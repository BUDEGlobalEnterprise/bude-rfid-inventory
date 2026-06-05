from unittest.mock import MagicMock, patch

from bude_api.api import stock as stock_api


def test_create_transfer_requires_source_warehouse():
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="",
        target_warehouse="Stores - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_transfer_requires_target_warehouse():
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="Stores - X",
        target_warehouse="",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_transfer_requires_items():
    result = stock_api.create_transfer(
        items=[],
        source_warehouse="A",
        target_warehouse="B",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_transfer_rejects_non_positive_qty():
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 0}],
        source_warehouse="A",
        target_warehouse="B",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_BAD_QTY"


def test_create_transfer_rejects_non_numeric_qty():
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": "five"}],
        source_warehouse="A",
        target_warehouse="B",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_BAD_QTY"


def test_create_transfer_rejects_same_source_and_target():
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="Same",
        target_warehouse="Same",
    )
    # Note: same-warehouse check happens after frappe is required, so this
    # test only reaches it when frappe is mocked. Without frappe, we get
    # ENV_NO_FRAPPE first. Skip this specific message check in unit mode.
    assert result["ok"] is False


@patch("bude_api.api.stock.frappe")
def test_create_transfer_rejects_unknown_source_warehouse(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            filters = kwargs.get("filters", [])
            name = filters[0][2] if filters else None
            return [{"name": name}] if name == "Target - X" else []
        return []

    mock_frappe.get_list.side_effect = get_list
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="Bad - X",
        target_warehouse="Target - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_WAREHOUSE"


@patch("bude_api.api.stock.frappe")
def test_create_transfer_rejects_same_source_target_after_frappe(mock_frappe):
    mock_frappe.get_list.return_value = [{"name": "Same - X"}]
    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="Same - X",
        target_warehouse="Same - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_SAME_WAREHOUSE"


@patch("bude_api.api.stock.frappe")
def test_create_transfer_rejects_unknown_items(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]  # 'B' is missing
        return []

    mock_frappe.get_list.side_effect = get_list
    result = stock_api.create_transfer(
        items=[
            {"item_code": "A", "qty": 1},
            {"item_code": "B", "qty": 2},
        ],
        source_warehouse="Src - X",
        target_warehouse="Tgt - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_ITEM"
    assert "B" in result["message"]


@patch("bude_api.api.stock.frappe")
def test_create_transfer_submits_stock_entry_on_happy_path(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "X"}]
        if doctype == "Item":
            return [{"item_code": "A"}, {"item_code": "B"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    doc = MagicMock()
    doc.name = "STE-2026-00001"
    doc.docstatus = 1
    mock_frappe.get_doc.return_value = doc

    result = stock_api.create_transfer(
        items=[
            {"item_code": "A", "qty": 2.5},
            {"item_code": "B", "qty": 1},
        ],
        source_warehouse="Src - X",
        target_warehouse="Tgt - X",
        posting_date="2026-06-03",
    )

    assert result["ok"] is True
    assert result["data"]["name"] == "STE-2026-00001"
    assert result["data"]["docstatus"] == 1

    # Verify the Stock Entry doc was assembled correctly.
    args, kwargs = mock_frappe.get_doc.call_args
    payload = args[0]
    assert payload["doctype"] == "Stock Entry"
    assert payload["stock_entry_type"] == "Material Transfer"
    assert payload["posting_date"] == "2026-06-03"
    assert len(payload["items"]) == 2
    assert payload["items"][0] == {
        "item_code": "A",
        "qty": 2.5,
        "s_warehouse": "Src - X",
        "t_warehouse": "Tgt - X",
    }
    doc.insert.assert_called_once()
    doc.submit.assert_called_once()
