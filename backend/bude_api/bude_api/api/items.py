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
    "item_group",
]


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["GET", "POST"])


@_whitelist()
def search(
    query: str = "",
    limit: int = 20,
    page: int = 0,
    warehouse: Optional[str] = None,
    item_group: Optional[str] = None,
    in_stock: Optional[str] = None,
) -> dict:
    """Search Items by item_code/item_name (LIKE) and by Item Barcode (exact).

    Optional filters: item_group, warehouse (used with in_stock), in_stock.
    Supports pagination via page (0-based).
    Returns merged, deduped results ordered by item_code.
    """
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    query = (query or "").strip()
    limit = max(1, min(int(limit), 100))
    page = max(0, int(page))

    # Nothing to search without query or filters
    if not query and not item_group and not in_stock:
        return success([])

    # Base filters applied to all Item queries
    base_filters: list = [["disabled", "=", 0]]
    if item_group:
        base_filters.append(["item_group", "=", item_group])

    if in_stock:
        bin_filters: list = [["actual_qty", ">", 0]]
        if warehouse:
            bin_filters.append(["warehouse", "=", warehouse])
        stocked = frappe.get_all(
            "Bin", filters=bin_filters, pluck="item_code", limit=1000,
        )
        if not stocked:
            return success([])
        base_filters.append(["item_code", "in", list(set(stocked))])

    # Exact barcode match — only on page 0, barcode hits always come first
    barcode_matches: list[dict] = []
    if query and page == 0:
        barcode_rows = frappe.get_list(
            "Item Barcode",
            filters=[["barcode", "=", query]],
            fields=["parent"],
            limit=limit,
        )
        bc_codes = [r["parent"] for r in barcode_rows]
        if bc_codes:
            barcode_matches = frappe.get_list(
                "Item",
                filters=base_filters + [["item_code", "in", bc_codes]],
                fields=_ITEM_FIELDS,
                limit=limit,
            )

    # Text search or browse (empty query with filters)
    if query:
        name_matches = frappe.get_list(
            "Item",
            filters=base_filters,
            or_filters=[
                ["item_code", "like", f"%{query}%"],
                ["item_name", "like", f"%{query}%"],
            ],
            fields=_ITEM_FIELDS,
            limit=limit,
            limit_start=page * limit,
            order_by="item_code asc",
        )
    else:
        name_matches = frappe.get_list(
            "Item",
            filters=base_filters,
            fields=_ITEM_FIELDS,
            limit=limit,
            limit_start=page * limit,
            order_by="item_code asc",
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
def list_groups() -> dict:
    """Return all leaf Item Groups (is_group=0) for the filter chip."""
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    groups = frappe.get_all(
        "Item Group",
        filters={"is_group": 0},
        pluck="name",
        order_by="name asc",
        limit=200,
    )
    return success(groups)


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
