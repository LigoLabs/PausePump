# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PausePump is a **zero-dependency, no-build static PWA** (vanilla HTML/CSS/JS) — a rest-timer for weightlifting. The entire web app is `index.html` + `css/styles.css` + `js/app.js` + `sw.js`. There is no framework, no bundler, no package.json, and no test suite. UI text and most code comments are in **French**; keep that convention.

A **native mobile app (Flutter)** lives in `mobile/` (Android + iOS), porting the same flows, plus a **native watchOS app (SwiftUI)** and an **iOS Live Activity** (`mobile/ios/`, `mobile/watch_engine/`). The web PWA at the repo root stays the web target. These are independent codebases — see `mobile/README.md`. Note: the `advancePhase` state machine exists in three places (JS here, Dart in `mobile/lib/state/timer_controller.dart`, Swift in `mobile/watch_engine/`) — keep them in sync when changing transition logic. Everything below this line concerns the **web** app.

## Commands

```bash
# Run locally (any static server works)
python3 -m http.server 8000        # then open http://localhost:8000

# Syntax-check after editing JS (there are no tests — do this every time)
node --check js/app.js
node --check sw.js

# Regenerate PNG icons (pure Node, no deps) if the icon design changes
node scripts/gen-icons.js
```

There is no lint or test command. "Verifying" a change means `node --check` plus reasoning through the state machine (and, ideally, loading the app in a browser).

## Cache-busting & versioning (read before deploying)

The string `__BUILD_VERSION__` appears in `index.html`, `sw.js`, and `js/app.js`. **CI replaces it with the commit SHA** (`sed` step in `.github/workflows/deploy.yml`); locally it stays literal and the app treats that as `dev`. Consequences:

- **Never hand-edit version numbers** — cache-busting is automatic per commit.
- The service worker cache name and the `?v=...` asset URLs are derived from this version, so every commit invalidates the old cache cleanly.
- **When you add a new static asset** (icon, etc.), add it to the `ASSETS` array in `sw.js` or it won't be cached / available offline.

Deployment is automatic: GitHub Actions publishes to GitHub Pages on push to `main` or the active `claude/*` branch. Because the app is served from the `/PausePump/` sub-path, **all asset references must be relative** (`./...`), especially in `sw.js`.

## Architecture

### Screens vs. views
There are two top-level `<section class="screen">` elements (`#screen-home`, `#screen-main`) toggled by `showScreen()`. Inside `#screen-main`, gameplay is a set of **views** (`setup`, `duration`, `doset`, `timer`, `done`) registered in the `views` object and switched with `showView()`. The top bar (series counter + timeline) lives outside the views and stays visible except on the `done` view.

### Core state (top of `js/app.js`)
- `rt` — runtime state (current phase, remaining time, `seriesRemaining`/`seriesTotal`, and timeline progress fields `tlDots`/`tlBars`/`tlFrac`). Not persisted.
- `settings` — persisted to `localStorage` (`STORE_SETTINGS`); merged over `DEFAULT_SETTINGS`, so new keys are added there and default safely for existing users.
- `session` — last-used config, persisted (`STORE_SESSION`). `session.pause`/`effort`/`rest` double as the "last selected duration" (used by the Space shortcut).

### Modes
`session.mode` is `'pause'` (Pause seule) or `'effort'` (Effort + Pause). Effort mode further splits on `session.effortAuto`: auto-chaining vs. "à chaque étape" (manual, pick a duration before each phase). The `doset` ("Fais ta série") screen and several behaviors are pause-mode-only.

### Phase state machine (the heart of the app)
`startPhase()` starts a countdown driven by `setInterval(loop, 200)`. `loop()` decrements `rt.remaining` and calls `onPhaseComplete()` at zero. **`advancePhase()` is the single source of truth for "what's next"** and is shared by both natural completion (`onPhaseComplete`) and the manual Skip button (`skipSeries`) — change phase-transition logic there, not in two places. It branches on mode/phase to decide: next pause, next effort, the do-set screen, the duration picker, or `finishSession()`.

### Timeline progress model
The top progress bar is built once by `renderTimeline()` (DOM rebuilt only when the dot count changes) and updated each tick by `updateTimelineProgress()`/`timelineState()`. In **pause mode** it is granular: a dot fills the moment a set is validated (counter decrements then, not at pause end), and the connecting bar fills proportionally to the running rest timer. In **effort mode** it uses a simpler `done = total - remaining` model.

### Audio engine (no audio files)
All sounds are synthesized via Web Audio. `SOUNDS` entries reference `TIMBRE` partial sets; `scheduleVoice()` renders one note through a shared master compressor bus (`getMaster`). Two entry points share this engine:
- `playSound()` — immediate preview.
- `scheduleAlarm()` — schedules the end beep on the **audio clock** so it fires reliably even when the JS thread is frozen in the background. `startKeepAlive()` plays a near-silent looping buffer to keep the AudioContext (and thus background timers) alive.

iOS caveat: audio is cut when the screen locks; background reliability is effectively Android-only.

### Notifications
Shown only while `document.hidden` (guarded in `showTimerNotification`/`showFinishNotification`). The timer notification is **issued once** — when backgrounding (`visibilitychange`) and on phase change (`resumeTimer`) — and shows the **absolute end time** (`fin à HH:MM`), not a ticking countdown. This is deliberate: a PWA's JS is frozen in the background, so re-issuing every second produced a jumpy notification that appeared to "relaunch" (a native app avoids this via a foreground service + Android's `setChronometerCountDown`, neither available to web). On return to foreground, notifications are cleared aggressively (`clearAllNotificationsSoon`, plus a `CLEAR_NOTIFS` postMessage to the service worker, which is the most reliable way to close them). The notification **`badge`** must be a transparent monochrome PNG (`icons/badge-96.png`) — a fully opaque icon renders as a white square in the Android status bar.

### PWA update flow
`sw.js` does **not** `skipWaiting` automatically. When a new version is waiting, the page shows the update banner; clicking it posts `SKIP_WAITING`, and the `controllerchange` event triggers a reload. The banner is anchored at the top and the screen reserves top space for it so the bottom CTA never shifts. Screen height uses `svh` (not `dvh`) so the bottom button doesn't slide when the mobile address bar collapses.

### Keyboard shortcut
A global `keydown` handler makes **Space** context-aware (for Bluetooth clickers at the gym): validate the set on the `doset` view, or launch the last-selected duration on the `duration` view. The hint keycap is hidden on touch devices via `@media (pointer: coarse)`.
