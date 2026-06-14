"""Warehouse list endpoint.

    GET /api/method/bude_api.api.warehouses.list

Wraps Frappe's Warehouse DocType list so mobile clients use a consistent
bude_api envelope instead of calling /api/resource/Warehouse directly.
"""

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
    return frappe.whitelist(allow_guest=allow_guest, methods=["GET", "POST"])


@_whitelist()
def get_stock(warehouse: str, limit: int = 100) -> dict:
    """Return Bin rows for a warehouse (items in stock), ordered by item_code.

    GET /api/method/bude_api.api.warehouses.get_stock
    """
    warehouse = (warehouse or "").strip()
    if not warehouse:
        return failure("warehouse is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 500))
    rows = frappe.get_list(
        "Bin",
        filters=[["warehouse", "=", warehouse]],
        fields=[
            "item_code",
            "item_name",
            "actual_qty",
            "reserved_qty",
            "ordered_qty",
            "projected_qty",
            "stock_uom",
        ],
        order_by="item_code asc",
        limit_page_length=limit,
    )
    return success(rows)


@_whitelist()
def list(limit: int = 100) -> dict:
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    rows = frappe.get_list(
        "Warehouse",
        filters={"disabled": 0},
        fields=["name"],
        order_by="name asc",
        limit_page_length=int(limit),
    )
    return success([r["name"] for r in rows])
