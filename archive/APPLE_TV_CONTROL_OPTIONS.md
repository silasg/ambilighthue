# Controlling the TV Ambilight with a Free Apple ID: Realistic Options

This report evaluates realistic ways to control the Philips TV ambilight using your Apple TV and/or other
Apple devices, given that you have **only a free Apple ID** (no paid Apple Developer Program membership)
and run a homelab capable of hosting dockerized apps.

Short version: the existing sideloaded tvOS app works, but the free-account 7-day expiry makes it a chore.
The durable answer is to stop trying to make *your* app run on the Apple TV and instead run **Home Assistant**
(or a small HomeKit bridge) in your homelab. From there, two no-developer-account, no-7-day-churn paths
co-lead: (a) expose the ambilight as a **HomeKit accessory** so the Apple TV (as Home hub), Siri, the Home
app, and your Apple Watch control it natively; and (b) install a **native tvOS Home Assistant client**
(e.g. Room Board) from the App Store to get an actual control dashboard **on the Apple TV screen** — the one
thing the HomeKit-only path lacks.

---

## 1. Free Apple ID provisioning: the constraints

When you sign apps with a free Apple ID (a "Personal Team" in Xcode), Apple imposes hard limits that a paid
membership ($99/yr) removes:

| # | Constraint | Free Apple ID | Paid Apple Developer Program |
|---|---|---|---|
| 1 | Provisioning profile / app validity | **~7 days**, then the app refuses to launch until re-signed and re-installed | 1 year |
| 2 | App ID (bundle ID) churn | **10 App IDs per 7 days** max | Effectively unlimited for normal use |
| 3 | Sideloaded apps installed at once | Typically **3 active app IDs** per device | Many |
| 4 | Developer web portal (Certificates, IDs & Profiles) | **No access** — signing only through Xcode | Full access |
| 5 | TestFlight / App Store distribution | Not available | Available |

Streamlining the re-sign workflow (you can't avoid it, only smooth it):

- Use **Xcode automatic signing** ("Automatically manage signing", Personal Team selected). Xcode regenerates
  the short-lived development certificate and provisioning profile on each build.
- If a profile has gone stale, Xcode > Settings > Accounts > (your Apple ID) > **Download Manual Profiles** /
  "Download All" forces a fresh set of certs, then Build & Run re-deploys.
- Keep the **same bundle ID** between re-signs so you don't burn the "10 App IDs / 7 days" budget and so
  `UserDefaults` (your stored TV IP/username/password from pairing) survives — re-installing over the same
  bundle ID generally preserves app data; deleting/re-adding loses it and forces re-pairing.
- The practical loop becomes: every ~7 days, connect the Apple TV (Xcode > Window > Devices and Simulators,
  Apple TV paired over the network), open the project, Build & Run to the device. A few minutes, but recurring.

This is a stopgap, not a solution. There is no free way to make a tvOS sideload last longer than 7 days.

## 2. Sideloading tools on tvOS (AltStore / SideStore reality)

The popular "untethered" sideload managers that auto-refresh apps in the background **do not support tvOS**:

- **AltStore** and **SideStore** are sandboxed **iOS/iPadOS** apps. Their whole auto-refresh mechanism relies
  on running as a normal iOS app on the device. There is no tvOS build; community requests exist but it is not
  supported.
- The only tool that signs/installs to **tvOS is Sideloadly**, but it is **computer-tethered**: you must
  re-connect to a Mac/PC to install, update, and refresh — i.e. it does **not** remove the 7-day re-sign chore,
  it just gives you another front-end for it.

Conclusion: the convenient "set-and-forget" sideloading story (AltStore/SideStore background refresh) that iOS
users enjoy **does not exist for Apple TV**. On tvOS you are stuck with manual periodic re-signing
(Xcode or Sideloadly).

## 3. Can tvOS run PWAs, web apps, or Apple Shortcuts? (Confirming your belief)

Your belief is correct on all counts:

- **No Shortcuts app on tvOS.** Shortcuts ships on iOS, iPadOS, macOS, and **watchOS** — but not tvOS.
- **No Safari / no web browser on tvOS.** With no browser, there is **no PWA / Web Clip / "Add to Home Screen"**
  mechanism at all. There is no way to install or run a web app on the Apple TV.
- The "no-app" control surfaces on the Apple TV are **Siri** and **Control Center's Home tile** — and those
  only work with **HomeKit** accessories and scenes (see §6), not arbitrary web apps.

Caveat — App Store apps are a different story: while *web apps* and *sideloaded* apps are out, the **tvOS App
Store** does carry native apps. Notably, third-party Home Assistant dashboard clients for tvOS now exist (see
§5b), and because they are App Store apps they install with **no developer account and no 7-day re-sign**.

So any browser/Shortcut-based plan must run on an **iPhone, iPad, Mac, or Apple Watch** — never on the Apple TV
itself.

## 4. HomeKit angle — the strongest durable path

This is the recommended direction. The key insight: your **Apple TV is already a HomeKit Home hub** (4th-gen or
newer, signed into iCloud with 2FA). A Home hub gives you remote access, automations, and Siri control of any
HomeKit accessory — **without any sideloaded app and without a developer account.**

To make the ambilight a HomeKit accessory, run a **HomeKit bridge in your homelab** that translates HomeKit
on/off to your homelab REST backend (the ambilight on/off endpoint). Two viable bridges:

### 4a. Homebridge + an HTTP plugin (lightweight, focused)

- Run **Homebridge** (Node.js, dockerized) in the homelab.
- Use the **`homebridge-http-switch`** plugin to define a stateful switch that calls your REST backend:
  - `onUrl` → your "ambilight on" endpoint
  - `offUrl` → your "ambilight off" endpoint
  - `statusUrl` (+ `statusPattern` / `pullInterval`) → reflect current state back into the Home app
- For richer needs, **`homebridge-http-advanced-accessory`** can map an HTTP API onto other HomeKit service types.
- Homebridge pairs to the Home app via a HomeKit setup code; the switch then appears in the Home app, is
  Siri-controllable, and shows up in the **Apple TV Control Center Home tile**.

This is the cleanest fit because your homelab REST backend already exposes exactly the on/off control the switch
needs — Homebridge becomes a thin HTTP→HAP shim.

### 4b. Home Assistant + HomeKit Bridge (more batteries-included)

- Run **Home Assistant** (dockerized).
- Get the ambilight as an HA entity (see §5), then enable the **HomeKit Bridge** integration to expose that
  entity to Apple Home. Pair via the QR/setup code in the Home app ("Add Anyway" for the uncertified bridge).
- HA scripts appear in Home as momentary switches; light/switch entities appear as native toggles.
- Note the practical caveats: HomeKit pairing relies on **mDNS/Bonjour** (multicast must reach the Apple
  devices, so watch VLAN/firewall setup), bridges are capped at 150 accessories (irrelevant for one switch),
  and re-pairing is needed if the HA IP changes.

Both routes converge on the same payoff: the ambilight becomes a first-class HomeKit accessory.

## 5. Home Assistant + Philips JointSpace integration (control without your backend)

Home Assistant can talk to the Philips TV **directly**, potentially making a separate REST backend unnecessary
for the HA route:

- The built-in **`philips_js`** integration controls Philips TVs that expose the jointSPACE JSON-API (the same
  API your app uses on port 1926). It can pair via PIN, just like your app.
- It exposes a **light entity for the ambilight** (turn on/off, set color / lounge modes; "off" hands ambilight
  back to the TV's video-based mode), a **remote entity** for key presses, and — when supported — an
  **"Ambilight+Hue" switch** that syncs ambilight to a Hue bridge (relevant to this project's Hue angle).
- Caveats from the field: on some newer firmware (API v6.x) the TV returns HTML "Ok" pages instead of JSON,
  which the integration treats as success but logs noisily; the Ambilight+Hue switch sometimes fails to appear
  and needs a reconfigure toggle; and the TV dropping to standby can break the connection (a Wakelock app on
  the TV is a common workaround). A maintained HACS custom component (**jomwells/ambilights**) offers more
  dedicated ambilight control if the built-in one falls short.

If you go HA, you also get **HA dashboards** and the **HA Companion app** (iPhone/iPad/Apple Watch) as an extra,
non-Apple control surface — though the Companion app does **not** run on tvOS.

## 5b. Home Assistant with a native tvOS client (a control UI on the Apple TV)

Earlier sections noted tvOS has no Shortcuts/PWA/browser. That remains true — but there is an important
nuance: **native Home Assistant dashboard apps for tvOS now exist on the App Store.** Because they are normal
App Store apps, they install with no developer account and **no 7-day re-sign churn** (that limitation only
applies to *sideloaded* apps signed by you). This is the one non-sideload path that actually puts a **control
UI on the Apple TV screen itself**.

The flow:

1. Run **Home Assistant** in the homelab.
2. Add the **`philips_js`** integration so the ambilight is an HA **switch/light entity** (see §5). (Or point
   HA at your homelab REST backend instead.)
3. Install a native **tvOS HA client** on the Apple TV and connect it directly to your HA server (token stored
   on-device; no developer-run cloud). Toggle the ambilight entity from the couch with the Siri Remote.

Available native tvOS clients (verified on the App Store):

| # | App | Min tvOS | Notes |
|---|---|---|---|
| 1 | **Room Board for Home Assistant** | tvOS 18+ | Dedicated, polished native room-based HA dashboard; direct connection, token/data stay on device; controls lights, switches, climate, media, cameras, sensors. The most purpose-built/refined of the three. |
| 2 | **HA Control** | tvOS 17.6+ | Community app; auto-connects to HA, tile/list views of devices, scenes, sensors. The lowest tvOS-version bar. |
| 3 | **Couch Control (for HomeKit & HA)** | tvOS 18.1+ | Newer/beta-stage; supports **both HA and HomeKit**, multi-camera grids, media browsing, sensor history; Keychain-stored tokens, no cloud. |

HA also now supports **deep-linking into tvOS**, enabling tighter Apple-TV-side integration.

Trade-offs: this gives you a real on-TV dashboard, but it is **not** Siri/Watch-native the way the HomeKit
route is — control happens inside the third-party app via the remote, not via "Hey Siri" or the Home app on
your wrist. UX quality depends on the chosen client (Room Board is the most dedicated; HA Control and Couch
Control are community/beta efforts). You still depend on HA running in the homelab. Pairs well with the
HomeKit bridge (§4) and Shortcuts (§7) — you can run all three.

## 6. tvOS-native automation / remote-control paths

What you can actually do **on the Apple TV itself**, with no developer account and no app:

- **Control Center Home tile:** press-and-hold the TV button on the Siri Remote → Home icon. You can toggle
  accessories for the current room and **run existing scenes**. (The HomeKit icon only appears once you have at
  least one scene/camera configured; create a scene on iPhone if it's missing.) The standalone full accessory
  list found on iPhone is **not** available — it is intentionally limited on tvOS.
- **Siri on the Siri Remote:** "Hey Siri, turn on the ambilight" works if the ambilight is a named HomeKit
  accessory or a scene.
- **Apple TV Remote app** (in iOS Control Center) controls the Apple TV's UI, not arbitrary HTTP endpoints — not
  useful for ambilight directly. Third-party tvOS remote apps don't provide a general HTTP automation surface.

All of these require the ambilight to be a HomeKit accessory first (§4). There is **no** native tvOS *scripting*
that can hit your REST backend directly — but a native **App Store** app can (e.g. the tvOS HA clients in §5b).

## 7. Triggering the homelab REST backend from iPhone / iPad / Apple Watch (Shortcuts)

The platforms that **do** have Shortcuts (iOS, iPadOS, macOS, watchOS) can call your homelab REST backend
directly with the **"Get Contents of URL"** action — no HomeKit, no app, no developer account:

- Build a shortcut with **Get Contents of URL** → your backend's on/off endpoint. Switch method to POST/PUT if
  needed; add headers (e.g. an `Authorization` header) via "Show More".
- The shortcut runs from the iPhone/iPad, from the **Apple Watch Shortcuts app or a watch complication**, and
  can be triggered by Siri.
- **watchOS caveats to design around:** the watch tends to **force HTTPS** (plain `http://` requests can fail
  with SSL errors that the same shortcut survives on iPhone). For watch reliability, give the backend a **valid
  TLS cert** (e.g. via a reverse proxy with Let's Encrypt / a trusted internal CA) rather than self-signed.

This is the best **remote/quick-glance** trigger for wrist/phone control, and it composes well with the HomeKit
route (you can do both).

---

## Comparison of viable options

| # | Approach | What it requires | Works on Apple TV itself? | Controllable from Watch / iPhone? | Ongoing maintenance / effort | Cost |
|---|---|---|---|---|---|---|
| 1 | **Re-sign existing tvOS app** (Xcode or Sideloadly) | Mac + Xcode/Sideloadly, periodic redeploy | **Yes** (the app runs on the Apple TV) | No (control is on the TV screen only) | **High** — manual re-sign every ~7 days | Free |
| 2 | **Homebridge + `homebridge-http-switch`** → REST backend | Homebridge in homelab; the REST backend; HomeKit pairing | **Yes** — via Control Center Home tile + Siri | **Yes** — Home app + Siri on Watch/iPhone | **Low** — set up once, runs as a service | Free (self-hosted) |
| 3 | **Home Assistant + HomeKit Bridge** (entity via `philips_js` or REST backend) | HA in homelab; HomeKit Bridge integration | **Yes** — Control Center Home tile + Siri | **Yes** — Home app, Siri, + HA Companion app | **Low–Med** — HA upkeep; possible Philips API quirks | Free (self-hosted) |
| 4 | **Home Assistant + native tvOS client** (Room Board / HA Control / Couch Control) | HA in homelab; ambilight as HA entity; App Store app on the Apple TV | **Yes** — a full dashboard UI **on the TV** (App Store app, **no dev account, no 7-day re-sign**) | Indirectly (HA Companion app on Watch/iPhone is separate) | **Low–Med** — HA upkeep; app is third-party/community | Free (apps free; self-hosted HA) |
| 5 | **Shortcuts "Get Contents of URL"** → REST backend | The REST backend (ideally HTTPS); Shortcuts | **No** (no Shortcuts/browser on tvOS) | **Yes** — iPhone, iPad, **Apple Watch** | **Very low** | Free |
| 6 | **HA dashboard / Companion app** (no HomeKit) | HA in homelab; Companion app or browser | **No** | **Yes** — Companion app / any browser | **Low–Med** — HA upkeep | Free (self-hosted) |

## Pros / cons per option

1. **Re-sign tvOS app**
   - Pros: control lives literally on the TV box; reuses the app you already built; no extra infra.
   - Cons: 7-day expiry forces recurring manual redeploys; no AltStore/SideStore auto-refresh on tvOS;
     no Watch/phone control; loses app data if you delete/re-add instead of overwriting.
2. **Homebridge + HTTP switch**
   - Pros: thin, single-purpose, low-maintenance; native Siri + Apple TV Control Center + Watch via Home app;
     no developer account ever; uses your REST backend directly.
   - Cons: you must keep the REST backend and Homebridge running; initial HomeKit pairing/mDNS setup.
3. **Home Assistant + HomeKit Bridge**
   - Pros: can talk to the Philips TV directly (may make the REST backend optional for HA); dashboards +
     Companion app as bonus; same native Apple control as Homebridge.
   - Cons: heavier to run/maintain than Homebridge; documented Philips API quirks (HTML-vs-JSON, Ambilight+Hue
     switch detection, standby dropouts); HomeKit re-pair if HA IP changes.
4. **HA + native tvOS client (Room Board / HA Control / Couch Control)**
   - Pros: a real **control dashboard on the Apple TV screen** without sideloading — App Store apps, so **no
     developer account and no 7-day re-sign**; direct, local connection to HA with on-device tokens; reuses the
     same HA instance as the HomeKit-bridge route.
   - Cons: not Siri/Watch-native (control is inside the third-party app via the remote); depends on HA running;
     apps are third-party/community (Room Board most polished; HA Control and Couch Control community/beta);
     newer clients need tvOS 18/18.1.
5. **Shortcuts → REST backend**
   - Pros: trivial to build; works great on Watch/iPhone; pairs naturally with the HomeKit route.
   - Cons: nothing on the Apple TV itself; watchOS forces HTTPS, so the backend needs a valid TLS cert.
6. **HA dashboard / Companion app**
   - Pros: rich UI, no Apple constraints, cross-platform.
   - Cons: not on tvOS; less "native Apple" than HomeKit.

## Ranked recommendation

There are two co-leading durable paths; which is "best" depends on whether you weight **native Siri/Watch
integration** or a **dashboard UI on the TV screen** more. Both avoid the developer account and the 7-day churn.

1. **Co-best (most native / Siri / Watch) — REST backend + Homebridge HTTP switch (option 2).** Gives you native
   control from the **Apple TV itself** (Control Center Home tile + Siri, because the Apple TV is your Home hub)
   **and** from **Apple Watch / iPhone** (Home app + Siri), with **no App Store, no developer account, and no
   7-day churn**. Reuses the homelab REST backend and is the lightest thing to run. Best if you want voice and
   wrist control.
2. **Co-best (best on-TV dashboard) — Home Assistant + a native tvOS client (option 4).** A polished client like
   **Room Board** (or HA Control / Couch Control) puts an actual control UI **on the Apple TV screen** — the key
   advantage the HomeKit-only path lacks — via an **App Store app, so still no developer account and no 7-day
   re-sign**. Choose this if you want to point the remote at an on-screen dashboard rather than rely on Siri. It
   needs HA running and the client is third-party/community (Room Board the most refined; the others beta-ish).

   Because both options 2 and 4 can share the same HA instance, you can run them **together**: HomeKit bridge for
   Siri/Watch + a native tvOS HA client for the on-screen dashboard.

3. **Strong alternative — Home Assistant + HomeKit Bridge (option 3),** if you prefer the Siri/Watch path but
   want HA's `philips_js` integration to talk to the TV directly (potentially skipping the REST backend) plus
   dashboards and the Companion app. Slightly more upkeep and some Philips-API rough edges.
4. **Add Shortcuts → REST backend (option 5)** as a complementary quick-trigger for **Apple Watch and iPhone**
   (use HTTPS for watch reliability). Cheap to add on top of any of the above.
5. **Keep the re-signed tvOS app (option 1) only as a temporary stopgap** while you stand up one of the durable
   paths — the manual 7-day re-sign makes it unsuitable long-term, and AltStore/SideStore cannot rescue it on
   tvOS.

Net: stand up **Home Assistant** in the homelab (it serves both durable paths). Add the **HomeKit bridge** for
native Siri/Watch control, and/or install a **native tvOS HA client** (Room Board) for an on-TV dashboard. Use
the re-signed tvOS app only to bridge the gap.

---

## Sources

- https://mybyways.com/blog/new-limitations-imposed-on-free-apple-developer-account
- https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/
- https://news.ycombinator.com/item?id=36023322
- https://kenhv.com/blog/sideloading-on-any-apple-product
- https://github.com/SideStore/SideStore
- https://github.com/rileytestut/AltStore/issues/1037
- https://firt.dev/notes/pwa-ios/
- https://discussions.apple.com/thread/250145661
- https://support.apple.com/en-us/105027
- https://support.apple.com/en-us/102313
- https://www.macrumors.com/how-to/set-up-apple-tv-as-home-hub-homekit/
- https://reolink.com/blog/add-apple-tv-to-homekit/
- https://github.com/homebridge-plugins/homebridge-http-switch
- https://www.npmjs.com/package/homebridge-http-switch
- https://github.com/staromeste/homebridge-http-advanced-accessory
- https://developers.homebridge.io/homebridge/
- https://www.home-assistant.io/integrations/philips_js/
- https://github.com/jomwells/ambilights
- https://github.com/home-assistant/core/issues/73740
- https://www.home-assistant.io/integrations/homekit/
- https://support.apple.com/guide/tv/use-tvos-control-center-atvb5f549664/15.0/tvos/15.0
- https://support.apple.com/guide/tv/monitor-cameras-run-scenes-apple-home-tab-atvb90537bb0/tvos
- https://support.apple.com/guide/shortcuts/request-your-first-api-apd58d46713f/ios
- https://support.apple.com/guide/shortcuts/run-shortcuts-from-apple-watch-apd5888b0858/ios
- https://discussions.apple.com/thread/252082211
- https://discussions.apple.com/thread/253865778
- https://apps.apple.com/us/app/room-board-for-home-assistant/id6756843713
- https://community.home-assistant.io/t/apple-tv-app-for-home-assistant-ha-control/640068
- https://apps.apple.com/us/app/ha-control/id6738877093
- https://community.home-assistant.io/t/couch-control-apple-tv-app-for-ha-homekit/915281
- https://apps.apple.com/us/app/couch-control-for-homekit-ha/id6742379313
- https://www.bensoftware.com/forum/discussion/4273/
