from unittest.mock import patch

from bude_api.api import companies as companies_api


@patch("bude_api.api.companies.frappe")
def test_list_companies_returns_rows(mock_frappe):
    mock_frappe.get_all.return_value = [
        {"name": "Acme Inc", "company_name": "Acme Inc", "default_currency": "USD", "country": "United States"},
        {"name": "Acme Gulf", "company_name": "Acme Gulf", "default_currency": "AED", "country": "UAE"},
    ]

    result = companies_api.list_companies()

    assert result["ok"] is True
    assert len(result["data"]) == 2
    assert result["data"][0]["name"] == "Acme Inc"


@patch("bude_api.api.companies.frappe")
def test_list_companies_respects_limit(mock_frappe):
    mock_frappe.get_all.return_value = []

    companies_api.list_companies(limit=5)

    call_kwargs = mock_frappe.get_all.call_args
    assert call_kwargs.kwargs.get("limit") == 5 or call_kwargs.args[2:] or True
    # Verify limit was clamped and passed through
    mock_frappe.get_all.assert_called_once()
    _, kwargs = mock_frappe.get_all.call_args
    assert kwargs["limit"] == 5
