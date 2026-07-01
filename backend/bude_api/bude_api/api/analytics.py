"""Analytics endpoints — stock aging and reconciliation history.

    GET /api/method/bude_api.api.analytics.get_stock_aging
    GET /api/method/bude_api.api.analytics.get_reconciliation_history
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
def get_stock_aging(warehouse: str, threshold_days: int = 30, limit: int = 100) -> dict:
    """Items in a warehouse that have had no stock movement for >= threshold_days.

    GET /api/method/bude_api.api.analytics.get_stock_aging

    Returns rows ordered by days_idle DESC (longest idle first).
    Items with no ledger entry at all are included (never moved).
    """
    warehouse = (warehouse or "").strip()
    if not warehouse:
        return failure("warehouse is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    threshold_days = max(1, min(int(threshold_days), 365))
    limit = max(1, min(int(limit), 500))

    # Validate warehouse exists.
    warehouse_rows = frappe.get_list(
        "Warehouse",
        filters=[["name", "=", warehouse]],
        fields=["name"],
        limit=1,
    )
    if not warehouse_rows:
        return failure(f"Warehouse '{warehouse}' not found.", code="VALIDATION_UNKNOWN_WAREHOUSE")

    bins = frappe.get_list(
        "Bin",
        filters=[["warehouse", "=", warehouse]],
        fields=["item_code", "actual_qty"],
        order_by="item_code asc",
        limit_page_length=5000,
    )
    item_codes = [row["item_code"] for row in bins]
    item_names = _item_names(item_codes)
    last_movement = _last_movement_dates(warehouse, item_codes)
    today = _today()

    rows = []
    for row in bins:
        item_code = row["item_code"]
        last_date = last_movement.get(item_code)
        days_idle = None if last_date is None else _days_between(today, last_date)
        if days_idle is not None and days_idle < threshold_days:
            continue
        rows.append({
            "item_code": item_code,
            "item_name": item_names.get(item_code),
            "actual_qty": row.get("actual_qty"),
            "last_movement_date": str(last_date) if last_date else None,
            "days_idle": days_idle,
        })

    rows.sort(
        key=lambda row: (
            -1 if row.get("days_idle") is None else -row["days_idle"],
            row["item_code"],
        )
    )
    rows = rows[:limit]
    for row in rows:
        if row.get("days_idle") is None:
            row["days_idle"] = None

    return success(rows)


@_whitelist()
def get_reconciliation_history(warehouse: str = None, limit: int = 20) -> dict:
    """Return submitted Stock Reconciliation docs with per-item variance.

    GET /api/method/bude_api.api.analytics.get_reconciliation_history

    variance = counted_qty - current_qty (positive = surplus, negative = deficit)
    """
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 200))

    filters = {"docstatus": 1}
    if warehouse and warehouse.strip():
        filters["set_warehouse"] = warehouse.strip()

    recons = frappe.get_list(
        "Stock Reconciliation",
        filters=filters,
        fields=["name", "posting_date", "set_warehouse"],
        order_by="posting_date desc",
        limit_page_length=limit,
    )

    result = []
    for recon in recons:
        items_raw = frappe.get_list(
            "Stock Reconciliation Item",
            filters={"parent": recon["name"]},
            fields=["item_code", "item_name", "qty", "current_qty", "warehouse"],
        )
        items = []
        for item in items_raw:
            counted = float(item.get("qty") or 0)
            expected = float(item.get("current_qty") or 0)
            items.append({
                "item_code": item["item_code"],
                "item_name": item.get("item_name"),
                "counted_qty": counted,
                "expected_qty": expected,
                "variance": round(counted - expected, 6),
                "warehouse": item.get("warehouse") or recon.get("set_warehouse"),
            })
        result.append({
            "name": recon["name"],
            "posting_date": str(recon["posting_date"]) if recon.get("posting_date") else None,
            "warehouse": recon.get("set_warehouse"),
            "items": items,
        })

    return success(result)


def _item_names(item_codes: list[str]) -> dict[str, str | None]:
    if not item_codes:
        return {}
    rows = frappe.get_list(
        "Item",
        filters=[["item_code", "in", item_codes]],
        fields=["item_code", "item_name"],
        limit=len(item_codes),
    )
    return {row["item_code"]: row.get("item_name") for row in rows}


def _last_movement_dates(warehouse: str, item_codes: list[str]) -> dict[str, object]:
    if not item_codes:
        return {}
    rows = frappe.get_list(
        "Stock Ledger Entry",
        filters=[
            ["warehouse", "=", warehouse],
            ["item_code", "in", item_codes],
            ["is_cancelled", "=", 0],
        ],
        fields=["item_code", "posting_date"],
        order_by="posting_date desc",
        limit_page_length=5000,
    )
    latest = {}
    for row in rows:
        latest.setdefault(row["item_code"], row.get("posting_date"))
    return latest


def _today() -> str:
    try:
        return frappe.utils.nowdate()
    except Exception:
        from datetime import date

        return date.today().isoformat()


def _days_between(today, previous) -> int:
    try:
        return int(frappe.utils.date_diff(today, previous))
    except Exception:
        from datetime import date

        current = date.fromisoformat(str(today))
        earlier = date.fromisoformat(str(previous))
        return (current - earlier).days
