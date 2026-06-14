"""Item lookup endpoints.

    POST /api/method/bude_api.api.items.search           (auth required)
    POST /api/method/bude_api.api.items.get_by_barcode   (auth required)
    POST /api/method/bude_api.api.items.get_stock        (auth required)

All three use standard ERPNext DocTypes: Item, Item Barcode, Bin.
No custom DocTypes, no writes — read-only Phase 2 lookups.
"""

from typing import Optional

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success

_ITEM_FIELDS = [
    "name",
    "item_code",
    "item_name",
    "description",
    "stock_uom",
    "image",
    "disabled",
]


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["GET", "POST"])


@_whitelist()
def search(query: str, limit: int = 20) -> dict:
    """Search Items by item_code/item_name (LIKE) and by Item Barcode (exact).

    Returns merged, deduped results ordered by item_code.
    """
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    query = (query or "").strip()
    if not query:
        return success([])

    limit = max(1, min(int(limit), 100))

    name_matches = frappe.get_list(
        "Item",
        filters=[["disabled", "=", 0]],
        or_filters=[
            ["item_code", "like", f"%{query}%"],
            ["item_name", "like", f"%{query}%"],
        ],
        fields=_ITEM_FIELDS,
        limit=limit,
        order_by="item_code asc",
    )

    barcode_rows = frappe.get_list(
        "Item Barcode",
        filters=[["barcode", "=", query]],
        fields=["parent"],
        limit=limit,
    )
    barcode_item_codes = [row["parent"] for row in barcode_rows]
    barcode_matches: list[dict] = []
    if barcode_item_codes:
        barcode_matches = frappe.get_list(
            "Item",
            filters=[
                ["disabled", "=", 0],
                ["item_code", "in", barcode_item_codes],
            ],
            fields=_ITEM_FIELDS,
            limit=limit,
        )

    seen: set[str] = set()
    merged: list[dict] = []
    for row in barcode_matches + name_matches:
        code = row["item_code"]
        if code in seen:
            continue
        seen.add(code)
        merged.append(row)

    return success(merged[:limit])


@_whitelist()
def get_by_barcode(barcode: str) -> dict:
    barcode = (barcode or "").strip()
    if not barcode:
        return failure("Barcode is required.", code="VALIDATION_REQUIRED")

    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    rows = frappe.get_list(
        "Item Barcode",
        filters=[["barcode", "=", barcode]],
        fields=["parent"],
        limit=1,
    )
    if not rows:
        return failure("No item matches that barcode.", code="ITEM_NOT_FOUND")

    item_code = rows[0]["parent"]
    items = frappe.get_list(
        "Item",
        filters=[["item_code", "=", item_code]],
        fields=_ITEM_FIELDS,
        limit=1,
    )
    if not items:
        return failure("Barcode points to a missing item.", code="ITEM_NOT_FOUND")

    return success(items[0])


@_whitelist()
def get_ledger(
    item_code: str, warehouse: Optional[str] = None, limit: int = 50
) -> dict:
    """Return Stock Ledger Entry rows for an item, newest first.

    GET /api/method/bude_api.api.items.get_ledger
    """
    item_code = (item_code or "").strip()
    if not item_code:
        return failure("item_code is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 200))
    filters: list = [["item_code", "=", item_code], ["is_cancelled", "=", 0]]
    if warehouse:
        filters.append(["warehouse", "=", warehouse])

    rows = frappe.get_list(
        "Stock Ledger Entry",
        filters=filters,
        fields=[
            "posting_date",
            "posting_time",
            "voucher_type",
            "voucher_no",
            "warehouse",
            "actual_qty",
            "qty_after_transaction",
            "valuation_rate",
            "stock_value_difference",
        ],
        order_by="posting_date desc, posting_time desc",
        limit_page_length=limit,
    )
    return success(rows)


@_whitelist()
def get_stock(item_code: str, warehouse: Optional[str] = None) -> dict:
    item_code = (item_code or "").strip()
    if not item_code:
        return failure("item_code is required.", code="VALIDATION_REQUIRED")

    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    filters: list = [["item_code", "=", item_code]]
    if warehouse:
        filters.append(["warehouse", "=", warehouse])

    bins = frappe.get_list(
        "Bin",
        filters=filters,
        fields=[
            "warehouse",
            "actual_qty",
            "reserved_qty",
            "ordered_qty",
            "projected_qty",
            "stock_uom",
        ],
        order_by="warehouse asc",
    )
    return success(bins)
