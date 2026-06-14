from unittest.mock import patch

from bude_api.api import warehouses as warehouses_api


@patch("bude_api.api.warehouses.frappe")
def test_list_returns_warehouse_names(mock_frappe):
    mock_frappe.get_list.return_value = [
        {"name": "Stores - X"},
        {"name": "Finished Goods - X"},
    ]
    result = warehouses_api.list()
    assert result["ok"] is True
    assert result["data"] == ["Stores - X", "Finished Goods - X"]


@patch("bude_api.api.warehouses.frappe")
def test_list_returns_empty_when_no_warehouses(mock_frappe):
    mock_frappe.get_list.return_value = []
    result = warehouses_api.list()
    assert result["ok"] is True
    assert result["data"] == []


@patch("bude_api.api.warehouses.frappe")
def test_list_passes_disabled_filter(mock_frappe):
    mock_frappe.get_list.return_value = []
    warehouses_api.list()
    _, kwargs = mock_frappe.get_list.call_args
    assert kwargs["filters"] == {"disabled": 0}


@patch("bude_api.api.warehouses.frappe")
def test_list_respects_limit(mock_frappe):
    mock_frappe.get_list.return_value = []
    warehouses_api.list(limit=25)
    _, kwargs = mock_frappe.get_list.call_args
    assert kwargs["limit_page_length"] == 25
