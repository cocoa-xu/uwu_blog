---
title: "Sharing Now Playing Song"
date: 2023-02-17
permalink: sharing-now-playing-song
---

This feature displays the song that I'm listening to on my blog. The idea of sharing one's current playing song comes from [@sumimakito](https://maki.to)✨

### Protocol

To make this work, we need to design a protocol that allows client-side code to send necessray information of the current playing song. For example,

```json
{
  "type": "youtube",
  "title": "六等星の夜 Magic Blue ver.",
  "current_time": 101.0,
  "duration": 347.3,
  "data": "ar9Q4VRp71Y"
}
```

The necessary fields are

- `type`.

  Like `youtube` or `spotify`.

- `title`.

  The title of the song.

- `current_time`.
  
  Playback progress in seconds.

- `duration`.

  Duration of this song in seconds.

- `data`.
  
  When `type` is `youtube`, this field is the ID of that YouTube video.
  
  For instance, `"ar9Q4VRp71Y"` means I'm listening to the music at `https://www.youtube.com/watch?v=ar9Q4VRp71Y`

### Client-side

For client-side, I decide to write a Chrome extension to do this job. By obverseration, we know that the URL of a YouTube video follows this pattern (as of the time of writing)

```url
https://youtube.com/watch?v={VIDEO_ID}
```

So we can parse the URL (i.e., `document.location.href`) and check if we are on a YouTube video page. It's done by checking the hostname (should be `www.youtube.com`) and pathname (should be `/watch`). If we're on a YouTube video page, then we can try to get the video ID via `url.searchParams.get`.

```js
const url = new URL(document.location.href)
if (url === undefined || 
    url.hostname !== 'www.youtube.com' || 
    url.pathname !== '/watch') {
  return
}

// Yes, we're on a YouTube video page

// Ensure we have the video ID
let playing = url.searchParams.get('v')
if (playing === undefined || playing.length === 0) {
  return
}
```

After that, we can get the HTML video element using `document.querySelector` and add an `timeupdate` event listener to the video element. (As a side note, [`progress`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/progress_event) event is different from the [`timeupdate`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/timeupdate_event) event, and what we need here is the latter one.)

```js
let video = document.querySelector('video')
video.addEventListener('timeupdate', handleTimeUpdateEvent)
```

In this `handleTimeUpdateEvent` function, we pack all the necessary information into a hashmap and send it to the service worker (`background.js`) via `chrome.runtime.sendMessage`.

```js
const handleTimeUpdateEvent = (event) => {
  if (event.target.currentTime - oldTime < 1 || 
      event.target.currentTime > oldTime) {
    return
  }

  let title = 'unknown'

  try {
    title = document.querySelector("#title>h1>yt-formatted-string").innerHTML
  } catch (error) {}

  chrome.runtime.sendMessage({
    type: 'youtube',
    data: oldPlaying,
    current_time: event.target.currentTime,
    duration: event.target.duration,
    title: title
  }, (resp) => {})

  oldTime = event.target.currentTime
}
```

Of course, since YouTube can automatically play the next song in a playlist, we should also observe the changes of the URL, remove the `timeupdate` event listener for the old video element and add the same event listener for the new video element.

```js
const observeUrlChange = () => {
  let oldHref = ''
  let oldPlaying = ''
  let oldPlayer = undefined
  let oldTime = -1

  const handleTimeUpdateEvent = (event) => {
    // skipped...
  }

  const body = document.querySelector("body")
  const observer = new MutationObserver(mutations => {
    mutations.forEach(() => {
      if (oldHref === document.location.href) {
        return
      }

      oldHref = document.location.href
      const url = new URL(document.location.href)
      if (url === undefined || 
          url.hostname !== 'www.youtube.com' || 
          url.pathname !== '/watch') {
        return
      }

      let playing = url.searchParams.get('v');
      if (playing === undefined || playing.length === 0) {
        return
      }

      let video = document.querySelector('video')
      if (video !== undefined) {
        if (oldPlayer !== undefined) {
          oldPlayer.removeEventListener('timeupdate', handleTimeUpdateEvent)
        }
        oldPlaying = playing
        video.addEventListener('timeupdate', handleTimeUpdateEvent)
      }

      oldPlayer = video
    })
  })
  observer.observe(body, { childList: true, subtree: true })
}

window.onload = observeUrlChange
```

### Server-side

On the Phoenix side, we first need to have an API endpoint that verifies and stores the received message.

For this project, I created a custom Phoenix plug which will handle the data and broadcast updated info to each client via WebSocket.

As a side note, I did consider using a Liveview page, but I ended up using WebSocket in this case because 

1. the data source is a Chrome extension
2. there are no interactions among visitors
3. also, I'm too lazy to design a new page for this feature XD

So I added a `/now-playing` scope which will first pipe any requests through `:api` and then process the request in `UwUBlogWeb.Plugs.NowPlaying.call/2`, where the first parameter is a `Plug.Conn` struct and the value of the second parameter will be `:update`, which we defined it using the `post` macro.

```elixir
scope "/now-playing", UwUBlogWeb do
  pipe_through :api

  post "/", Plugs.NowPlaying, :update
end
```

Moreover, as we're posting updates to the server in a Chrome extension, it's possible that we might lose connection or close the browser at any moment. Hence we need to remove songs that no longer have further playback updates. Let's say if a song is not getting updated for 10 seconds, we can safely assume that it's not in playing status thus remove it.

```elixir
defp timeout, do: 10

defp remove_timeout(now_playing) do
  Map.filter(now_playing, fn {_, v} ->
    :erlang.monotonic_time(:second) - Map.get(v, "last_seen", 0) < timeout()
  end)
end
```

In the next step, we can setup a very basic API key verification in `UwUBlogWeb.Plugs.NowPlaying.call/2` so that no one else can arbitrarily send fake data to this API. 

Note that the code shown below is probably not the best practice as it doesn't prevent replay attacks.

```elixir
defp api_key, do: Application.fetch_env!(:uwu_blog, __MODULE__)[:apikey]

def call(
    %Plug.Conn{
      params: %{
        "apikey" => apikey,
        "type" => type,
        "data" => data,
        "current_time" => current_time,
        "duration" => duration,
        "title" => title
      }
    } = conn,
    :update=_metadata
  ) do
  if apikey == api_key() do
    key = "#{type}-#{data}"

    # store and update now playing items...
    Agent.update(__MODULE__, fn
      %{now_playing: now_playing} ->
        updated_progress =  %{
          "type" => type,
          "data" => data,
          "current_time" => current_time,
          "duration" => duration,
          "title" => title,
          "last_seen" => :erlang.monotonic_time(:second)
        }
        updated =
          Map.update(now_playing, key, updated_progress, fn _ -> updated_progress end)
          |> remove_timeout()

        # broadcast to all clients in the `"now_playing:lobby"`
        # WebSocket channel
        #
        # the event name is `"update"` and the payload is `updated`
        UwUBlogWeb.Endpoint.broadcast("now_playing:lobby", "update", updated)
        %{now_playing: updated}
    end)

    conn
    |> Plug.Conn.send_resp(200, [])
  else
    conn
    |> Plug.Conn.send_resp(401, [])
  end
  |> Plug.Conn.halt()
end
```

The rest of this project is mostly frontend thingy, and I believe you can do better than me so I'll skip them.

I decided to output current playing songs in `lib/uwu_blog_web/templates/page/index.html.heex`, so if there is any song playing, the visitor will see it immediately when the page is loaded without waiting for the WebSocket to connect.

```html
<article id="now-playing" class="column post-section">
  <h2 class="kira">Now Playing</h2>
  <div id="now-playing-list">
    <% now_playing = UwUBlogWeb.Plugs.NowPlaying.get() %>
    <%= if map_size(now_playing) == 0 do %>
      <div>Not playing</div>
    <% else %>
      <%= for {_, item} <- now_playing do %>
        <% link = if item["type"] == "youtube", do: """
        <a href="https://youtube.com/watch?v=#{item["data"]}" target="_about:blank">#{item["title"]}</a>
        """, else: "" %>
        <div class="now-playing-item"><%= raw link %>
          <div class="music__times duration">
            <div id="music-seek" class="music__seek bar--duration">
              <% width = if item["duration"] > 0, do: Float.round(item["current_time"] / item["duration"] * 100.0, 1), else: 100 %>
              <span class="music__seek_handle" style={"width: #{width}%"}></span>
            </div>
            <span id="music-current-time" class="music__current_time duration__current">
              <%= Time.to_string(Time.add(~T[00:00:00], trunc(item["current_time"]) * 1000, :millisecond)) %>
            </span>
            <span id="music-duration" class="music__duration duration__until"><%= Time.to_string(Time.add(~T[00:00:00], trunc(item["duration"]) * 1000, :millisecond)) %></span>
          </div>
        </div>
      <% end %>
    <% end %>
  </div>
</article>
```

And we update this list in `assets/js/now_playing_socket.js`

```js
const seconds_to_display = (seconds) => {
  const totalMs = seconds * 1000;
  const result = new Date(totalMs).toISOString().slice(11, 19);

  return result;
}

channel.on("update", payload => {
  const playlist = new Map(Object.entries(payload))
  let playlist_div = document.querySelector("#now-playing-list")
  let playlist_div_clone = playlist_div.cloneNode()
  playlist_div_clone.innerHTML = ''
  if (playlist.size === 0) {
    let playing_item = document.createElement("div")
      playing_item.innerText = "Not playing"
      playlist_div_clone.appendChild(playing_item)
  } else {
    for (let [_, value] of playlist) {
      let current_time = parseFloat(value["current_time"])
      let duration = parseFloat(value["duration"])
      let width = 100
      if (duration !== 0) {
        width = current_time / duration * 100
      }
      let link = ''
      if (value["type"] === "youtube") {
        link = `<a href="https://youtube.com/watch?v=${value["data"]}" target="_about:blank">${value["title"]}</a>`
      }
      let now_playing_item = `<div class="now-playing-item">${link}
      <div class="music__times duration">
        <div id="music-seek" class="music__seek bar--duration">
          <span class="music__seek_handle" style="width: ${width}%"></span>
        </div>
        <span id="music-current-time" class="music__current_time duration__current">
          ${seconds_to_display(current_time)}
        </span>
        <span id="music-duration" class="music__duration duration__until">${seconds_to_display(duration)}</span>
      </div>
      </div>`
      let playing_item = document.createElement("div")
      playing_item.innerHTML = now_playing_item
      playlist_div_clone.appendChild(playing_item)
    }
  }
  playlist_div.replaceWith(playlist_div_clone)
})
```

After everything is done, we can start the server in a bash session,

```bash
$ mix phx.server
```

and test it in another bash session with `curl`.

```bash
$ curl -X POST http://127.0.0.1:4000/now-playing -vv \
   -H 'Content-Type: application/json' \
   -d '{"apikey": "NOWPLAYINGAPIKEY", "type":"youtube", "title": "六等星の夜 Magic Blue ver.", "current_time": 303.0, "duration": 347.3, "data":"ar9Q4VRp71Y"}'
```
