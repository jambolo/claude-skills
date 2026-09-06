# CLAUDE.md — `finance` family

Guidance for the `treasury-prices` skill. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## Family layout

Unlike the other families, this one carries a runnable test suite. The split matters: `treasury-prices/` is the **leaf** — the only thing copied to `~/.claude/skills/treasury-prices/` — and holds `SKILL.md`, `requirements.txt`, and `scripts/`. The dev harness (`pytest.ini`, `requirements-dev.txt`, `tests/`) sits here at the family level so it never ships with the installed skill. Adding a test dependency or a fixture goes above the leaf; adding anything the skill needs at runtime goes inside it.

```bash
pip install -r requirements-dev.txt

# Run from this folder — pytest.ini's pythonpath is relative to it
pytest -m "not integration"    # unit tests (integration deselected)
pytest -m integration          # real network to TreasuryDirect / FedInvest
pytest                         # all
pytest tests/test_tips_unit.py::test_name

# The CLI, from this folder
python treasury-prices/scripts/treasury.py get-price --cusip 91282CGW5 --date 2026-05-05
python treasury-prices/scripts/treasury.py list-prices --date 2026-05-05 --type TIPS --text
python treasury-prices/scripts/treasury.py tips-value --cusip 91282CGW5 --date 2026-05-05 --price-type sell
```

`pytest.ini` sets `asyncio_mode = auto` — async tests need no `@pytest.mark.asyncio` — and `pythonpath = treasury-prices/scripts .`, which puts the leaf's modules on the path as top-level imports (`import fetcher`) while keeping `tests` importable as a package. Tests import the implementation directly, so a module moved within `scripts/` breaks them.

## treasury-prices

`scripts/treasury.py` is an argparse CLI with three subcommands (`get-price`, `list-prices`, `tips-value`), all routed through the `_load_rows` / `_load_row` helpers — keep that single source of truth when adding subcommands. Every subcommand returns a plain dict or list; `main` serializes it as JSON unless `--text` is given, in which case `_render_text` prints an aligned table.

`SKILL.md` is the model-facing contract. Any change to a subcommand's name, flags, output shape, or error behavior must be mirrored there, and the change bumps the `version:` and its `manifest.json` entry like any other skill in this repo.

Two independent upstream data sources:

1. **FedInvest historical prices** (`scripts/fetcher.py`) — POSTs date params to a CSV endpoint at `treasurydirect.gov/GA-FI/FedInvest/securityPriceDetail`. The CSV is **headerless and positional**; column order is hardcoded in `_COLUMNS`. Cached per-date in `cache.PriceCache` (in-memory, async-locked, two indexes: rows-by-date and cusip-lookup-by-date). Weekends and holidays return empty CSV → empty list, not an error.

   That endpoint is behind **Spring Security CSRF**. A POST carrying neither a session cookie nor a `_csrf` field is rejected with a bare 403. `_get_session` seeds both from the date-picker page (`SELECT_URL`) on first use and caches them for the life of the process; `fetch_prices` re-seeds once on a 403 before giving up. Do not drop the seeding GET — the POST works in a browser only because the browser already made it.

   Upstream field quirks: TIPS rows carry `security_type == "TIPS"`, not `"MARKET BASED TIPS"` like every other type, and their `rate` is a fraction (`0.0125`) where other types use a plain number. Nothing reads `rate` — the coupon rate for valuation comes from TA_WS metadata — but `_filter_by_type` matches against these strings.

2. **TreasuryDirect TA_WS** (`scripts/tips.py`) — two endpoints: `/securities/search` for security metadata (immutable post-issuance, cached by CUSIP) and `/secindex/search` for the daily CPI index ratio table (fetched once per CUSIP as a full table of up to 1000 rows, then keyed by date string). Both caches are module-level dicts with asyncio locks.

All caching is **process-lifetime only** — one CLI invocation fetches a given date or CUSIP at most once, and nothing survives process exit. Do not add disk persistence without asking.

TIPS valuation (`compute_tips_value`) combines both sources: clean price from FedInvest × `dailyIndex` from TA_WS, plus accrued-interest math from coupon dates. Coupon dates are derived from maturity month ± 6 months on the 15th — see `_coupon_dates`. All money math uses `Decimal` with `ROUND_HALF_UP`; only the final return dict converts to `float` for JSON.

### Price-type semantics (important caveat)

FedInvest publishes three clean prices per security: `buy`, `sell`, `end_of_day`. **`end_of_day` is zero/missing for the current trading day** because it is not published until after the close. `tips-value` exits 1 with a "zero or missing" message in that case, and `SKILL.md` tells the model to retry with `--price-type sell`. Preserve this behavior — the error message is a contract with the model.

## Conventions

- Dates in the CLI surface are strings `YYYY-MM-DD`; internally always `datetime.date`. `_parse_date` is the only conversion point.
- CUSIPs are normalized via `.strip().upper()` at the cache-lookup boundary, not in the cache itself.
- All upstream HTTP uses `httpx.AsyncClient` with `timeout=30.0, follow_redirects=True`.
- `Decimal(str(x))` when constructing from floats — never `Decimal(float)`.
- Errors are raised as exceptions inside command functions; `main` is the only place that catches, prints to stderr, and sets the exit code.
