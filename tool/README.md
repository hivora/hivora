# `tool/` — brand assets, demo data & screenshots

Developer tooling for the visual side of Hinata. Everything here is local and
reproducible; nothing runs in CI by default.

| Script | What it does |
| --- | --- |
| `gen_brand_assets.py` | Renders every app icon / splash PNG from the hex-mark (pure stdlib). |
| `device_frames.py` | Drops a screenshot into a real Apple frame (`frames/macbook.png`, `frames/iphone.png`). |
| `capture_screenshots.py` | Drives the built web app to capture the README screenshots. |
| `frames/` | The genuine transparent-screen device frames (16" MacBook · iPhone 17 Pro Max). |
| `lucide_icon_map.txt` | Material → Lucide icon mapping reference. |

## Demo data (reusable dev cluster)

The server seeds a realistic, English demo workspace on boot when
`HINATA_DEMO_SEED=true` (see `hinata-server/.../demo/DemoSeeder.java`). It is
**idempotent** — it does nothing once any project exists — and it completes
first-run setup, so a fresh database becomes login-ready immediately.

```bash
# in hinata-server/ — against the standard dev stack, or any local Mongo
SPRING_PROFILES_ACTIVE=dev HINATA_DEMO_SEED=true ./mvnw spring-boot:run
```

Seeds 6 users, 2 teams, 3 projects (`HIN`, `MOB`, `INF`), a Scrum board with
three sprints (Sprint 24 active), ~49 issues across states/assignees/points with
start-due dates + dependencies, and a week of tracked work.

**Login:** `rebar` / `hinata-demo-2026` (admin). Every demo account shares that
password.

## Regenerating the README screenshots

Deterministic, no flaky UI automation: the web bundle is served locally, the app
is pre-authenticated via `localStorage`, and each screen is captured at the exact
device viewport, then framed.

```bash
# 1. one-time: Python venv with Pillow + Playwright
python3 -m venv tool/.venv
tool/.venv/bin/pip install Pillow playwright requests
tool/.venv/bin/python -m playwright install chromium

# 2. a seeded server must be running on :8080 (see "Demo data" above),
#    reachable from the web origin — keep localhost:8081 in HINATA_CORS_ALLOWED_ORIGINS

# 3. build the web bundle, capture, frame
flutter build web --release
tool/.venv/bin/python tool/capture_screenshots.py          # -> docs/screenshots/raw/*.png
for s in dashboard board gantt reports; do
  tool/.venv/bin/python tool/device_frames.py macbook docs/screenshots/raw/desktop_$s.png docs/screenshots/desktop-$s.png
done
for s in dashboard board issues; do
  tool/.venv/bin/python tool/device_frames.py iphone docs/screenshots/raw/mobile_$s.png docs/screenshots/mobile-$s.png
done
```

`device_frames.py <macbook|iphone> in.png out.png` is standalone and reusable —
e.g. for a future `fastlane` App Store screenshot lane. It auto-detects the
frame's transparent screen cut-out (flood-fill), drops the shot in at the exact
rounded corners with the notch / Dynamic Island as chrome on top, and
synthesizes a slim iOS status bar for the phone so the island clears the app bar.
The capture viewports are sized to the frames' screens for a 1:1 fit (desktop
1728×1117 @2 → 3456×2234; phone 440×912 @3 + a 44 pt status bar → 1320×2868).

The venv and the raw (un-framed) captures are git-ignored; only the framed PNGs
under `docs/screenshots/` are committed.
