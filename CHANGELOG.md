## 2026-07-09 (4)

- V3 pass on `apps/apache-watchface`: boot ankle shaft widened 1px/side ("a little more chunky"); battery value font down 1 more px (11px) and a new dedicated temperature font (12px, `Fonts.tempValueFont()`) so the Weather box's temp can shrink without affecting HR/steps/solar (which share `metricsFont()`); "WX" text label removed, weather icon shifted into the reclaimed space; Bluetooth + notification bell moved from flanking the Weather box up to flank the Battery/HR row instead (in the bezel-margin gap beside those boxes, vertically positioned where the round-display corner math actually leaves enough width, not the row's literal center); clock HH:MM anchor shifted 5px left of box-center while the seconds readout's position calculation was deliberately left untouched (computed from the original box center, not the shifted one) — this was a client correction of an earlier guess (a 3px shift with dynamically-recomputed seconds) that got interrupted mid-implementation with a stray debug override (`timeStr = "00:00"`) left in the file; removed before this commit. Solar icon nudged 2px left (inset 10→8, matching the Weather icon's inset for consistency).

## 2026-07-09 (3)

- Client polish pass on `apps/apache-watchface`'s V2 layout: battery icon nudged up 1px, its value given a dedicated 1px-smaller font (`Fonts.batteryValueFont()`, scoped to just that field); "HR" text label removed and the heart icon lifted to match the battery box's icon-on-top/value-below structure (resolves the visual inconsistency flagged after the battery change); Steps box widened (right edge 124→150) with its "STP" label re-centered to use the extra room. Boot icon's requested ankle-shaft addition (`tools/generate_hud_icons.py`) is drafted but not yet regenerated/committed — picking up separately.

## 2026-07-09 (2)

- Implemented client V2 spec for `apps/apache-watchface` — tactical MFD layout:
  - `source/ApacheWatchFaceView.mc` rewritten to the client's literal 280x280 pixel coordinate matrix, replacing V1's dynamic circle-geometry layout.
  - `source/ColorScheme.mc` simplified to single-hue Tactical Green (`0x39FF14`), dropping V1's amber/red per-field accents; battery is now the only field with a dynamic override, swapping to Alert Red (`0xFF1E1E`) below 15% charge.
  - `source/HudDraw.mc` — fixed 6px chamfer on panel boxes (was proportional), new `drawChapterRing()` (240° tick gauge, gap at 6 o'clock, verified not to repeat V1's removed gauge's "spiral" bug), `drawBitmapScaledCentered()` (contain-fit scaling via `Dc.drawScaledBitmap`).
  - Custom "MFD-64" font resources from the spec don't exist and Connect IQ's font-resource pipeline expects BMFont atlases, not raw TTF (confirmed by a real compile attempt) — fell back to `Graphics.getVectorFont()` at the spec's 7 exact point sizes instead (`source/Fonts.mc`), verified actually rendering, not silently falling back to system defaults.
  - Found and fixed two real bezel-clipping bugs the hand-worked geometry flagged before implementation: the Weather box and the Bravo4 footer overlapped at the spec'd coordinates; both repositioned slightly (Weather box + footer Y) after visual confirmation via screenshot.
  - `tools/generate_hud_icons.py` recolored all day-mode icons to the single tactical-green scheme (heart/solar dropped their old fixed red/amber).
  - Verified end-to-end: clean compile (`fenix7xpro` + `fenix7xpronowifi`), crash-free `monkeydo` run, ring gauge renders as clean ticks, battery-critical red alert fires correctly, Always-On mode still works after the layout rewrite — all via real screenshots, not assumption.

## 2026-07-09

- Verified `apps/apache-watchface`'s bitmap HUD icon integration (already wired up on disk from a prior uncommitted pass) end-to-end via real compile + `monkeydo` run + simulator screenshots, and confirmed Always-On/sleep mode actually works (flagged unverified in a prior pass):
  - Compiled clean (`BUILD SUCCESSFUL`) and ran via `monkeydo` with no `Error:` crash block; the process stayed alive through both the sleep and wake transitions.
  - Discovered the correct simulator control for triggering Always-On: **Settings → Display Mode → Always-Active** (native Win32 menu, `id=6248`) — not the separate `Settings → Sleep Mode` checkbox, which had no observable effect on the watch face in testing. Documented this in `apps/apache-watchface/README.md`.
  - Screenshotted both modes (native `PrintWindow` capture of the simulator window) and confirmed icon-by-icon: day mode renders all bitmap assets correctly with nothing overlapping (chrome battery + vector fill, red heart, boot, amber solar, weather bucket icon, banner, Bluetooth+bell); Always-On correctly hides the banner and seconds, desaturates every icon/text to a single dim monochrome green, still shows the weather/Bluetooth/notification row (dimmed, since it's live status not decoration), and collapses the weather bucket to the 2-state AOD icon set (`clear`/`overcast`) per spec.
  - Confirmed date field (`THU 09/07`, DD/MM default), always-24-hour clock, and the DD/MM vs MM/DD property were all untouched by the bitmap integration.
  - Updated `apps/apache-watchface/README.md`'s "What's on screen" and "Files" tables, which had gone stale (still described vector-drawn footprint/icon shapes and didn't mention the banner row, the combined weather/Bluetooth/notification row, or the `resources/drawables/hud/` bitmap asset set / `tools/generate_hud_icons.py` generator).

## 2026-07-08 (3)

- Added `.claude/agents/mobius.md` — Garmin Connect IQ / Monkey C watch face specialist agent: legibility checklist (sunlight/glance/Always-On/data-loss/round-display tests), the established `apps/apache-watchface` design spec, the local Connect IQ toolchain paths, a running list of Monkey C compile/runtime gotchas hit during this project, and a battery-optimization checklist.
- Restyled `apps/apache-watchface` to a phosphor-green LCD/HUD look (client-approved concept), then used Mobius to fix legibility issues found via real compile+run+screenshot verification:
  - `source/ColorScheme.mc` — new phosphor-green palette (day: green text/icons + amber solar accent + red heart accent; Always-On: single dim green, fully monochrome), `panelColor()`.
  - `source/HudDraw.mc` — added `drawPanel` (octagon-cut panel outline), `drawDashedLine` (segmented row divider), `lerpColor`; a decorative chapter-ring/gauge-arc addition was built, found to render as a broken spiral, and removed entirely per client feedback ("solar intensity is not important and not really necessary" — distinct from the "next solar event" field, which stays); fixed a real runtime bug where the weather icon wasn't rendering at all (coordinates/sizing, not a compile error — caught only by screenshotting the running simulator).
  - `source/ApacheWatchFaceView.mc` — field layout rewritten to center the whole content stack vertically as a block (top margin == bottom margin by construction) with each row's safe width computed via `safeHalfWidth()` against real circle-radius math instead of eyeballed fractions; time forced to always-24-hour per client request (removed the device 12/24h setting dependency and AM/PM label); row sizing now follows an explicit client-stated priority order (clock+seconds biggest, then weather/temp, solar event, heart rate, steps, battery%).
  - Verified end-to-end multiple times via `monkeyc` (compile) → `monkeydo` (run, checked for `Error:` crash blocks) → a native Win32 `PrintWindow` screenshot of the simulator window, Read back to visually confirm — not just a clean compile, since this project already hit a bug (font loading) that compiled fine and crashed at runtime, and another (weather icon) that ran fine and silently didn't render.

## 2026-07-08 (2)

- Set up a working Connect IQ dev environment and fixed `apps/apache-watchface/` to actually compile and run:
  - Installed Connect IQ SDK 9.2.0, fenix7xpro/fenix7xpronowifi device files + simulator fonts, Microsoft OpenJDK 17, and the `garmin.monkey-c` VS Code extension; generated a developer signing key (`~/.garmin/developer_key.der`, outside the repo).
  - Fixed 5 real compile errors found via `monkeyc`: `private` on a `module` function (not supported, only `class` allows it) in `HudDraw.mc`; missing `import Toybox.Lang;` in `ColorScheme.mc`; `getInitialView()`'s return type needed Monkey C's tuple-array syntax (`[Views] or [Views, InputDelegates]`); `fillPolygon()` point arrays needed `Array<[Numeric, Numeric]>` tuple typing; `settings.xml`'s DD/MM date-format picker used a `list` config on a `boolean` property (only valid on `number`/`string`), so `dateFormatDDMM` became a `number` property.
  - Fixed a runtime crash (`Invalid Font Specified` on the first `drawText()` call, any font): device *fonts* are a separate download from the device profile — fixed by re-downloading with `--include-fonts`.
  - Swapped `FONT_NUMBER_THAI_HOT` for `FONT_NUMBER_HOT` for the center clock (Thai locale font pack not needed since the manifest only declares `eng`).
  - Confirmed both `fenix7xpro` and `fenix7xpronowifi` device ids build and run cleanly in the simulator (`monkeydo`, no crash) — resolves the device-id ambiguity flagged in the first pass.
  - Regenerated the launcher icon at 40x40 (was 80x80, wrong size for this device, `tools/generate_launcher_icon.py`).
  - `README.md` — documents the now-verified local setup, the sideload/distribution mechanics (a signed `.prg` can be emailed and installed on any matching-device watch without it ever touching this machine), and the bugs found for future reference.

## 2026-07-08

- Added new standalone app `apps/apache-watchface/` — Garmin Connect IQ watch face for the fenix 7X Pro Sapphire Solar, styled like an AH-64E cockpit HUD/MFD:
  - `source/ApacheWatchFaceView.mc` — main draw loop: center HH:MM with smaller seconds, battery/heart-rate/steps/solar-event/date/weather fields, day vs. Always-On (monochrome, seconds hidden) rendering.
  - `source/DataCache.mc` — throttled sensor refresh (weather every 15/45 min awake/asleep, heart rate every 5/60s awake/asleep, solar event once per day).
  - `source/HudDraw.mc` — vector-drawn HUD icons (battery, heart, footprints, sun, weather) and a `Weather.CONDITION_*` → sunny/cloudy/rain/snow/storm icon mapper.
  - `source/ColorScheme.mc` — white/cyan/yellow/red day palette vs. monochrome Always-On palette.
  - `resources/` — DD/MM vs MM/DD date-format setting, launcher icon (generated via `tools/generate_launcher_icon.py`).
  - `README.md` — Connect IQ SDK/VS Code local setup, build, sideload, and Connect IQ Store publishing steps, plus flagged unknowns (device id string, API constants) to verify on first build since the SDK wasn't available to compile-test in this environment.

## 2026-03-02 (4)

- Added gameplay loop to `apps/m20-game/` — buildings, monster groups, combat narration:
  - `internal/resources/monster_groups.go` — thematic monster groups per building type (e.g. Zombie Classroom, Vampire Detective Agency, Werewolf Pack). Every building has 2–3 curated groups; group is randomised on tile generation.
  - `internal/game/tile.go` — tile now carries `[]BuildingInstance`, each with a pre-populated `MonsterGroup`. Building count scales with tile danger (2–4 buildings).
  - `internal/ai/ollama.go` — expanded with `BuildingEntrance`, `MonsterDialogue`, `CombatHit`, `CombatMiss`, `MonsterDefeated` methods; per-monster fallback lines for all 10 monsters.
  - `cmd/server/main.go` — added `POST /api/building/enter` (entrance flavor + group) and `POST /api/combat/encounter` (D20 roll + AI narration + hit/miss).
  - `web/static/js/game.js` — full gameplay loop: Map → Click Tile → Building List → Enter Building → Monster Group → Combat → Loot/XP.
  - `web/static/index.html` — new tile-panel (building list), building-panel (monster group + combat section).
  - `web/static/css/style.css` — new classes: building rows, monster cards, HP bar (green/orange/red), combat section, cleared-victory state.
  - `web/static/js/admin.js` + `admin.html` — test cards for both new endpoints with Ollama status feedback.
  - `.claude/agents/agon.md` — new gameplay loop specialist agent (Agon, Greek personification of contest).

## 2026-03-02 (3)

- Added `.claude/agents/` — native Claude Code sub-agent persona team:
  - 9 agents: Pixel (UI), Gopher (Backend), Bridge (API), Vera (QA), Charity (SRE), Terra (DevOps), Cipher (Security), Droid (Mobile), Atlas (PM)
  - Each agent has full project context, tech expertise, "Everything Has an Experience" philosophy, red flags, and team dynamics
  - Invokable via `/agents` or natural language in any Claude Code session
  - `.agents/README.md` documents the team roster and how to use them

## 2026-03-02 (2)
- Added `apps/m20-game/` — full M20 RPG game engine, Phase 2 of the platform roadmap:
  - `cmd/server/main.go` — HTTP server with all 12 REST endpoints, SRE middleware, structured JSON errors, Prometheus metrics.
  - `internal/game/` — D20 combat engine, tile/land generation, scavenging, building explore, vehicle find.
  - `internal/character/` — Character model, random generator (8 classes), SQLite persistence via `modernc.org/sqlite` (no CGO).
  - `internal/resources/` — Static game data: 8 classes, 10 monsters, 10 tile types, 14 supplies, 6 craftable items, 6 vehicles.
  - `internal/ai/ollama.go` — Ollama HTTP client for Sphinx riddles and monster dialogue; graceful fallback if Ollama unavailable.
  - `internal/obs/` — Prometheus metrics (promauto), alert rules (4 rules), Prometheus scrape config.
  - `web/static/` — jQuery 3.7.1 game UI, admin dashboard, post-apocalyptic dark CSS, PWA manifest.
  - `dockerfile` — Multi-stage Alpine build, non-root user (`m20:m20`), exposes 8082.
  - `docker-compose.yml` — m20-game + Ollama + Prometheus + Grafana.
  - `Makefile`, `scripts/` — bootstrap, unit_test, chaos_test (real 404 validation fixed from weather-service).
  - README.md in every directory.

## 2026-03-02

- Fixed `apps/weather-service/scripts/bootstrap/bootstrap.sh`:
  - Replaced deprecated `docker-compose` (hyphen CLI) with `docker compose` on all 4 invocations.
  - Corrected Grafana credentials hint — anonymous admin is enabled, no login required.

## 2026-03-02 (initial)

- Added `.gitignore` to exclude build artifacts and sensitive files:
  - Covers `bin/`, root `weather-api` binary, `coverage.out`, `coverage.html`, `vendor/`, `.env`, editor configs, and OS files.
  - Removed `bin/weather-api` and root `weather-api` binaries that were previously committed to the repo.
- Added `CLAUDE.md` for Claude Code session context:
  - Documents architecture, key commands, endpoints, chaos engineering chain, Prometheus metrics/alerts, and important code patterns.
  - Reduces per-session AI exploration token cost by ~20k–35k tokens.
## 2026-02-20

- **Lint hardening (weather-service)**:
  - Fixed `errcheck` findings by handling return values from `w.Write`, `json.NewEncoder(...).Encode`, deferred Redis `Close`, and `http.ListenAndServe`.
  - Fixed `staticcheck SA1029` by replacing string context keys with typed helpers in `internal/weather/client.go` (`WithChaosTrigger`, `ChaosTrigger`) and updating call sites.
  - Applied `gofmt` to all touched files.
- **Tests & validation**:
  - Ran full package tests in `apps/weather-service` via `go test -v ./...` (pass).
  - Ran script-based full test suite via `bash ./scripts/unit_test/unit_test.sh` (pass, coverage produced).
  - Ran chaos validation via `./scripts/chaos_test/chaos_test.sh` (pass).
- **Repo hygiene**:
  - Added root `.gitignore` for Go build artifacts, coverage files, local env/log/temp files, binaries, and macOS/editor noise.
- **Docs**:
  - Updated `GEMINI.md` to reflect typed context key strategy and lint reliability hardening.
  - Updated `apps/weather-service/README.md` with a concise quality/testing command section.

## 2026-02-19 (rieger-mastering-hpa branch)

- **Redis queue + KEDA**: Weather service now consumes jobs from Redis (`weather:jobs`). KEDA scales workers based on queue backlog. Chaos test loads 800 jobs to simulate demand.
- **Restructure**: Moved Go app to `apps/weather-service/`. Root README is now SRE lab overview.
- **Observability**: Added `redis-exporter`, Grafana "Redis Queue & KEDA Scaling" dashboard, `weather_queue_length` and `weather_jobs_processed_total` metrics, `Queue_Backlog_High` alert.
- **Dashboard UI**: Links to Grafana, Prometheus, Redis Exporter, Queue Stats, chaos load.
- **K8s**: Manifests in `platform/local/k8s/weather-service/` (Redis, weather-service, KEDA ScaledObject, HPA, VPA).
- **Scripts**: `scripts/local/kind_up.sh`, `compose_up.sh`, `compose_down.sh`, `kind_down.sh`.
- **CI**: `.github/workflows/ci.yml` — test, lint, Docker build, govulncheck.
- **Docs**: `docs/overview.md`, `docs/keda.md`, `docs/scaling-hpa-vpa.md`.

## 2026-02-17

- Aligned HTTP metrics with Prometheus:
  - Centralized metric definitions in `internal/obs/metrics.go` (`HttpRequestsTotal` and `HttpRequestDuration` with `path`, `method`, `code`, `status_text`).
  - Updated `cmd/server/main.go` to use `obs` metrics and keep routing/SRE logic focused.
- Reorganized observability configuration:
  - Moved `prometheus.yml`, `alert_rules.yml`, and `alertmanager.yaml` into `internal/obs/`.
  - Updated `docker-compose.yml` to mount configs from `internal/obs`.
- Standardized scripts and documentation:
  - Created `scripts/` hierarchy with per-script READMEs (`bootstrap`, `chaos_test`, `unit_test`).
  - Updated `README.md`, `GEMINI.md`, and dashboard title to match the new structure and neutral naming.
- Strengthened testing posture:
  - Fixed and expanded `internal/weather/client_test.go` to cover cache hits/misses and chaos priority.
  - Added handler, middleware, and integration tests under `cmd/server/`.
  - Updated `scripts/unit_test/unit_test.sh` and `Makefile` to run the full suite with coverage reporting.

