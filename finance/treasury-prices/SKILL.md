---
name: treasury-prices
description: Look up U.S. Treasury historical prices (buy, sell, end-of-day clean prices per 100 face value) for any CUSIP and date, and compute the full invoice value of a TIPS — inflation-adjusted principal, accrued interest, and dirty price. Use when the user asks about Treasury security prices, a CUSIP's quote on a date, TIPS inflation adjustment, CPI index ratios, or what a Treasury bill/note/bond/TIPS position is worth. Data comes from TreasuryDirect FedInvest and the TA_WS API.
version: 1.0.0
---

# Treasury Prices

Query U.S. Treasury market-based security prices and value TIPS positions.

## Prerequisites

Requires `httpx`. Install once:

```bash
pip install -r requirements.txt
```

## Commands

Run from the skill directory. Every command prints JSON to stdout; add `--text` for an aligned table. Errors print to stderr and exit non-zero.

| Command | Purpose |
| --- | --- |
| `get-price` | One price row for a CUSIP on a date. |
| `list-prices` | All price rows for a date, optionally filtered by security type. |
| `tips-value` | Full invoice value of a TIPS on a date. |

### get-price

```bash
python scripts/treasury.py get-price --cusip 91282CGW5 --date 2026-05-05
```

Returns `cusip`, `security_type`, `rate`, `maturity_date`, `call_date`, `buy`, `sell`, `end_of_day`. All three prices are clean prices per 100 face value.

### list-prices

```bash
python scripts/treasury.py list-prices --date 2026-05-05
python scripts/treasury.py list-prices --date 2026-05-05 --type TIPS --text
```

`--type` is a case-insensitive substring match against the security type — `TIPS`, `BILL`, `NOTE`, `BOND`, `FRN`. TIPS rows are labeled just `TIPS`; the others are labeled `MARKET BASED NOTE`, `MARKET BASED BILL`, and so on.

### tips-value

```bash
python scripts/treasury.py tips-value --cusip 91282CGW5 --date 2026-05-05
python scripts/treasury.py tips-value --cusip 91282CGW5 --date 2026-05-05 --face-value 25000 --price-type sell
```

Options: `--face-value` (par in dollars, default 1000), `--price-type` (`buy`, `sell`, or `end_of_day`, default `end_of_day`).

Returns the daily CPI index ratio, reference CPI, inflation-adjusted principal, inflation-adjusted price (per 100 and in dollars), coupon dates, accrued interest, and `full_price` — the dirty price in dollars.

## Price types

FedInvest publishes three clean prices per security: `buy`, `sell`, `end_of_day`.

- `end_of_day` is the most accurate for settled dates.
- `end_of_day` is **zero for the current trading day** — it is not published until after the close. If `tips-value` fails with "zero or missing", rerun with `--price-type sell`.

## Other behavior

- Dates are always `YYYY-MM-DD`.
- Weekends and holidays return an empty result. FedInvest publishes nothing on non-trading days — this is not an error.
- The price cache lives only for one process, so each invocation fetches a date at most once. Prefer one `list-prices` call over many `get-price` calls when you need several CUSIPs for the same date.
- The price source requires a session handshake, so each invocation makes one extra request before its first fetch. This is automatic.
