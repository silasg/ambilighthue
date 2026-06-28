"use strict";

const $ = (id) => document.getElementById(id);
const TOKEN_KEY = "ambilight_api_token";

function token() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

async function api(path, options = {}) {
  const headers = Object.assign({ "Content-Type": "application/json" }, options.headers || {});
  const t = token();
  if (t) headers["X-API-Token"] = t;
  const res = await fetch(path, Object.assign({}, options, { headers }));
  let body = {};
  try { body = await res.json(); } catch (_) { /* empty body */ }
  if (!res.ok) {
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return body;
}

function log(msg, isError) {
  const el = $("log");
  el.textContent = msg || "";
  el.classList.toggle("error", !!isError);
}

function renderState(power, configured) {
  $("state-dot").dataset.power = power;
  const label = { on: "Ambilight On", off: "Ambilight Off", unknown: "Unknown" }[power] || "Unknown";
  $("state-text").textContent = configured ? label : "Not paired";
  $("controls").hidden = !configured;
  $("not-configured").hidden = configured;
}

async function refresh() {
  try {
    const s = await api("/api/state");
    renderState(s.power, s.configured);
    if (s.error) log(s.error, true); else log("");
  } catch (e) {
    log(e.message, true);
  }
}

async function setPower(value) {
  try {
    log("Working…");
    const s = await api("/api/" + value, { method: "POST" });
    renderState(s.power, s.configured);
    log("");
  } catch (e) {
    log(e.message, true);
  }
}

async function startPairing() {
  const tvIp = $("tv-ip").value.trim();
  if (!tvIp) { log("Enter the TV IP first", true); return; }
  try {
    const r = await api("/api/pair/start", { method: "POST", body: JSON.stringify({ tvIp }) });
    log(r.status || "Pairing started; enter the PIN.");
  } catch (e) {
    log(e.message, true);
  }
}

async function confirmPairing() {
  const pin = $("pin").value.trim();
  if (!pin) { log("Enter the PIN shown on the TV", true); return; }
  try {
    const r = await api("/api/pair/confirm", { method: "POST", body: JSON.stringify({ pin }) });
    log(r.status || "Paired!");
    await refresh();
  } catch (e) {
    log(e.message, true);
  }
}

async function resetPairing() {
  try {
    await api("/api/pair/reset", { method: "POST" });
    log("Pairing reset.");
    await refresh();
  } catch (e) {
    log(e.message, true);
  }
}

function init() {
  $("btn-on").addEventListener("click", () => setPower("on"));
  $("btn-off").addEventListener("click", () => setPower("off"));
  $("btn-start").addEventListener("click", startPairing);
  $("btn-confirm").addEventListener("click", confirmPairing);
  $("btn-reset").addEventListener("click", resetPairing);
  $("toggle-settings").addEventListener("click", () => {
    $("settings").hidden = !$("settings").hidden;
  });

  const tokenInput = $("api-token");
  tokenInput.value = token();
  tokenInput.addEventListener("change", () => {
    localStorage.setItem(TOKEN_KEY, tokenInput.value.trim());
    refresh();
  });

  refresh();

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch(() => { /* offline shell optional */ });
  }
}

document.addEventListener("DOMContentLoaded", init);
