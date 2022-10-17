<pmeta id="created">2022 October 16</pmeta>
<pmeta id="title">Wayland interfaces in the times of rust ownership</pmeta>

I spent the last couple of weeks implementing code to parse wayland protocol definitions in xml and generate rust code.
There already exists [wayland-scanner] for C code, and [wayland-rs] for Rust, but I took a shot at modelling this myself.

The [wayland-book] written by ddevault was useful in describing the units that wayland protocols are built on, but the definitions and wire protocol have changed slightly since that book has been written.

# Enums: unique values or flag bits?

This isn't the first time I tried this.
Maybe I just didn't notice it the last time, or it actually wasn't there, but it seemed the protocol could use `<enum>`s for either an enumeration of unique values, or as a way to define constant bit flags.
I started out by generating both rust implementations (one `enum` and a set of constant `u32` flags), and while I was looking into converting between the two cases as-needed I realized the protocols all define a `bitflag="true"` attribute on `enum`s that cat act as bit flags, so that cut down on the amount of duplicate unnecessary code.

# References

References are `u32`'s that are only valid in the context of a connection or client.
They are not globally unique values, so each client of a wayland server opens a connection and starts with the assumed id of `wl_display@1`.
Next you allocate an id on the clientside (naturally `2`) and bind a `wl_registry` to that, using the `wl_display.get_registry` call.
With an id and a type, you _should_ be able to register callbacks or listeners for any events sent from the server to that id.
A connection must be read to receive new events.
The golang way to do this might be to have one goroutine reading the connection with a channel for each set of listeners.
When an event comes in, the goroutine would read it, unmarshal the event, and send it to the object's channel.
Another goroutine would be reading from the channel, and handling events.

Maybe an actor model might see each object and set of listeners as actors with mailboxes.
The client receives bytes in its mailbox, unmarshals them, and sends them to the different objects' mailboxes.

I chose to have the client own everything.
It owns the connection, it owns the byte buffers used for reading and writing, and it also owns per-object listeners.
References are created with proxy objects.
With a reference to a proxy object, anyone can send a request, so `WlRef<WlRegistry>` has a `sync()` method.
I tried for a bit making the client be something you had to pass in, but it didn't make sense, because it opened the possibility for users of the API to pass in a different client or connection, and wouldn't tell you that the id is actually invalid in that context.
So instead, I store an `rc::Weak` pointer back to the client in each `WlRef<_>` object, which is used to send requests.

This sort of works, now for receiving events.
When you create a new id for something, you have to actually pass the callback for events to that object at creation time.
This is different from the C api which allows you to create an object, and register a listener for it later.
`WlRef<WlDisplay>::get_registry` for instance takes a `WlRegistry` object that defines the `on_event` callback.
This callback is stored in the client under a map from ids to event callbacks.

The only way to know how to unmarshal the message, is to know which object the event message is destined to, and which event (specified by an opcode) it is.
I chose to define an interface that all event handler proxies must conform to that accepts bytes.
This way, I can store a bunch of `Box<dyn Interface>` values.
Since, for example, the `WlRegistry` event callback will only take `wl_registry::Event` values, the glue code that is generated is mostly the unmarshalling and calling event handler code.

# RefCell

One of the most confusing parts of this, that works but I'm not sure how, is that the main entrypoint and owner of all `WlClient` is passed around by-reference, but must have interior mutability to:
- create new ids
- add new object event handlers
- read into the input buffer from the connection
- write into the output buffer for the outgoing connection

So most of the fields inside `WlClient` are `RefCell` fields that I just call `borrow` and `borrow_mut` where it makes sense.
There was a little juggling involved as I realized in some places I needed both a `borrow` earlier and then a `borrow_mut` later.

For instance, the `WlClient::poll` function reads data from connection, unmarshals the destined object id, and dispatches it to the correct handler.
It must borrow the map of ids to handlers in order to call the `Interface::handle` function on it.
However, within a handler, there might be code to register a new object with a new handler, so the map of ids to handlers must be borrowed as mut.
```
fn poll() {
  buf = // bytes from connection
  objid = // unmarshal u32 from buf
  let handlers = client.handlers.borrow(); // 'a  handlers.borrow'd here
  let handler = handlers.get(objid); // 'a
  handler.handle(buf) // 'a
}

fn <handler.handle>(buf) { // technically still in 'a here, so handlers is still borrow'd
  ...
  let handlers = client.handlers.borrow_mut(); // 'b handlers.borrow_mut'd
  handlers.new_id(other_obj);
}
```

What I did here was to assume that in a single call to `poll`, an object cannot both be created _and_ receive an event so there are two maps.
One handler map can be borrowed as immutable for calling `handler.handle` on, and the second map can be borrowed as mutable for adding new handlers.
This requires that the two maps are merged at the end (or beginning) of each `poll` call, so the newly created handlers can be borrowed as immutable when their events start coming in.

```
fn poll() {
	buf = // bytes from connection
	objid = // unmarshal u32 from buf
	let handlers = client.handlers.borrow(); // 'a  handlers.borrow'd
	let handler = handlers.get(objid); // 'a
}

fn <handler.handle>(buf) {
	...
	let handlers = client.new_handlers.borrow_mut(); // client.handlers borrowed as 'a , but new_handlers as 'b
	handlers.new_id(other_obj);
}
```

I'm still not entirely certain this is guaranteed not to panic in some handler, and I hope after staring at it enough, a clearer separation of "(im)mutable in this context, not in this other" pops out at me, but right now it's mostly just guess and check.

# Multiple Versions

There's a couple protocols on my system that have multiple versions.
I was originally ignoring the version, except on a call to `wl_registry.bind`, but it seems I'll have to namespace them accordingly if I _want_ to include both in an app.
Not sure, it might be nicer to just have a proc macro or something to define that only builds the version you care to use.

# Object-generic Bind

The `wl_registry.bind` request is defined as only having two arguments
```
      <arg name="name" type="uint" summary="unique numeric name of the object"/>
      <arg name="id" type="new_id" summary="bounded object"/>
```
and it seems when the [wayland-book] was written (and I remember the last time I did this), it actually was simply two arguments.
However, my generated code for calling bind was resulting in a fatal error being returned from the server.
I checked another wayland app under `WAYLAND_DEBUG=1` and it seemed like it was actually sending 4 arguments:
```
      <arg name="name" type="uint" summary="unique numeric name of the object"/>
      <arg name="interface" type="string" summary="interface implemented by the object"/>
      <arg name="version" type="uint" summary="interface version"/>
      <arg name="id" type="new_id" summary="bounded object"/>
```

I also checked the current [wayland-scanner] code, and in fact, the generator code was special-casing a `type="new_id"` with no `interface=...` attribute to actually send 3 arguments instead of 1.
I don't understand why they didn't change the protocol definition instead of special-casing this?
If it was some attempt at stability, it's a fail, because you want stability in the wire-protocol, not simply stability in the xml file defining it.
Maybe there are other cases in the protocol definitions where `type="new_id"` without `interface` is used, but I haven't seen it, and I think it would make sense to update the protocol there as well.

# Other Thoughts

The wayland C code follows a pretty standard model of defining callback hooks as a struct that stores function pointers (which all have an initial `void* data` parameter), and registering those structs with optional closure data.
wayland-rs for the most part duplicates this.
Last time, I defined a `___Listener` trait which could be implemented, and then each trait method includes a more strictly typed `self` receiver.
This time, I think I'm okay with just passing a closure, and if you want to share data across closures, you'll have to do it with some sort of `'static` reference type.
I think I _could_ make the callback functions `FnMut`, but not sure how much better that'd be in terms of ergonomics.

I'm going to try rewriting a couple desktop helpers that I had written using `wayland-rs` before, and see how much I hate my implementation.
I was most struck by how much the model of single-owner, shared/mut references _didn't_ map naturally onto wayland objects.
The _client_ and _server_ both sort of joint-own all the objects, and you call destroy with the client, or receive a `destroy` call from the server for anything I guess (maybe I misunderstand the protocol, and this isn't true?).
While `wayland-rs` requires you to attempt to lock the object before using it.
This is sort of like `Rc`, because the server could `destroy` it at any time even if you have a `WlRef<_>` with its id, and you have to always check whether that reference is still valid.
I though of some design where you ask the client each time you want a reference to something, or maybe two reference types: one for inside a `poll` callback and one for outside, but I ultimately settled on locking the reference only in generated code where I need it, and allowing for lock failure in the error types.

-JD

[wayland-scanner]: https://gitlab.freedesktop.org/wayland/wayland/-/blob/main/src/scanner.c#L1226
[wayland-rs]: https://github.com/smithay/wayland-rs
[wayland-book]: https://wayland-book.com/registry/binding.html
