"""Stock write endpoints.

    POST /api/method/bude_api.api.stock.create_transfer   (auth required)
    POST /api/method/bude_api.api.stock.create_receipt    (auth required)

Slice 4 (Stock Reconciliation) lands in a separate function in this same
module. All writes go through standard ERPNext DocTypes (Stock Entry,
Purchase Receipt, Warehouse, Item, Purchase Order) — no custom DocTypes.
"""

from typing import Optional

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["POST"])


@_whitelist()
def create_transfer(
    items: list,
    source_warehouse: str,
    target_warehouse: str,
    posting_date: Optional[str] = None,
) -> dict:
    """Create + submit a Stock Entry of type Material Transfer.

    `items` is a list of {item_code: str, qty: number}. Returns
    {name, docstatus} on success. Validation errors are 4xx (VALIDATION_*);
    server / DB errors propagate as 5xx via Frappe's default handling.
    """
    error = _validate_inputs(items, source_warehouse, target_warehouse)
    if error is not None:
        return error

    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    if not _warehouse_exists(source_warehouse):
        return failure(
            f"Source warehouse '{source_warehouse}' does not exist.",
            code="VALIDATION_UNKNOWN_WAREHOUSE",
        )
    if not _warehouse_exists(target_warehouse):
        return failure(
            f"Target warehouse '{target_warehouse}' does not exist.",
            code="VALIDATION_UNKNOWN_WAREHOUSE",
        )
    if source_warehouse == target_warehouse:
        return failure(
            "Source and target warehouses must differ.",
            code="VALIDATION_SAME_WAREHOUSE",
        )

    missing = _missing_items([row["item_code"] for row in items])
    if missing:
        return failure(
            f"Unknown item(s): {', '.join(missing)}",
            code="VALIDATION_UNKNOWN_ITEM",
        )

    doc = frappe.get_doc({
        "doctype": "Stock Entry",
        "stock_entry_type": "Material Transfer",
        "purpose": "Material Transfer",
        "posting_date": posting_date,
        "items": [
            {
                "item_code": row["item_code"],
                "qty": row["qty"],
                "s_warehouse": source_warehouse,
                "t_warehouse": target_warehouse,
            }
            for row in items
        ],
    })
    doc.insert(ignore_permissions=False)
    doc.submit()

    return success({"name": doc.name, "docstatus": doc.docstatus})


def _validate_inputs(
    items, source_warehouse, target_warehouse,
) -> Optional[dict]:
    if not source_warehouse or not source_warehouse.strip():
        return failure("source_warehouse is required.", code="VALIDATION_REQUIRED")
    if not target_warehouse or not target_warehouse.strip():
        return failure("target_warehouse is required.", code="VALIDATION_REQUIRED")
    if not items:
        return failure("At least one item is required.", code="VALIDATION_REQUIRED")
    for row in items:
        if not isinstance(row, dict):
            return failure("Each item must be an object.", code="VALIDATION_BAD_SHAPE")
        if "item_code" not in row or not row["item_code"]:
            return failure("Each item needs an item_code.", code="VALIDATION_REQUIRED")
        if "qty" not in row:
            return failure("Each item needs a qty.", code="VALIDATION_REQUIRED")
        try:
            qty = float(row["qty"])
        except (TypeError, ValueError):
            return failure(
                f"Invalid qty for {row.get('item_code')}.",
                code="VALIDATION_BAD_QTY",
            )
        if qty <= 0:
            return failure(
                f"qty must be greater than zero for {row['item_code']}.",
                code="VALIDATION_BAD_QTY",
            )
    return None


def _warehouse_exists(name: str) -> bool:
    rows = frappe.get_list(
        "Warehouse",
        filters=[["name", "=", name]],
        fields=["name"],
        limit=1,
    )
    return bool(rows)


def _missing_items(codes: list) -> list:
    if not codes:
        return []
    found = frappe.get_list(
        "Item",
        filters=[["item_code", "in", codes]],
        fields=["item_code"],
        limit=len(codes),
    )
    found_set = {row["item_code"] for row in found}
    return [code for code in codes if code not in found_set]


# ---------------------------------------------------------------------------
# create_receipt — Material Receipt (Stock Entry) or Purchase Receipt against PO
# ---------------------------------------------------------------------------


@_whitelist()
def create_receipt(
    items: list,
    target_warehouse: str,
    supplier: Optional[str] = None,
    against_po: Optional[str] = None,
    posting_date: Optional[str] = None,
) -> dict:
    """Receive stock into [target_warehouse].

    If [against_po] is provided: creates a Purchase Receipt linked to the PO.
    Each item must match a line on that PO (by item_code) — extras are
    rejected with VALIDATION_PO_LINE_MISMATCH.

    Otherwise: creates a Stock Entry of type Material Receipt. [supplier] is
    informational only (not persisted on Material Receipt) and currently
    ignored to keep the wire shape consistent with Purchase Receipt mode.

    Returns {name, docstatus} on success.
    """
    error = _validate_receipt_inputs(items, target_warehouse)
    if error is not None:
        return error

    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    if not _warehouse_exists(target_warehouse):
        return failure(
            f"Target warehouse '{target_warehouse}' does not exist.",
            code="VALIDATION_UNKNOWN_WAREHOUSE",
        )

    missing = _missing_items([row["item_code"] for row in items])
    if missing:
        return failure(
            f"Unknown item(s): {', '.join(missing)}",
            code="VALIDATION_UNKNOWN_ITEM",
        )

    if against_po:
        return _create_purchase_receipt(items, target_warehouse, against_po, posting_date)

    return _create_material_receipt(items, target_warehouse, posting_date)


def _validate_receipt_inputs(items, target_warehouse) -> Optional[dict]:
    if not target_warehouse or not target_warehouse.strip():
        return failure("target_warehouse is required.", code="VALIDATION_REQUIRED")
    if not items:
        return failure("At least one item is required.", code="VALIDATION_REQUIRED")
    for row in items:
        if not isinstance(row, dict):
            return failure("Each item must be an object.", code="VALIDATION_BAD_SHAPE")
        if "item_code" not in row or not row["item_code"]:
            return failure("Each item needs an item_code.", code="VALIDATION_REQUIRED")
        if "qty" not in row:
            return failure("Each item needs a qty.", code="VALIDATION_REQUIRED")
        try:
            qty = float(row["qty"])
        except (TypeError, ValueError):
            return failure(
                f"Invalid qty for {row.get('item_code')}.",
                code="VALIDATION_BAD_QTY",
            )
        if qty <= 0:
            return failure(
                f"qty must be greater than zero for {row['item_code']}.",
                code="VALIDATION_BAD_QTY",
            )
    return None


def _create_material_receipt(items, target_warehouse, posting_date) -> dict:
    doc = frappe.get_doc({
        "doctype": "Stock Entry",
        "stock_entry_type": "Material Receipt",
        "purpose": "Material Receipt",
        "posting_date": posting_date,
        "items": [
            {
                "item_code": row["item_code"],
                "qty": row["qty"],
                "t_warehouse": target_warehouse,
            }
            for row in items
        ],
    })
    doc.insert(ignore_permissions=False)
    doc.submit()
    return success({"name": doc.name, "docstatus": doc.docstatus})


def _create_purchase_receipt(items, target_warehouse, against_po, posting_date) -> dict:
    po_doc = frappe.db.get_value(
        "Purchase Order",
        {"name": against_po, "docstatus": 1},
        fieldname=["name", "supplier"],
        as_dict=True,
    )
    if not po_doc:
        return failure(
            f"Purchase Order '{against_po}' not found or not submitted.",
            code="VALIDATION_UNKNOWN_PO",
        )

    # Build a lookup of {item_code: po_detail_name, po_qty} from the PO lines.
    po_lines = frappe.get_list(
        "Purchase Order Item",
        filters=[["parent", "=", against_po]],
        fields=["name", "item_code", "qty"],
        limit=500,
    )
    po_line_by_code = {row["item_code"]: row for row in po_lines}

    rejected = [
        row["item_code"] for row in items if row["item_code"] not in po_line_by_code
    ]
    if rejected:
        return failure(
            f"Item(s) not on PO {against_po}: {', '.join(rejected)}",
            code="VALIDATION_PO_LINE_MISMATCH",
        )

    pr = frappe.get_doc({
        "doctype": "Purchase Receipt",
        "supplier": po_doc["supplier"],
        "posting_date": posting_date,
        "items": [
            {
                "item_code": row["item_code"],
                "qty": row["qty"],
                "warehouse": target_warehouse,
                "purchase_order": against_po,
                "purchase_order_item": po_line_by_code[row["item_code"]]["name"],
            }
            for row in items
        ],
    })
    pr.insert(ignore_permissions=False)
    pr.submit()
    return success({"name": pr.name, "docstatus": pr.docstatus})
