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
    if not frappe.db.exists("Warehouse", warehouse):
        return failure(f"Warehouse '{warehouse}' not found.", code="VALIDATION_UNKNOWN_WAREHOUSE")

    rows = frappe.db.sql(
        """
        SELECT
            b.item_code,
            i.item_name,
            b.actual_qty,
            MAX(sle.posting_date) AS last_movement_date,
            DATEDIFF(CURDATE(), MAX(sle.posting_date)) AS days_idle
        FROM `tabBin` b
        JOIN `tabItem` i ON i.name = b.item_code
        LEFT JOIN `tabStock Ledger Entry` sle
               ON sle.item_code = b.item_code
              AND sle.warehouse  = %(warehouse)s
              AND sle.is_cancelled = 0
        WHERE b.warehouse = %(warehouse)s
        GROUP BY b.item_code, i.item_name, b.actual_qty
        HAVING days_idle >= %(threshold_days)s OR last_movement_date IS NULL
        ORDER BY days_idle DESC, b.item_code ASC
        LIMIT %(limit)s
        """,
        values={
            "warehouse": warehouse,
            "threshold_days": threshold_days,
            "limit": limit,
        },
        as_dict=True,
    )

    for row in rows:
        # Convert date objects to ISO strings for JSON serialisation.
        if row.get("last_movement_date"):
            row["last_movement_date"] = str(row["last_movement_date"])
        if row.get("days_idle") is None:
            row["days_idle"] = None  # truly never moved

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
        items_raw = frappe.get_all(
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
