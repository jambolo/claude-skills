#!/usr/bin/env python3
"""Treasury prices and TIPS valuation CLI.

Subcommands print JSON to stdout by default; --text prints an aligned table
instead. Errors go to stderr with a non-zero exit code.

Two data sources:

1. FedInvest historical prices (fetcher.py) — buy/sell/end_of_day clean prices
   per 100 face value for all market-based Treasury securities on a date.

2. TreasuryDirect TA_WS (tips.py) — security metadata and the daily CPI index
   ratio used to compute the inflation-adjusted full invoice price of a TIPS.

The price cache lives only for the duration of one process, so a single
invocation fetches each date at most once.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import date, datetime
from decimal import Decimal

from cache import PriceCache
from fetcher import fetch_prices
from tips import compute_tips_value

PRICE_TYPES = ("buy", "sell", "end_of_day")

cache = PriceCache()


def _parse_date(s: str) -> date:
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError as e:
        raise ValueError(f"Invalid date '{s}'. Expected YYYY-MM-DD.") from e


# --- Core helpers: single source of truth for every subcommand. ---

async def _load_rows(price_date: str) -> list[dict]:
    d = _parse_date(price_date)
    return await cache.get_or_fetch(d, fetch_prices)


async def _load_row(price_date: str, cusip: str) -> dict:
    d = _parse_date(price_date)
    await cache.get_or_fetch(d, fetch_prices)
    row = await cache.lookup(d, cusip.strip().upper())
    if not row:
        raise ValueError(f"CUSIP {cusip} not found for {price_date}")
    return row


def _filter_by_type(rows: list[dict], security_type: str | None) -> list[dict]:
    if not security_type:
        return rows
    st = security_type.lower()
    return [r for r in rows if st in r.get("security_type", "").lower()]


# --- Commands. ---

async def cmd_get_price(args) -> dict:
    """Price row for a CUSIP on a date (buy, sell, end_of_day clean prices per 100 face)."""
    return await _load_row(args.date, args.cusip)


async def cmd_list_prices(args) -> list[dict]:
    """All price rows for a date, optionally filtered by security type substring."""
    rows = await _load_rows(args.date)
    return _filter_by_type(rows, args.type)


async def cmd_tips_value(args) -> dict:
    """Full invoice value of a TIPS: inflation-adjusted principal, accrued interest, dirty price."""
    if args.price_type not in PRICE_TYPES:
        raise ValueError(f"--price-type must be one of {sorted(PRICE_TYPES)}")

    row = await _load_row(args.date, args.cusip)
    raw_price = row.get(args.price_type, "")

    if not raw_price or Decimal(raw_price) == 0:
        raise ValueError(
            f"Price type '{args.price_type}' is zero or missing for {args.cusip} on {args.date}. "
            "Try a different --price-type."
        )

    return await compute_tips_value(
        cusip=args.cusip.strip().upper(),
        price_date=_parse_date(args.date),
        quoted_price=Decimal(raw_price),
        face_value=Decimal(str(args.face_value)),
    )


# --- Rendering. ---

_ROW_COLUMNS = ("cusip", "security_type", "rate", "maturity_date", "call_date", "buy", "sell", "end_of_day")


def _render_table(rows: list[dict]) -> str:
    if not rows:
        return "(no rows)"
    cols = [c for c in _ROW_COLUMNS if c in rows[0]] or list(rows[0])
    widths = {c: max(len(c), *(len(str(r.get(c, ""))) for r in rows)) for c in cols}
    lines = ["  ".join(c.upper().ljust(widths[c]) for c in cols)]
    lines += ["  ".join(str(r.get(c, "")).ljust(widths[c]) for c in cols) for r in rows]
    return "\n".join(lines)


def _render_pairs(d: dict) -> str:
    width = max(len(k) for k in d)
    return "\n".join(f"{k.ljust(width)}  {v}" for k, v in d.items())


def _render_text(result) -> str:
    if isinstance(result, list):
        return _render_table(result)
    return _render_pairs(result)


# --- Entry point. ---

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="treasury",
        description="U.S. Treasury historical prices and TIPS valuation.",
    )
    p.add_argument("--text", action="store_true", help="Print an aligned table instead of JSON.")
    sub = p.add_subparsers(dest="command", required=True)

    gp = sub.add_parser("get-price", help=cmd_get_price.__doc__)
    gp.add_argument("--cusip", required=True, help="9-character Treasury CUSIP.")
    gp.add_argument("--date", required=True, help="Price date, YYYY-MM-DD.")
    gp.set_defaults(func=cmd_get_price)

    lp = sub.add_parser("list-prices", help=cmd_list_prices.__doc__)
    lp.add_argument("--date", required=True, help="Price date, YYYY-MM-DD.")
    lp.add_argument("--type", help='Case-insensitive security type substring, e.g. "TIPS", "BILL", "NOTE".')
    lp.set_defaults(func=cmd_list_prices)

    tv = sub.add_parser("tips-value", help=cmd_tips_value.__doc__)
    tv.add_argument("--cusip", required=True, help="9-character CUSIP of a TIPS security.")
    tv.add_argument("--date", required=True, help="Price / settlement date, YYYY-MM-DD.")
    tv.add_argument("--face-value", type=float, default=1000.0, help="Par amount in dollars (default 1000).")
    tv.add_argument(
        "--price-type",
        default="end_of_day",
        choices=PRICE_TYPES,
        help="Which FedInvest price to use (default end_of_day; use sell for the current day).",
    )
    tv.set_defaults(func=cmd_tips_value)

    return p


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        result = asyncio.run(args.func(args))
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(_render_text(result) if args.text else json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
