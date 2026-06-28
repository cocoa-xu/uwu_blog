// WebAuthn (passkey / security-key) ceremonies for the admin.
// Talks to the PasskeyController JSON endpoints and the browser credential API.

function csrfToken() {
  const meta = document.querySelector("meta[name='csrf-token']")
  return meta ? meta.getAttribute("content") : ""
}

function bufferToBase64url(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function base64urlToBuffer(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/")
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=")
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function postJSON(url, body) {
  return fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json", "x-csrf-token": csrfToken()},
    body: JSON.stringify(body || {})
  })
}

async function registerPasskey(label) {
  const challengeResponse = await postJSON("/admin/passkeys/challenge")
  if (!challengeResponse.ok) throw new Error("challenge request failed")
  const options = await challengeResponse.json()

  options.challenge = base64urlToBuffer(options.challenge)
  options.user.id = base64urlToBuffer(options.user.id)
  options.excludeCredentials = (options.excludeCredentials || []).map((cred) => ({
    ...cred,
    id: base64urlToBuffer(cred.id)
  }))

  const credential = await navigator.credentials.create({publicKey: options})

  const response = await postJSON("/admin/passkeys", {
    label,
    credential: {
      rawId: bufferToBase64url(credential.rawId),
      attestationObject: bufferToBase64url(credential.response.attestationObject),
      clientDataJSON: bufferToBase64url(credential.response.clientDataJSON)
    }
  })

  return response.ok
}

async function authenticatePasskey() {
  const challengeResponse = await postJSON("/auth/passkey/challenge")
  if (!challengeResponse.ok) throw new Error("challenge request failed")
  const options = await challengeResponse.json()

  options.challenge = base64urlToBuffer(options.challenge)
  options.allowCredentials = (options.allowCredentials || []).map((cred) => ({
    ...cred,
    id: base64urlToBuffer(cred.id)
  }))

  const credential = await navigator.credentials.get({publicKey: options})

  const response = await postJSON("/auth/passkey", {
    credential: {
      rawId: bufferToBase64url(credential.rawId),
      authenticatorData: bufferToBase64url(credential.response.authenticatorData),
      signature: bufferToBase64url(credential.response.signature),
      clientDataJSON: bufferToBase64url(credential.response.clientDataJSON)
    }
  })

  if (!response.ok) throw new Error("authentication failed")
  const data = await response.json()
  if (data.redirect) window.location.assign(data.redirect)
}

// The user dismissing the native prompt is not an error worth reporting.
function cancelled(error) {
  return error && error.name === "NotAllowedError"
}

export function initPasskeys() {
  const registerButton = document.querySelector("[data-passkey-register]")
  const loginButton = document.querySelector("[data-passkey-login]")
  const buttons = [registerButton, loginButton].filter(Boolean)

  // Buttons render hidden; reveal them only when WebAuthn is actually available.
  if (buttons.length === 0 || !window.PublicKeyCredential) return
  for (const button of buttons) button.hidden = false

  if (registerButton) {
    registerButton.addEventListener("click", async () => {
      const labelInput = document.querySelector("[data-passkey-label]")
      const label = labelInput ? labelInput.value.trim() : ""
      registerButton.disabled = true
      try {
        if (await registerPasskey(label)) {
          window.location.reload()
        } else {
          alert("Could not register the passkey.")
        }
      } catch (error) {
        if (!cancelled(error)) alert("Could not register the passkey.")
      } finally {
        registerButton.disabled = false
      }
    })
  }

  if (loginButton) {
    loginButton.addEventListener("click", async () => {
      loginButton.disabled = true
      try {
        await authenticatePasskey()
      } catch (error) {
        if (!cancelled(error)) alert("Could not sign in with a passkey.")
        loginButton.disabled = false
      }
    })
  }
}
