// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

let channel = socket.channel("now_playing:lobby", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

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

export default socket
