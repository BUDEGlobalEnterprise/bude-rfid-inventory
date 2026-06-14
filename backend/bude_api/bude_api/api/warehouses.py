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
