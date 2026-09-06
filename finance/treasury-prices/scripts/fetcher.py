"""Fetch Treasury historical prices CSV from FedInvest."""
from __future__ import annotations

import asyncio
import csv
import re
from datetime import date
from io import StringIO

import httpx

URL = "https://www.treasurydirect.gov/GA-FI/FedInvest/securityPriceDetail"
SELECT_URL = "https://www.treasurydirect.gov/GA-FI/FedInvest/selectSecurityPriceDate"

_CSRF_RE = re.compile(r'name="_csrf"\s+value="([^"]+)"')

# CSV has no header row. Columns are positional.
_COLUMNS = ("cusip", "security_type", "rate", "maturity_date", "call_date", "buy", "sell", "end_of_day")

# (csrf token, cookies) seeded from SELECT_URL — see _get_session.
_session: tuple[str, httpx.Cookies] | None = None
_session_lock = asyncio.Lock()


async def _get_session() -> tuple[str, httpx.Cookies]:
    """Return a cached (csrf token, cookies) pair, seeding it on first use.

    The CSV endpoint sits behind Spring Security CSRF: a POST carrying neither a
    session cookie nor a `_csrf` field is rejected with 403. Both come from the
    date-picker page, and the token is per-session — one seed serves every date
    fetched by this process.
    """
    global _session
    async with _session_lock:
        if _session is None:
            async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
                r = await client.get(SELECT_URL)
                r.raise_for_status()
                m = _CSRF_RE.search(r.text)
                if not m:
                    raise RuntimeError(f"No CSRF token in {SELECT_URL}")
                _session = (m.group(1), client.cookies)
        return _session


def _reset_session() -> None:
    global _session
    _session = None


async def fetch_prices(d: date) -> list[dict]:
    """POST date to FedInvest CSV endpoint, return list of normalized rows."""
    data = {
        "priceDateDay": str(d.day),
        "priceDateMonth": str(d.month),
        "priceDateYear": str(d.year),
        "fileType": "csv",
        "csv": "CSV FORMAT",
    }

    text = ""
    for attempt in (0, 1):
        token, cookies = await _get_session()
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True, cookies=cookies) as client:
            r = await client.post(URL, data={**data, "_csrf": token})
        # A 403 means the seeded session went stale; re-seed once before failing.
        if r.status_code == 403 and attempt == 0:
            _reset_session()
            continue
        r.raise_for_status()
        text = r.text
        break

    if not text.strip():
        return []

    rows: list[dict] = []
    for raw in csv.reader(StringIO(text)):
        if not raw or all(not c.strip() for c in raw):
            continue
        row = {_COLUMNS[i]: raw[i].strip() if i < len(raw) else "" for i in range(len(_COLUMNS))}
        if row.get("cusip"):
            rows.append(row)
    return rows
