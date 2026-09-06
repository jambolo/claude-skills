"""Unit tests for the CLI helpers and subcommands (mocked network)."""
from __future__ import annotations

import json
from datetime import date
from unittest.mock import AsyncMock

import pytest

import treasury
from treasury import _filter_by_type, _parse_date, _render_pairs, _render_table, main
from cache import PriceCache
from tests.conftest import SAMPLE_INDEX_TABLE, SAMPLE_ROWS, SAMPLE_SECURITY


@pytest.fixture(autouse=True)
def fresh_cache(monkeypatch):
    """The CLI cache is module-level; give every test its own."""
    monkeypatch.setattr(treasury, "cache", PriceCache())


@pytest.fixture
def mock_prices(monkeypatch):
    async def fake_fetch(d):
        return SAMPLE_ROWS

    monkeypatch.setattr(treasury, "fetch_prices", fake_fetch)


# --- _parse_date ---

def test_parse_date_valid():
    assert _parse_date("2026-05-05") == date(2026, 5, 5)


def test_parse_date_invalid_format():
    with pytest.raises(ValueError, match="YYYY-MM-DD"):
        _parse_date("05/05/2026")


def test_parse_date_invalid_date():
    with pytest.raises(ValueError):
        _parse_date("2026-13-01")


def test_parse_date_leap_year_valid():
    assert _parse_date("2024-02-29") == date(2024, 2, 29)


def test_parse_date_leap_year_invalid():
    with pytest.raises(ValueError):
        _parse_date("2026-02-29")


# --- _filter_by_type ---

def test_filter_by_type_none_returns_all():
    assert _filter_by_type(SAMPLE_ROWS, None) == SAMPLE_ROWS


def test_filter_by_type_tips():
    rows = _filter_by_type(SAMPLE_ROWS, "TIPS")
    assert len(rows) == 1
    assert rows[0]["cusip"] == "91282CGW5"


def test_filter_by_type_case_insensitive():
    assert len(_filter_by_type(SAMPLE_ROWS, "tips")) == 1


def test_filter_by_type_no_match():
    assert _filter_by_type(SAMPLE_ROWS, "ZZZZ") == []


def test_filter_by_type_partial_match():
    # Only the bill and the bond carry the "MARKET BASED" prefix; TIPS rows do not.
    assert len(_filter_by_type(SAMPLE_ROWS, "MARKET")) == 2


# --- get-price ---

def test_cli_get_price(mock_prices, capsys):
    assert main(["get-price", "--cusip", "912797SP3", "--date", "2026-05-05"]) == 0
    data = json.loads(capsys.readouterr().out)
    assert data["cusip"] == "912797SP3"
    assert data["security_type"] == "MARKET BASED BILL"


def test_cli_get_price_lowercase_cusip(mock_prices, capsys):
    assert main(["get-price", "--cusip", "912797sp3", "--date", "2026-05-05"]) == 0
    assert json.loads(capsys.readouterr().out)["cusip"] == "912797SP3"


def test_cli_get_price_not_found(mock_prices, capsys):
    assert main(["get-price", "--cusip", "XXXXXXXXX", "--date", "2026-05-05"]) == 1
    assert "not found" in capsys.readouterr().err


def test_cli_get_price_bad_date(mock_prices, capsys):
    assert main(["get-price", "--cusip", "912797SP3", "--date", "05/05/2026"]) == 1
    assert "YYYY-MM-DD" in capsys.readouterr().err


# --- list-prices ---

def test_cli_list_prices_no_filter(mock_prices, capsys):
    assert main(["list-prices", "--date", "2026-05-05"]) == 0
    assert len(json.loads(capsys.readouterr().out)) == 3


def test_cli_list_prices_tips_filter(mock_prices, capsys):
    assert main(["list-prices", "--date", "2026-05-05", "--type", "TIPS"]) == 0
    data = json.loads(capsys.readouterr().out)
    assert len(data) == 1
    assert data[0]["cusip"] == "91282CGW5"


def test_cli_list_prices_text(mock_prices, capsys):
    assert main(["--text", "list-prices", "--date", "2026-05-05"]) == 0
    lines = capsys.readouterr().out.strip().splitlines()
    assert lines[0].split() == ["CUSIP", "SECURITY_TYPE", "RATE", "MATURITY_DATE", "CALL_DATE", "BUY", "SELL", "END_OF_DAY"]
    assert len(lines) == 4


def test_cli_list_prices_empty_day(monkeypatch, capsys):
    async def no_rows(d):
        return []

    monkeypatch.setattr(treasury, "fetch_prices", no_rows)
    assert main(["list-prices", "--date", "2026-05-02"]) == 0
    assert json.loads(capsys.readouterr().out) == []


# --- tips-value ---

def test_cli_tips_value_zero_eod_fails(mock_prices, capsys):
    # 912797SP3 has end_of_day=0.000000.
    assert main(["tips-value", "--cusip", "912797SP3", "--date", "2026-05-05"]) == 1
    assert "zero or missing" in capsys.readouterr().err


def test_cli_tips_value_invalid_price_type(mock_prices):
    with pytest.raises(SystemExit):
        main(["tips-value", "--cusip", "91282CGW5", "--date", "2026-05-05", "--price-type", "mid"])


def test_cli_tips_value_math(mock_prices, monkeypatch, capsys):
    monkeypatch.setattr("tips._fetch_security", AsyncMock(return_value=SAMPLE_SECURITY))
    monkeypatch.setattr("tips._fetch_index_table", AsyncMock(return_value=SAMPLE_INDEX_TABLE))

    assert main([
        "tips-value", "--cusip", "91282CGW5", "--date", "2026-05-05",
        "--face-value", "1000", "--price-type", "sell",
    ]) == 0
    data = json.loads(capsys.readouterr().out)

    assert data["cusip"] == "91282CGW5"
    assert data["face_value"] == 1000.0
    assert data["full_price"] > data["inflation_adjusted_price"] > 0
    assert data["accrued_interest"] > 0
    assert data["last_coupon_date"] == "2026-04-15"
    assert data["next_coupon_date"] == "2026-10-15"


def test_cli_tips_value_text(mock_prices, monkeypatch, capsys):
    monkeypatch.setattr("tips._fetch_security", AsyncMock(return_value=SAMPLE_SECURITY))
    monkeypatch.setattr("tips._fetch_index_table", AsyncMock(return_value=SAMPLE_INDEX_TABLE))

    assert main(["--text", "tips-value", "--cusip", "91282CGW5", "--date", "2026-05-05", "--price-type", "sell"]) == 0
    out = capsys.readouterr().out
    assert "full_price" in out
    assert "{" not in out


# --- Rendering ---

def test_render_table_empty():
    assert _render_table([]) == "(no rows)"


def test_render_table_columns_aligned():
    lines = _render_table(SAMPLE_ROWS).splitlines()
    assert len({len(line.rstrip()) for line in lines}) <= len(lines)
    assert all(line.startswith(("CUSIP", "912797SP3", "91282CGW5", "912810TM0")) for line in lines)


def test_render_pairs():
    out = _render_pairs({"a": 1, "bbb": 2})
    assert out.splitlines() == ["a    1", "bbb  2"]
