from unittest.mock import MagicMock, patch

from bude_api.api import stock as stock_api


class _FakeValidationError(Exception):
    """Stand-in for frappe.ValidationError in unit tests (no Frappe installed)."""


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
    mock_frappe.get_all.side_effect = get_list
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
    mock_frappe.get_all.side_effect = get_list
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


@patch("bude_api.api.stock.frappe")
def test_create_transfer_converts_erpnext_validation_error(mock_frappe):
    # ERPNext rejects the submit (e.g. insufficient stock). Frappe would raise
    # ValidationError → raw HTTP 417; we convert it to a clean envelope and
    # roll back the half-created draft.
    mock_frappe.ValidationError = _FakeValidationError

    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    doc = MagicMock()
    doc.submit.side_effect = _FakeValidationError(
        "Insufficient stock for Item A in Finished Goods - BUDE",
    )
    mock_frappe.get_doc.return_value = doc

    result = stock_api.create_transfer(
        items=[{"item_code": "A", "qty": 1}],
        source_warehouse="Finished Goods - BUDE",
        target_warehouse="Stores - BUDE",
    )

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_ERPNEXT"
    assert "Insufficient stock" in result["message"]
    doc.insert.assert_called_once()
    mock_frappe.db.rollback.assert_called_once()


# ---------------------------------------------------------------------------
# create_receipt
# ---------------------------------------------------------------------------


def test_create_receipt_requires_target_warehouse():
    result = stock_api.create_receipt(
        items=[{"item_code": "A", "qty": 1}],
        target_warehouse="",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_receipt_requires_items():
    result = stock_api.create_receipt(items=[], target_warehouse="Stores - X")
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_receipt_rejects_bad_qty():
    result = stock_api.create_receipt(
        items=[{"item_code": "A", "qty": -1}],
        target_warehouse="Stores - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_BAD_QTY"


@patch("bude_api.api.stock.frappe")
def test_create_receipt_rejects_unknown_warehouse(mock_frappe):
    mock_frappe.get_list.return_value = []  # no warehouse, no items
    result = stock_api.create_receipt(
        items=[{"item_code": "A", "qty": 1}],
        target_warehouse="Nope - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_WAREHOUSE"


@patch("bude_api.api.stock.frappe")
def test_create_receipt_material_receipt_happy_path(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Tgt - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}, {"item_code": "B"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    doc = MagicMock()
    doc.name = "STE-MR-2026-00001"
    doc.docstatus = 1
    mock_frappe.get_doc.return_value = doc

    result = stock_api.create_receipt(
        items=[
            {"item_code": "A", "qty": 5},
            {"item_code": "B", "qty": 2.5},
        ],
        target_warehouse="Tgt - X",
        posting_date="2026-06-10",
    )

    assert result["ok"] is True
    assert result["data"]["name"] == "STE-MR-2026-00001"

    payload = mock_frappe.get_doc.call_args[0][0]
    assert payload["doctype"] == "Stock Entry"
    assert payload["stock_entry_type"] == "Material Receipt"
    assert payload["posting_date"] == "2026-06-10"
    assert payload["items"][0] == {
        "item_code": "A",
        "qty": 5,
        "t_warehouse": "Tgt - X",
    }
    doc.submit.assert_called_once()


@patch("bude_api.api.stock.frappe")
def test_create_receipt_against_po_rejects_unknown_po(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Tgt - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    mock_frappe.db.get_value.return_value = None

    result = stock_api.create_receipt(
        items=[{"item_code": "A", "qty": 1}],
        target_warehouse="Tgt - X",
        against_po="PO-MISSING",
    )

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_PO"


@patch("bude_api.api.stock.frappe")
def test_create_receipt_against_po_rejects_line_mismatch(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Tgt - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}, {"item_code": "B"}]
        if doctype == "Purchase Order Item":
            return [{"name": "PO-001-1", "item_code": "A", "qty": 10}]
        return []

    mock_frappe.get_list.side_effect = get_list
    mock_frappe.get_all.side_effect = get_list
    mock_frappe.db.get_value.return_value = {
        "name": "PO-001",
        "supplier": "Acme Supplies",
    }

    result = stock_api.create_receipt(
        items=[
            {"item_code": "A", "qty": 5},
            {"item_code": "B", "qty": 1},  # not on PO
        ],
        target_warehouse="Tgt - X",
        against_po="PO-001",
    )

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_PO_LINE_MISMATCH"
    assert "B" in result["message"]


@patch("bude_api.api.stock.frappe")
def test_create_receipt_against_po_happy_path(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Tgt - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]
        if doctype == "Purchase Order Item":
            return [{"name": "PO-001-1", "item_code": "A", "qty": 10}]
        return []

    mock_frappe.get_list.side_effect = get_list
    mock_frappe.get_all.side_effect = get_list
    mock_frappe.db.get_value.return_value = {
        "name": "PO-001",
        "supplier": "Acme Supplies",
    }
    pr = MagicMock()
    pr.name = "PREC-2026-00001"
    pr.docstatus = 1
    mock_frappe.get_doc.return_value = pr

    result = stock_api.create_receipt(
        items=[{"item_code": "A", "qty": 5}],
        target_warehouse="Tgt - X",
        against_po="PO-001",
    )

    assert result["ok"] is True
    assert result["data"]["name"] == "PREC-2026-00001"

    payload = mock_frappe.get_doc.call_args[0][0]
    assert payload["doctype"] == "Purchase Receipt"
    assert payload["supplier"] == "Acme Supplies"
    assert payload["items"][0] == {
        "item_code": "A",
        "qty": 5,
        "warehouse": "Tgt - X",
        "purchase_order": "PO-001",
        "purchase_order_item": "PO-001-1",
    }
    pr.submit.assert_called_once()


# ---------------------------------------------------------------------------
# create_reconciliation
# ---------------------------------------------------------------------------


def test_create_reconciliation_requires_warehouse():
    result = stock_api.create_reconciliation(
        counts=[{"item_code": "A", "qty": 5}],
        warehouse="",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_reconciliation_requires_counts():
    result = stock_api.create_reconciliation(
        counts=[],
        warehouse="Stores - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_REQUIRED"


def test_create_reconciliation_rejects_negative_qty():
    # 0 is allowed (item present in system but counted as missing).
    # Negative is not.
    result = stock_api.create_reconciliation(
        counts=[{"item_code": "A", "qty": -1}],
        warehouse="Stores - X",
    )
    assert result["ok"] is False
    assert result["code"] == "VALIDATION_BAD_QTY"


@patch("bude_api.api.stock.frappe")
def test_create_reconciliation_allows_zero_qty(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Stores - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    doc = MagicMock()
    doc.name = "RECON-2026-00001"
    doc.docstatus = 1
    mock_frappe.get_doc.return_value = doc

    # Counted zero on hand — legitimate after a full count showing nothing.
    result = stock_api.create_reconciliation(
        counts=[{"item_code": "A", "qty": 0}],
        warehouse="Stores - X",
    )

    assert result["ok"] is True
    assert result["data"]["name"] == "RECON-2026-00001"


@patch("bude_api.api.stock.frappe")
def test_create_reconciliation_rejects_unknown_item(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Stores - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}]  # B missing
        return []

    mock_frappe.get_list.side_effect = get_list

    result = stock_api.create_reconciliation(
        counts=[
            {"item_code": "A", "qty": 10},
            {"item_code": "B", "qty": 5},
        ],
        warehouse="Stores - X",
    )

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_UNKNOWN_ITEM"


@patch("bude_api.api.stock.frappe")
def test_create_reconciliation_happy_path_assembles_doc(mock_frappe):
    def get_list(doctype, **kwargs):
        if doctype == "Warehouse":
            return [{"name": "Stores - X"}]
        if doctype == "Item":
            return [{"item_code": "A"}, {"item_code": "B"}]
        return []

    mock_frappe.get_list.side_effect = get_list
    doc = MagicMock()
    doc.name = "RECON-2026-00002"
    doc.docstatus = 1
    mock_frappe.get_doc.return_value = doc

    result = stock_api.create_reconciliation(
        counts=[
            {"item_code": "A", "qty": 12},
            {"item_code": "B", "qty": 0},
        ],
        warehouse="Stores - X",
        posting_date="2026-06-10",
    )

    assert result["ok"] is True
    payload = mock_frappe.get_doc.call_args[0][0]
    assert payload["doctype"] == "Stock Reconciliation"
    assert payload["purpose"] == "Stock Reconciliation"
    assert payload["posting_date"] == "2026-06-10"
    assert payload["items"] == [
        {"item_code": "A", "warehouse": "Stores - X", "qty": 12},
        {"item_code": "B", "warehouse": "Stores - X", "qty": 0},
    ]
    doc.submit.assert_called_once()
