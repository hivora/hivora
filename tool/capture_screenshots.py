#!/usr/bin/env python3
"""Capture deterministic app screenshots from the built Flutter web bundle.

Pipeline (all local, no flaky UI automation):
  1. serve build/web with correct MIME types,
  2. log in to the demo backend to obtain a token pair,
  3. for each (form-factor, route): open a Playwright browser context at the
     device's exact logical viewport + DPR, pre-seed SharedPreferences in
     localStorage (server URL + tokens + onboarding) so the app boots straight
     into the authenticated shell, navigate by hash route, screenshot the canvas.

Raw, unframed PNGs land in docs/screenshots/raw/. Feed them to device_frames.py.

Prereqs: a running demo server (HINATA_DEMO_SEED=true) and `flutter build web`.
Run with the tool venv:  tool/.venv/bin/python tool/capture_screenshots.py
"""
from __future__ import annotations

import functools
import http.server
import json
import os
import socketserver
import threading
import time

import requests
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB_DIR = os.path.join(ROOT, "build", "web")
OUT_DIR = os.path.join(ROOT, "docs", "screenshots", "raw")

API = os.environ.get("HINATA_API", "http://localhost:8080")
WEB_PORT = int(os.environ.get("WEB_PORT", "8081"))   # must be CORS-allowed by the server
WEB_ORIGIN = f"http://localhost:{WEB_PORT}"
LOGIN = {"identifier": "rebar", "password": "hinata-demo-2026"}

# Device viewports sized to the real Apple frames' screen cut-outs (1:1, no crop).
# Desktop = 16" MacBook "looks like" 1728x1117 -> 3456x2234 screen.
# Mobile  = iPhone 17 Pro Max minus a 44pt status-bar band the framer adds back
#           (912 + 44 = 956pt -> 1320x2868 screen).
DESKTOP = (1728, 1117, 2)
MOBILE = (440, 912, 3)

def build_shots(board_id):
    """(name, form, route). {board} is the live Scrum board's kanban route."""
    board = f"/boards/{board_id}"
    return [
        ("desktop_dashboard", DESKTOP, "/dashboard"),
        ("desktop_board",     DESKTOP, board),
        ("desktop_reports",   DESKTOP, "/reports"),
        ("desktop_gantt",     DESKTOP, "/gantt"),
        ("mobile_dashboard",  MOBILE,  "/dashboard"),
        ("mobile_issues",     MOBILE,  "/issues"),
        ("mobile_reports",    MOBILE,  "/reports"),
        ("mobile_board",      MOBILE,  board),
    ]


def first_board_id(access):
    r = requests.get(f"{API}/api/v1/boards",
                     headers={"Authorization": f"Bearer {access}"}, timeout=10)
    r.raise_for_status()
    data = r.json()
    data = data if isinstance(data, list) else data.get("content", [])
    return data[0]["id"]


class _Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript", ".mjs": "text/javascript",
        ".wasm": "application/wasm", ".json": "application/json",
        ".css": "text/css", ".html": "text/html",
    }

    def log_message(self, *a):  # quiet
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def serve():
    handler = functools.partial(_Handler, directory=WEB_DIR)
    httpd = socketserver.ThreadingTCPServer(("127.0.0.1", WEB_PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def login():
    r = requests.post(f"{API}/api/v1/auth/login", json=LOGIN, timeout=10)
    r.raise_for_status()
    d = r.json()
    return d["accessToken"], d["refreshToken"]


def init_script(access, refresh):
    prefs = {
        "flutter.server_url": API,
        "flutter.access_token": access,
        "flutter.refresh_token": refresh,
        "flutter.onboarding_done": True,
        "flutter.locale": "en",
    }
    lines = [f"localStorage.setItem({json.dumps(k)}, {json.dumps(json.dumps(v))});"
             for k, v in prefs.items()]
    return "\n".join(lines)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    httpd = serve()
    access, refresh = login()
    shots = build_shots(first_board_id(access))
    print(f"logged in — token {len(access)} chars; serving {WEB_DIR} at {WEB_ORIGIN}")
    seed = init_script(access, refresh)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        try:
            for name, (w, h, dpr), route in shots:
                ctx = browser.new_context(
                    viewport={"width": w, "height": h},
                    device_scale_factor=dpr,
                    color_scheme="light",
                    base_url=WEB_ORIGIN,
                )
                ctx.add_init_script(seed)
                page = ctx.new_page()
                page.goto(f"{WEB_ORIGIN}/#{route}", wait_until="domcontentloaded")
                # let CanvasKit boot, fetch data and settle animations
                page.wait_for_timeout(7000)
                out = os.path.join(OUT_DIR, f"{name}.png")
                page.screenshot(path=out)
                print(f"  shot {name:18} {w}x{h}@{dpr} {route} -> {out}")
                ctx.close()
        finally:
            browser.close()
    httpd.shutdown()
    print("done.")


if __name__ == "__main__":
    main()
