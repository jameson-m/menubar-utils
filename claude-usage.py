#!/usr/bin/env python3
"""SwiftBar plugin to display Claude.ai usage in menu bar."""

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests
from dotenv import load_dotenv

SCRIPT_DIR = Path(__file__).parent
ENV_FILE = SCRIPT_DIR / ".env"
load_dotenv(ENV_FILE)

ORG_ID = os.environ.get("CLAUDE_ORG_ID")
SESSION_KEY = os.environ.get("CLAUDE_SESSION_KEY")


def format_time_until(iso_timestamp: str | None) -> str:
    """Format time until reset as 'Xh Ym' or 'Xd Yh'."""
    if not iso_timestamp:
        return "unknown"
    try:
        reset_time = datetime.fromisoformat(iso_timestamp.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        delta = reset_time - now
        if delta.total_seconds() <= 0:
            return "now"
        total_hours = delta.total_seconds() / 3600
        if total_hours < 24:
            hours = int(total_hours)
            minutes = int((delta.total_seconds() % 3600) / 60)
            return f"{hours}h {minutes}m"
        days = int(total_hours / 24)
        hours = int(total_hours % 24)
        return f"{days}d {hours}h"
    except (ValueError, TypeError):
        return "unknown"


def get_color(pct: float) -> str:
    """Return SwiftBar color based on usage percentage."""
    if pct >= 95:
        return "red"
    if pct >= 80:
        return "orange"
    return ""


def fetch_usage() -> dict | None:
    """Fetch usage data from Claude API."""
    if not ORG_ID or not SESSION_KEY:
        return None
    url = f"https://claude.ai/api/organizations/{ORG_ID}/usage"
    headers = {
        "Cookie": f"sessionKey={SESSION_KEY}",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    }
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code in (401, 403):
            return {"auth_error": True}
        resp.raise_for_status()
        return resp.json()
    except requests.RequestException:
        return None


def main():
    if not ORG_ID or not SESSION_KEY:
        print("C: CFG | color=red")
        print("---")
        print("Missing CLAUDE_ORG_ID or CLAUDE_SESSION_KEY")
        print(f"Edit .env | bash=open param1={ENV_FILE} terminal=false")
        sys.exit(0)

    data = fetch_usage()

    if data is None:
        print("C: --/-- | color=gray")
        print("---")
        print("Network error")
        sys.exit(0)

    if data.get("auth_error"):
        print("C: AUTH | color=red")
        print("---")
        print("Session expired - refresh cookie")
        print("---")
        print("1. Open claude.ai in browser")
        print("2. DevTools > Application > Cookies")
        print("3. Copy sessionKey value")
        print("---")
        print(f"Edit .env | bash=open param1={ENV_FILE} terminal=false")
        sys.exit(0)

    five_hour = data.get("five_hour", {})
    seven_day = data.get("seven_day", {})

    session_pct = five_hour.get("utilization", 0)
    weekly_pct = seven_day.get("utilization", 0)
    session_reset = five_hour.get("resets_at")
    weekly_reset = seven_day.get("resets_at")

    max_pct = max(session_pct, weekly_pct)
    color = get_color(max_pct)
    color_str = f" | color={color}" if color else ""

    print(f"C: {session_pct:.0f}%/{weekly_pct:.0f}%{color_str}")
    print("---")
    print(f"Session: {session_pct:.0f}% (resets in {format_time_until(session_reset)})")
    print(f"Weekly: {weekly_pct:.0f}% (resets in {format_time_until(weekly_reset)})")
    print("---")
    print("Refresh | refresh=true")
    print(f"Edit .env | bash=open param1={ENV_FILE} terminal=false")


if __name__ == "__main__":
    main()
