# treasury-prices

A Claude Code skill exposing U.S. Treasury historical prices and TIPS valuation as a command-line tool.

## Data sources

1. **FedInvest historical prices** — buy, sell, and end-of-day clean prices per 100 face value for all market-based Treasury securities on a given date. Fetched from `treasurydirect.gov/GA-FI/FedInvest/securityPriceDetail`.
2. **TreasuryDirect TA_WS** — security metadata and daily CPI index ratios, used to compute the inflation-adjusted full invoice price of a TIPS.

## Install

The leaf folder `finance/treasury-prices/` is the installable unit. Copy it to `~/.claude/skills/treasury-prices/` and install its one runtime dependency:

```bash
pip install -r ~/.claude/skills/treasury-prices/requirements.txt
```

Or let `skill-version-check` do the copy. Claude discovers the skill from its `SKILL.md`.

## Commands

| Command | Purpose |
| --- | --- |
| `get-price` | Single price row for a CUSIP on a date. |
| `list-prices` | All price rows for a date, optionally filtered by security type substring (`TIPS`, `BILL`, `NOTE`, ...). |
| `tips-value` | Full invoice value of a TIPS — inflation-adjusted principal, accrued interest, and dirty price. |

Run from the installed skill directory:

```bash
python scripts/treasury.py get-price --cusip 91282CGW5 --date 2026-05-05
python scripts/treasury.py list-prices --date 2026-05-05 --type TIPS --text
python scripts/treasury.py tips-value --cusip 91282CGW5 --date 2026-05-05 --face-value 25000 --price-type sell
```

Output is JSON on stdout by default; `--text` prints an aligned table instead. Errors go to stderr with exit code 1. Dates are always `YYYY-MM-DD`.

## Notes on price types

FedInvest publishes three clean prices per security: `buy`, `sell`, `end_of_day`. `end_of_day` is the most accurate for settled dates, but it is zero for the current trading day until the close-of-day file is published. If `tips-value` fails with "zero or missing", retry with `--price-type sell`.

Weekends and holidays return an empty result — FedInvest publishes nothing on non-trading days, and this is not an error.

## Development

The test suite lives at the family level, in `finance/`, deliberately outside the installed leaf. Run it from `finance/` — `pytest.ini`'s `pythonpath` is relative to that folder:

```bash
pip install -r requirements-dev.txt
pytest -m "not integration"   # unit tests
pytest -m integration         # hits live TreasuryDirect / FedInvest
pytest                        # all
```

See `finance/CLAUDE.md` for the architecture and the upstream quirks worth knowing before changing `scripts/`.
