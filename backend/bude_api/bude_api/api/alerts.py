"""Alerts / notifications — computed live from standard DocTypes.

    GET/POST /api/method/bude_api.api.alerts.list_alerts   (auth required)

No custom DocTypes and nothing persisted: every alert is derived on demand
from Asset Maintenance Log, Asset, Bin, and Item. Categories:
maintenance_due, assets_in_maintenance, out_of_stock, low_stock.
"""


try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success

_PER_CATEGORY = 50


def _whitelist():
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=False, methods=["GET", "POST"])


def _alert(category, severity, title, subtitle, ref_doctype, ref_name):
    return {
        "category": category,
        "severity": severity,
        "title": title,
        "subtitle": subtitle,
        "ref_doctype": ref_doctype,
        "ref_name": ref_name,
    }


@_whitelist()
def list_alerts(limit: int = 200) -> dict:
    """Aggregate operational alerts. Returns {alerts, counts, total}."""
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 500))
    alerts: list = []

    alerts += _maintenance_due()
    alerts += _assets_in_maintenance()
    alerts += _stock_alerts()

    alerts = alerts[:limit]
    counts: dict = {}
    for a in alerts:
        counts[a["category"]] = counts.get(a["category"], 0) + 1

    return success({"alerts": alerts, "counts": counts, "total": len(alerts)})


def _maintenance_due() -> list:
    today = frappe.utils.nowdate()
    rows = frappe.get_all(
        "Asset Maintenance Log",
        filters=[
            ["maintenance_status", "in", ["Planned", "Overdue"]],
            ["due_date", "<=", today],
        ],
        fields=["name", "asset_name", "task", "due_date", "maintenance_status"],
        order_by="due_date asc",
        limit_page_length=_PER_CATEGORY,
    )
    return [
        _alert(
            "maintenance_due",
            "high",
            f"Maintenance due: {r.get('task') or r['name']}",
            f"{r.get('asset_name') or ''} · due {r.get('due_date')}",
            "Asset Maintenance Log",
            r["name"],
        )
        for r in rows
    ]


def _assets_in_maintenance() -> list:
    rows = frappe.get_all(
        "Asset",
        filters=[["status", "in", ["In Maintenance", "Out of Order"]]],
        fields=["name", "asset_name", "status", "location"],
        order_by="modified desc",
        limit_page_length=_PER_CATEGORY,
    )
    return [
        _alert(
            "assets_in_maintenance",
            "medium",
            f"{r.get('asset_name') or r['name']} — {r.get('status')}",
            r.get("location") or "",
            "Asset",
            r["name"],
        )
        for r in rows
    ]


def _stock_alerts() -> list:
    # Out of stock: any Bin at or below zero.
    out_rows = frappe.db.sql(
        """
        SELECT b.item_code, b.warehouse, b.actual_qty
        FROM `tabBin` b
        WHERE b.actual_qty <= 0
        ORDER BY b.actual_qty ASC
        LIMIT %(limit)s
        """,
        values={"limit": _PER_CATEGORY},
        as_dict=True,
    )
    # Low stock: on-hand positive but at/below the item's safety stock.
    low_rows = frappe.db.sql(
        """
        SELECT b.item_code, b.warehouse, b.actual_qty, i.safety_stock
        FROM `tabBin` b
        JOIN `tabItem` i ON i.name = b.item_code
        WHERE i.safety_stock > 0
          AND b.actual_qty > 0
          AND b.actual_qty <= i.safety_stock
        ORDER BY b.actual_qty ASC
        LIMIT %(limit)s
        """,
        values={"limit": _PER_CATEGORY},
        as_dict=True,
    )

    out = [
        _alert(
            "out_of_stock",
            "high",
            f"Out of stock: {r['item_code']}",
            f"{r['warehouse']} · {r['actual_qty']}",
            "Item",
            r["item_code"],
        )
        for r in out_rows
    ]
    low = [
        _alert(
            "low_stock",
            "medium",
            f"Low stock: {r['item_code']}",
            f"{r['warehouse']} · {r['actual_qty']} ≤ {r['safety_stock']}",
            "Item",
            r["item_code"],
        )
        for r in low_rows
    ]
    return out + low
