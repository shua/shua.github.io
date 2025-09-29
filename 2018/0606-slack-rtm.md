<pmeta id="created">2018-06-06T12:00:00-05:00</pmeta>
<pmeta id="title">slack-rtm</pmeta>

After learning slack had [removed support] for [irc gateways],
I wanted to see what their alternative was for an api.
I knew about some of the web API because I've messed around with [hubots] for various slack orgs I've been in, but I took a nice dive into the docs with the idea that I wanted to send myself a message via curl.
I ended up using just a little more (needed something that spoke "websocket"), and here's my little writeup for what was required.

APIs
----
First thing was figuring out the high-level route, and after some reading of slack api doc pages, I determined that I'd need

1. a slack app, with an auth key that has the proper permissions or oauth scopes (in this case "client")
2. curl the [`rtm.connect`] REST endpoint to get a websocket connection
3. use  awebsocket client to send a json formatted message event via the [rtm api]

With websockets, REST, and oauth roles, it's very 5-years-ago's next-gen web™ (and I'm really not sure what today's next-gen web is, but I imagine it's http 2.0 functional monito blockchains).

Auth
----
Here's what I did to get a token with the correct permissions (it was not obvious, and I wonder if slack will disallow this at some point):

1. create a [new app] if you haven't already
2. go to app control panel and open the "Add features and functionality" dropdown and select "Permissions"
3. right-click on `Reinstall App` button underneath the access token and copy the link location. It should look something like
```
https://slack.com/oauth/authorize?client_id=123456789.9876543&team=TXXXXXXXX&install_redirect=oauth&scope=chat:write:user
```
4. modify the `scope` url parameter to read `scope=client`
```
https://slack.com/oauth/authorize?client_id=123456789.9876543&team=TXXXXXXXX&install_redirect=oauth&scope=client
```
5. visit that url in a browser, and accept the change in permissions; now the access token will have [client scope]

Now you can use the app's token to access a bunch of REST endpoints.

socket up
---------
I made a little shell function while I was poking around the REST endpoints, you may find it useful too:

```
$ slackc() {
	method=$1
	api=$2
	shift 2
	curl -X $method -d "Authorization: Bearer $TOKEN" $@ "https://slack.com/api/$api"
}
```

I chose [wsc] as a websocket client because it was small and easy to install via `npm`.

```
$ npm install wsc
$ alias wsc=<path to node_modules>/wsc/wsc
```

Now, you can call

```
$ TOKEN=<app token, starts with "xoxp-">
$ slackc GET rtm.connect |jq . >rtm.connect.txt
$ wsc $(<rtm.connect.txt jq .url |sed 's/^"//' |sed 's/"$//')
```

You need to replace `<app token...>` with your slack app token which can be found on the app settings page in slack.
Here we call the `rtm.connect` REST endpoint, which returns some json that has a websocket url among other things.
The little shell stuff is there to extract the url via `jq`, and strip the quote characters with `sed`

Now you've got a slack rtm connection.

Talk to yourself
----------------
I joined an im with myself using the slack webclient, and got an event in `wsc`

```
< {"type":"im_open","user":"UXXXXXXXX","channel":"DXXXXXXXX","event_ts":"1527543437.000020"}
```

That showed me the channel id I needed `DXXXXXXXX`, and I sent a message to myself:

```
> { "id": 1, "type": "message", "channel": "DXXXXXXXX", "text": "testing this websocket" }
```

and it showed up in the webclient!

sick

[removed support]: https://it.slashdot.org/story/18/03/08/2049255/slack-is-shutting-down-its-irc-gateway
[irc gateways]: https://slack.com/account/gateways
[hubots]: https://hubot.github.com/
[`rtm.connect`]: https://api.slack.com/methods/rtm.connect
[rtm api]: https://api.slack.com/rtm
[client scope]: https://api.slack.com/scopes/client
[wsc]: https://github.com/danielstjules/wsc

