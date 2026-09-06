"""Unit tests for fetcher CSV parsing and the CSRF handshake, using mocked HTTP."""
from __future__ import annotations

from datetime import date

import pytest
import respx
from httpx import Response

import fetcher
from fetcher import SELECT_URL, URL, fetch_prices

SAMPLE_CSV = """\
912797SP3,MARKET BASED BILL,0.0,05/07/2026,,0.000000,99.980278,0.000000
91282CGW5,TIPS,0.0125,04/15/2028,,97.500000,97.480000,97.490000
912810TM0,MARKET BASED BOND,4.375,05/15/2041,,100.125000,100.100000,100.110000
"""

TOKEN = "test-csrf-token"
SELECT_PAGE = f'<form><input type="hidden" name="_csrf" value="{TOKEN}" /></form>'


@pytest.fixture(autouse=True)
def clean_session():
    """The seeded CSRF session is module-level; do not leak it between tests."""
    fetcher._reset_session()
    yield
    fetcher._reset_session()


def _mock_select():
    respx.get(SELECT_URL).mock(
        return_value=Response(200, text=SELECT_PAGE, headers={"set-cookie": "JSESSIONID=abc123; Path=/"})
    )


# --- CSV parsing ---

@respx.mock
async def test_fetch_prices_parses_csv():
    _mock_select()
    respx.post(URL).mock(return_value=Response(200, text=SAMPLE_CSV))
    rows = await fetch_prices(date(2026, 5, 5))
    assert len(rows) == 3
    assert rows[0]["cusip"] == "912797SP3"
    assert rows[0]["security_type"] == "MARKET BASED BILL"
    assert rows[0]["sell"] == "99.980278"


@respx.mock
async def test_fetch_prices_all_fields_present():
    _mock_select()
    respx.post(URL).mock(return_value=Response(200, text=SAMPLE_CSV))
    rows = await fetch_prices(date(2026, 5, 5))
    assert set(rows[1].keys()) == {"cusip", "security_type", "rate", "maturity_date", "call_date", "buy", "sell", "end_of_day"}


@respx.mock
async def test_fetch_prices_empty_response():
    _mock_select()
    respx.post(URL).mock(return_value=Response(200, text=""))
    assert await fetch_prices(date(2026, 5, 5)) == []


@respx.mock
async def test_fetch_prices_skips_blank_lines():
    _mock_select()
    respx.post(URL).mock(return_value=Response(200, text=SAMPLE_CSV + "\n\n\n"))
    assert len(await fetch_prices(date(2026, 5, 5))) == 3


@respx.mock
async def test_fetch_prices_strips_whitespace():
    _mock_select()
    csv_padded = " 912797SP3 , MARKET BASED BILL ,0.0,05/07/2026,,0.000000,99.980278,0.000000\n"
    respx.post(URL).mock(return_value=Response(200, text=csv_padded))
    rows = await fetch_prices(date(2026, 5, 5))
    assert rows[0]["cusip"] == "912797SP3"
    assert rows[0]["security_type"] == "MARKET BASED BILL"


@respx.mock
async def test_fetch_prices_posts_correct_date():
    _mock_select()
    captured = {}

    def capture(request):
        captured["body"] = request.content.decode()
        return Response(200, text=SAMPLE_CSV)

    respx.post(URL).mock(side_effect=capture)
    await fetch_prices(date(2026, 3, 7))
    assert "priceDateDay=7" in captured["body"]
    assert "priceDateMonth=3" in captured["body"]
    assert "priceDateYear=2026" in captured["body"]


# --- CSRF handshake ---

@respx.mock
async def test_fetch_prices_sends_csrf_token_and_cookie():
    _mock_select()
    captured = {}

    def capture(request):
        captured["body"] = request.content.decode()
        captured["cookie"] = request.headers.get("cookie", "")
        return Response(200, text=SAMPLE_CSV)

    respx.post(URL).mock(side_effect=capture)
    await fetch_prices(date(2026, 5, 5))
    assert f"_csrf={TOKEN}" in captured["body"]
    assert "JSESSIONID=abc123" in captured["cookie"]


@respx.mock
async def test_fetch_prices_seeds_session_once():
    select = respx.get(SELECT_URL).mock(
        return_value=Response(200, text=SELECT_PAGE, headers={"set-cookie": "JSESSIONID=abc123; Path=/"})
    )
    respx.post(URL).mock(return_value=Response(200, text=SAMPLE_CSV))
    await fetch_prices(date(2026, 5, 5))
    await fetch_prices(date(2026, 5, 6))
    assert select.call_count == 1


@respx.mock
async def test_fetch_prices_reseeds_once_on_403():
    select = respx.get(SELECT_URL).mock(
        return_value=Response(200, text=SELECT_PAGE, headers={"set-cookie": "JSESSIONID=abc123; Path=/"})
    )
    responses = [Response(403, json={"status": 403}), Response(200, text=SAMPLE_CSV)]
    respx.post(URL).mock(side_effect=lambda request: responses.pop(0))

    rows = await fetch_prices(date(2026, 5, 5))
    assert len(rows) == 3
    assert select.call_count == 2


@respx.mock
async def test_fetch_prices_raises_on_persistent_403():
    _mock_select()
    respx.post(URL).mock(return_value=Response(403, json={"status": 403}))
    with pytest.raises(Exception, match="403"):
        await fetch_prices(date(2026, 5, 5))


@respx.mock
async def test_fetch_prices_raises_when_no_csrf_token():
    respx.get(SELECT_URL).mock(return_value=Response(200, text="<html>no token here</html>"))
    with pytest.raises(RuntimeError, match="No CSRF token"):
        await fetch_prices(date(2026, 5, 5))
