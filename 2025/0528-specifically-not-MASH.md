<pmeta id="created">2025-05-27</pmeta>
<pmeta id="title">Bug report: Specifically not M\*A\*S\*H</pmeta>

The bug report was pretty straightforward, and yet every time I read it I was more puzzled.

> Searching for M\*A\*S\*H returns 401 unauthorized

This was a bug reported on our api gateway service, which stood at the exterior of our sprawling kingdom of services, the logical barriers of which reflected the social barriers between fiefdoms of developers.
Since we controlled the gateway, this bug could simply be appearing at the exterior but determining the cause could require a journey far deeper into the realm.

At least it was reproducible, I'd debugged the sorts of once-in-a-million only-on-production Heisenbugs, and while often rewarding, long wait times are not my strong suit.
Anyway, I could knock this out this afternoon and probably push to QA tomorrow.

But why "401"? That's error is usually for authorization issues, like if someone uses the wrong password or wrong key.
I need to find a search term that works first so I can see what the difference is between the working and bug condition.

- "MASH" works
- "M\*ASH" doesn't

Okay, so it looks like the '\*' is the issue here. Where is the error coming from? Is it from our gateway service, or from the search service that we call out to.
Time to start up my local integrated environment. It took quite a bit of time to decipher and bend the config needed to start *only* enough services on my laptop to test certain interactions, and search is one such interaction I've had to debug before. So copy in those configurations and start it up with verbose logging enabled.
A stream of garbage usually flies by my terminal before it slows down to a sensible crawl.
Okay, it's settled, and time to start poking.

```
$ curl "localhost:8080/search?q=MASH"
{ ... bunch of json ... }
$ curl "localhost:8080/search?q=M*A*S*H"
{ ... bunch of json ... }
$ curl "localhost:8080/search?q=*"
{ ... bunch of json ... }
```

That's annoying, I can't reproduce the bug locally. That's going to make it harder to make changes and see what happens.
I can try a local version of the gateway pointed at the production search service, just need to copy in another arcane configuration file.
```
$ curl "localhost:8080/search?q=MASH"
{ ... bunch of json ... }
$ curl "localhost:8080/search?q=M*A*S*H"
401 oauth unauthorized
$ curl "localhost:8080/search?q=*"
401 oauth unauthorized
```

My mental model of authorization is at odds with what I'm seeing. The API keys are correct (I checked them twice), and most search queries go through fine, search terms shouldn't even be a factor for whether a request is authorized or not, all requests which are signed with this key should be authorized. This is like realizing one day your front door does not open for guys named "Gerald".

Checking the production logs, eventually I see related logs for my requests:
```
20xx-05-02T13:01:24 GET "MASH"
20xx-05-02T13:01:25 GET "" 
20xx-05-02T13:01:27 GET "doesthiswork?" 
```

and the gateway
```
20xx-05-02T13:01:24 POST /search?q="MASH"
20xx-05-02T13:01:24 POST /search?q="M*A*S*H"
20xx-05-02T13:01:25 POST /search?q="*"
20xx-05-02T13:01:25 POST /search?q=""
20xx-05-02T13:01:25 POST /search?q="M*"
20xx-05-02T13:01:27 POST /search?q="doesthiswork?" 
```

okay, so it doesn't even reach the search service. But...it's not returning an error on the gateway? So where is the error coming from? Why doesn't the local version error?

## end of the first day

Now for some serious chin-scratching and mental preparation for the anguish that awaits me, reading someone else's code.
It wasn't too bad, but I needed to figure out what was different between their production deployment and my local version of their service.
Deployment configuration often resides somewhere between a structured and source-controlled source file which computers check and run daily, and the fleeting fancies that some engineer hacked together eons ago on a machine people are afraid to ssh into lest they summon nasal demons.
In this case it was solidly in the center. Some useful text files describing the setup (hopefully they're still applicable), it looks like it's running some http proxying gateway in front? And...a custom plugin for authentication?

Bingo this has got to be it. No way these idiots-who-are-not-me didn't mess this up somehow. The code is probably a mess.

About an hour of reading and re-reading some very clean and well-documented code which implements the authentication protocol and has links to specific sections of the spec, my head is spinning.

Could it be our service that is incorrectly signing the requests?

Digging through our client implementation for the search service, it's using the most standard of standard libraries, and my heart starts racing. Did I find a bug in code that has been used and read by the world over? Will this be the bug which launches me into a very niche stardom of people-who-fixed-years-old-bug-in-places-where-nobody-even-noticed-this-huge-glaring-issue? After all, it's a library which has been looked over but also changed by thousands, everyone adding and removing their little change, and probably it took my elevated capabilities to put all the pieces together.

About an hour of reading and re-reading some very clean and well-documented code which implements the authentication protocol and has links to specific sections of the spec, my head is spinning.

What is real? Is this some issue with the hardware? Are we running different versions of the code than what I'm looking at? Have computers loosed their bonds of strict execution and decided to use their newfound freedom of will mostly continue to serve media metadata, only to play tricks on this poor Junior Software Engineer

My coworker suggested I just strip the `*` from search queries and move on. After all, searching for `MASH` returns the same results as `M*A*S*H` so the search service is probably doing something like that anyway. I guess it's fine but in a way that makes my soul hurt a bit. There's nothing high-priority on the ticket queue right now, and I'm invested, I will solve this the non-soul-hurty way.

## end of the second day

Clearly I'm missing something. I'm pretty sure the error is being generated by the http proxy code, but essentially this error is a disagreement between the proxy authentication code and the gateway's authentication code.
The authentication code takes as input a key and some data, and as output gives a string of letters and numbers that you should attach to your request.
So the gateway says the signature is one thing `facedead` the gateway says it's another `cafebeef`, which one is right?
I need to consult the specification for the authentication protocol.

It says something like the following:

> The data is encoded as in <link to other specification>. Characters in the UNRESERVED set are percent-encoded, the rest are left as-is.

So cool, let's do that, but what is the `UNRESERVED` set? Got to look at `other specification`. Ah, it's a specification for an encoding. So I implement that encoding and use it for encoding the data that I want to sign.
I end up with the signature that matches the custom authentication code on the proxy server.
So the gateway server must be wrong. But this gateway server talks to a *lot* of other servers, all using the same, apparently wrong authentication code?
I look up to see if anyone has filed bugs similar to this on the most standard of standard libraries, and sure enough there's one from 8 years ago when this authentication scheme was more popular...and there's a thread where people argue about how to interpret the spec.

There are two interpretations of the line above:

> 1. The data is encoded as in <link to other specification>, for example characters in the UNRESERVED set are percent-encoded, the rest are left as-is.

> 2. Some definitions are used from <link to other specification>. Characters in the UNRESERVED set are percent-encoded, the rest are left as-is.

The first would mean that we should use the rules from `other specification` to encode, those rules encode more characters than just the `UNRESERVED` set.
The second means we use definitions like `UNRESERVED` and `percent-encoded` from `other specification` but we define a new rule to follow in this specification which is *only* to encode the `UNRESERVED` set characters.

So the fix for this was to implement the spec matching the search services authors' interpretation of the spec, and leave a lot of comments why this was done, and why none of the upstreams would accept patches to switch to the other's interpretations.

Still a bit soul-hurty of a fix, and took a couple extra days, but ultimately more fulfilling than just stripping out `*` and I had some fun reading specs.

