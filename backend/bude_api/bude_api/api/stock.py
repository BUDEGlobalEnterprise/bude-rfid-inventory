"""Stock write endpoints.

    POST /api/method/bude_api.api.stock.create_transfer   (auth required)

Phase 3 Slice 2 ships only Material Transfer. Receipts and reconciliation
land in Slices 3 and 4. All writes go through standard ERPNext DocTypes
(Stock Entry, Warehouse, Item) — no custom DocTypes.
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
