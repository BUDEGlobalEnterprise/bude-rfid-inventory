from unittest.mock import patch

from bude_api.api import items as items_api


@patch("bude_api.api.items.frappe")
def test_search_empty_query_returns_empty_list(mock_frappe):
    result = items_api.search("   ")
    assert result["ok"] is True
    assert result["data"] == []
    mock_frappe.get_list.assert_not_called()


@patch("bude_api.api.items.frappe")
def test_search_returns_name_and_barcode_matches_deduped(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Item Barcode":
            return [{"parent": "ITEM-A"}]
        if doctype == "Item":
            filters = kwargs.get("filters", [])
            if any(f[0] == "item_code" and f[1] == "in" for f in filters):
                return [
                    {
                        "name": "ITEM-A",
                        "item_code": "ITEM-A",
                        "item_name": "Widget A",
                        "description": "",
                        "stock_uom": "Nos",
                        "image": None,
                        "disabled": 0,
                    }
                ]
            return [
                {
                    "name": "ITEM-A",
                    "item_code": "ITEM-A",
                    "item_name": "Widget A",
                    "description": "",
                    "stock_uom": "Nos",
                    "image": None,
                    "disabled": 0,
                },
                {
                    "name": "ITEM-B",
                    "item_code": "ITEM-B",
                    "item_name": "Widget B",
                    "description": "",
                    "stock_uom": "Nos",
                    "image": None,
                    "disabled": 0,
                },
            ]
        return []

    mock_frappe.get_list.side_effect = get_list
    result = items_api.search("Widget")

    assert result["ok"] is True
    codes = [r["item_code"] for r in result["data"]]
    assert codes == ["ITEM-A", "ITEM-B"]


@patch("bude_api.api.items.frappe")
def test_search_respects_limit_bounds(mock_frappe):
    mock_frappe.get_list.return_value = []
    mock_frappe.get_all.return_value = []
    items_api.search("x", limit=500)
    args, kwargs = mock_frappe.get_list.call_args_list[0]
    assert kwargs["limit"] == 100

    items_api.search("x", limit=0)
    args, kwargs = mock_frappe.get_list.call_args_list[1]
    assert kwargs["limit"] == 1


@patch("bude_api.api.items.frappe")
def test_get_by_barcode_returns_item(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Item Barcode":
            return [{"parent": "ITEM-1"}]
        if doctype == "Item":
            return [
                {
                    "name": "ITEM-1",
                    "item_code": "ITEM-1",
                    "item_name": "Thing",
                    "description": "",
                    "stock_uom": "Nos",
                    "image": None,
                    "disabled": 0,
                }
            ]
        return []

    mock_frappe.get_list.side_effect = get_list
    result = items_api.get_by_barcode("ABC123")
    assert result["ok"] is True
    assert result["data"]["item_code"] == "ITEM-1"


@patch("bude_api.api.items.frappe")
def test_get_by_barcode_returns_not_found_when_no_match(mock_frappe):
    mock_frappe.get_list.return_value = []
    result = items_api.get_by_barcode("UNKNOWN")
    assert result["ok"] is False
    assert result["code"] == "ITEM_NOT_FOUND"


def test_get_by_barcode_requires_value():
    result = items_api.get_by_barcode("   ")
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


@patch("bude_api.api.items.frappe")
def test_get_stock_returns_bin_rows(mock_frappe):
    mock_frappe.get_list.return_value = [
        {
            "warehouse": "Stores - X",
            "actual_qty": 10.0,
            "reserved_qty": 1.0,
            "ordered_qty": 0.0,
            "projected_qty": 9.0,
            "stock_uom": "Nos",
        }
    ]
    result = items_api.get_stock("ITEM-1")
    assert result["ok"] is True
    assert len(result["data"]) == 1
    assert result["data"][0]["warehouse"] == "Stores - X"


@patch("bude_api.api.items.frappe")
def test_get_stock_filters_by_warehouse_when_given(mock_frappe):
    mock_frappe.get_list.return_value = []
    items_api.get_stock("ITEM-1", warehouse="Stores - X")
    args, kwargs = mock_frappe.get_list.call_args
    filters = kwargs["filters"]
    assert ["item_code", "=", "ITEM-1"] in filters
    assert ["warehouse", "=", "Stores - X"] in filters


def test_get_stock_requires_item_code():
    result = items_api.get_stock("   ")
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"
