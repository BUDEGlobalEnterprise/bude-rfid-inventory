from unittest.mock import MagicMock, patch

from bude_api.api import analytics as analytics_api


# ── get_stock_aging ────────────────────────────────────────────────────────────

@patch("bude_api.api.analytics.frappe")
def test_aging_returns_rows(mock_frappe):
    mock_frappe.db.exists.return_value = True
    mock_frappe.db.sql.return_value = [
        {
            "item_code": "BOLT-M8",
            "item_name": "Bolt M8",
            "actual_qty": 100.0,
            "last_movement_date": "2026-01-01",
            "days_idle": 165,
        },
        {
            "item_code": "NUT-M8",
            "item_name": None,
            "actual_qty": 50.0,
            "last_movement_date": None,
            "days_idle": None,
        },
    ]
    result = analytics_api.get_stock_aging("Stores - X")
    assert result["ok"] is True
    assert len(result["data"]) == 2
    assert result["data"][0]["item_code"] == "BOLT-M8"
    assert result["data"][0]["days_idle"] == 165


def test_aging_requires_warehouse():
    result = analytics_api.get_stock_aging("   ")
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


@patch("bude_api.api.analytics.frappe")
def test_aging_unknown_warehouse_returns_error(mock_frappe):
    mock_frappe.db.exists.return_value = False
    result = analytics_api.get_stock_aging("No-Such-WH")
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_WAREHOUSE"


@patch("bude_api.api.analytics.frappe")
def test_aging_respects_threshold_and_limit(mock_frappe):
    mock_frappe.db.exists.return_value = True
    mock_frappe.db.sql.return_value = []
    analytics_api.get_stock_aging("Stores - X", threshold_days=9999, limit=9999)
    _, kwargs = mock_frappe.db.sql.call_args
    values = kwargs["values"]
    assert values["threshold_days"] == 365
    assert values["limit"] == 500


@patch("bude_api.api.analytics.frappe")
def test_aging_date_converted_to_string(mock_frappe):
    from datetime import date
    mock_frappe.db.exists.return_value = True
    mock_frappe.db.sql.return_value = [
        {
            "item_code": "ITEM-1",
            "item_name": "Item 1",
            "actual_qty": 10.0,
            "last_movement_date": date(2026, 1, 15),
            "days_idle": 151,
        }
    ]
    result = analytics_api.get_stock_aging("Stores - X")
    assert result["ok"] is True
    assert result["data"][0]["last_movement_date"] == "2026-01-15"


# ── get_reconciliation_history ─────────────────────────────────────────────────

@patch("bude_api.api.analytics.frappe")
def test_recon_history_returns_rows(mock_frappe):
    mock_frappe.get_list.return_value = [
        {"name": "SRECON-001", "posting_date": "2026-05-10", "set_warehouse": "Stores - X"},
    ]
    mock_frappe.get_all.return_value = [
        {"item_code": "BOLT-M8", "item_name": "Bolt M8", "qty": 50.0, "current_qty": 45.0, "warehouse": "Stores - X"},
    ]
    result = analytics_api.get_reconciliation_history()
    assert result["ok"] is True
    assert len(result["data"]) == 1
    row = result["data"][0]
    assert row["name"] == "SRECON-001"
    assert len(row["items"]) == 1
    assert row["items"][0]["variance"] == 5.0


@patch("bude_api.api.analytics.frappe")
def test_recon_history_filters_by_warehouse(mock_frappe):
    mock_frappe.get_list.return_value = []
    analytics_api.get_reconciliation_history(warehouse="Stores - X")
    _, kwargs = mock_frappe.get_list.call_args
    assert kwargs["filters"]["set_warehouse"] == "Stores - X"


@patch("bude_api.api.analytics.frappe")
def test_recon_history_no_warehouse_filter_when_absent(mock_frappe):
    mock_frappe.get_list.return_value = []
    analytics_api.get_reconciliation_history()
    _, kwargs = mock_frappe.get_list.call_args
    assert "set_warehouse" not in kwargs["filters"]


@patch("bude_api.api.analytics.frappe")
def test_recon_history_respects_limit(mock_frappe):
    mock_frappe.get_list.return_value = []
    analytics_api.get_reconciliation_history(limit=9999)
    _, kwargs = mock_frappe.get_list.call_args
    assert kwargs["limit_page_length"] == 200
