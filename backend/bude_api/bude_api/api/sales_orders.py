"""Sales Order fulfillment endpoints.

Reads open Sales Orders and creates submitted Delivery Notes from exact
mobile pick/pack dispatch payloads. Uses only standard ERPNext DocTypes.
"""

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success
from . import stock as stock_api


_CLOSED_STATUSES = {"Closed", "Completed", "Cancelled"}
_QTY_EPSILON = 0.000001


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["GET", "POST"])


@_whitelist()
def list_open(limit: int = 50, company: str | None = None) -> dict:
    """Return submitted Sales Orders with pending delivery quantities."""
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    try:
        limit = max(1, min(int(limit), 200))
    except (TypeError, ValueError):
        return failure("limit must be an integer.", code="VALIDATION_BAD_LIMIT")

    filters = [
        ["docstatus", "=", 1],
        ["status", "not in", list(_CLOSED_STATUSES)],
    ]
    company = (company or "").strip()
    if company:
        filters.append(["company", "=", company])

    rows = frappe.get_list(
        "Sales Order",
        filters=filters,
        fields=[
            "name",
            "customer",
            "transaction_date",
            "delivery_date",
            "status",
            "company",
        ],
        order_by="transaction_date desc",
        limit_page_length=limit,
    )
    names = [row["name"] for row in rows]
    pending = _pending_summary_by_order(names)

    return success([
        {
            **row,
            "item_count": pending.get(row["name"], {}).get("item_count", 0),
            "pending_qty": pending.get(row["name"], {}).get("pending_qty", 0.0),
        }
        for row in rows
        if pending.get(row["name"], {}).get("item_count", 0) > 0
    ])


@_whitelist()
def get(name: str) -> dict:
    """Return Sales Order header and pending delivery lines."""
    name = (name or "").strip()
    if not name:
        return failure("name is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    so = _sales_order(name)
    if isinstance(so, dict) and so.get("ok") is False:
        return so

    lines = _pending_lines(name)
    return success({**so, "items": lines})


@_whitelist()
def create_delivery_note(
    sales_order: str,
    source_warehouse: str,
    items: list,
    posting_date: str | None = None,
    company: str | None = None,
    source_location: str | None = None,
) -> dict:
    """Create and submit a Delivery Note for an exactly fulfilled Sales Order."""
    sales_order = (sales_order or "").strip()
    source_warehouse = (source_warehouse or "").strip()
    if not sales_order:
        return failure("sales_order is required.", code="VALIDATION_REQUIRED")
    if not source_warehouse:
        return failure("source_warehouse is required.", code="VALIDATION_REQUIRED")
    if not items:
        return failure("At least one item is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    so = _sales_order(sales_order, company=company)
    if isinstance(so, dict) and so.get("ok") is False:
        return so

    stock_api.frappe = frappe
    source_or_error = stock_api._resolve_effective_warehouse(
        source_warehouse,
        source_location,
        so.get("company") or company,
        label="Source",
    )
    if isinstance(source_or_error, dict):
        return source_or_error
    effective_source, resolved_company = source_or_error

    pending = _pending_lines(sales_order)
    exact_error = _validate_exact_items(items, pending)
    if exact_error is not None:
        return exact_error

    pending_by_name = {row["sales_order_item"]: row for row in pending}
    erp_items = stock_api.expand_stock_rows(
        frappe,
        items,
        warehouse=effective_source,
        flow="outbound",
        row_builder=lambda row, allocation: {
            "item_code": row["item_code"],
            "qty": (allocation or row)["qty"],
            "warehouse": effective_source,
            "against_sales_order": sales_order,
            "so_detail": row["sales_order_item"],
        },
    )
    if isinstance(erp_items, dict):
        return erp_items

    doc_data = {
        "doctype": "Delivery Note",
        "customer": so.get("customer"),
        "posting_date": posting_date,
        "items": erp_items,
    }
    if resolved_company:
        doc_data["company"] = resolved_company
    for row in doc_data["items"]:
        source_line = pending_by_name[row["so_detail"]]
        if source_line.get("stock_uom"):
            row["uom"] = source_line["stock_uom"]

    return stock_api._insert_and_submit(doc_data)


def _sales_order(name: str, company: str | None = None) -> dict:
    row = frappe.db.get_value(
        "Sales Order",
        {"name": name, "docstatus": 1},
        fieldname=[
            "name",
            "customer",
            "transaction_date",
            "delivery_date",
            "status",
            "company",
        ],
        as_dict=True,
    )
    if not row:
        return failure(
            f"Sales Order '{name}' not found or not submitted.",
            code="VALIDATION_UNKNOWN_SALES_ORDER",
        )
    if row.get("status") in _CLOSED_STATUSES:
        return failure(
            f"Sales Order '{name}' is {row.get('status')}.",
            code="VALIDATION_SALES_ORDER_CLOSED",
        )
    requested_company = (company or "").strip()
    if requested_company and row.get("company") and row.get("company") != requested_company:
        return failure(
            f"Sales Order '{name}' belongs to '{row.get('company')}', not '{requested_company}'.",
            code="VALIDATION_SO_COMPANY_MISMATCH",
        )
    return row


def _pending_summary_by_order(names: list[str]) -> dict[str, dict]:
    if not names:
        return {}
    lines = frappe.get_all(
        "Sales Order Item",
        filters=[["parent", "in", names]],
        fields=["parent", "qty", "delivered_qty"],
        limit=5000,
    )
    summary: dict[str, dict] = {}
    for line in lines:
        pending = _pending_qty(line)
        if pending <= _QTY_EPSILON:
            continue
        bucket = summary.setdefault(line["parent"], {"item_count": 0, "pending_qty": 0.0})
        bucket["item_count"] += 1
        bucket["pending_qty"] += pending
    return summary


def _pending_lines(sales_order: str) -> list[dict]:
    rows = frappe.get_all(
        "Sales Order Item",
        filters=[["parent", "=", sales_order]],
        fields=[
            "name",
            "item_code",
            "item_name",
            "qty",
            "delivered_qty",
            "stock_uom",
            "warehouse",
        ],
        order_by="idx asc",
        limit=500,
    )
    result = []
    tracking_by_item = _tracking_by_item({row["item_code"] for row in rows})
    for row in rows:
        pending = _pending_qty(row)
        if pending <= _QTY_EPSILON:
            continue
        tracking = tracking_by_item.get(row["item_code"], {})
        result.append({
            "sales_order_item": row["name"],
            "item_code": row["item_code"],
            "item_name": row.get("item_name"),
            "pending_qty": pending,
            "stock_uom": row.get("stock_uom"),
            "warehouse": row.get("warehouse"),
            "has_batch_no": tracking.get("has_batch_no") or 0,
            "has_serial_no": tracking.get("has_serial_no") or 0,
            "create_new_batch": tracking.get("create_new_batch") or 0,
        })
    return result


def _tracking_by_item(item_codes: set[str]) -> dict[str, dict]:
    if not item_codes:
        return {}
    rows = frappe.get_list(
        "Item",
        filters=[["item_code", "in", list(item_codes)]],
        fields=["item_code", "has_batch_no", "has_serial_no", "create_new_batch"],
        limit=len(item_codes),
    )
    return {row["item_code"]: row for row in rows}


def _pending_qty(row: dict) -> float:
    return float(row.get("qty") or 0) - float(row.get("delivered_qty") or 0)


def _validate_exact_items(items: list, pending: list[dict]) -> dict | None:
    pending_by_name = {row["sales_order_item"]: row for row in pending}
    seen: set[str] = set()

    for row in items:
        if not isinstance(row, dict):
            return failure("Each item must be an object.", code="VALIDATION_BAD_SHAPE")
        line_name = (row.get("sales_order_item") or "").strip()
        if not line_name:
            return failure("Each item needs a sales_order_item.", code="VALIDATION_REQUIRED")
        if line_name in seen:
            return failure(
                f"Duplicate Sales Order line '{line_name}'.",
                code="VALIDATION_DUPLICATE_SO_LINE",
            )
        seen.add(line_name)
        if line_name not in pending_by_name:
            return failure(
                f"Sales Order line '{line_name}' is not pending on this order.",
                code="VALIDATION_SO_LINE_MISMATCH",
            )
        pending_row = pending_by_name[line_name]
        if row.get("item_code") != pending_row["item_code"]:
            return failure(
                f"Item mismatch for Sales Order line '{line_name}'.",
                code="VALIDATION_SO_LINE_MISMATCH",
            )
        try:
            qty = float(row.get("qty"))
        except (TypeError, ValueError):
            return failure(
                f"Invalid qty for {row.get('item_code')}.",
                code="VALIDATION_BAD_QTY",
            )
        expected = float(pending_row["pending_qty"])
        if abs(qty - expected) > _QTY_EPSILON:
            return failure(
                f"Line '{line_name}' requires exactly {expected:g}.",
                code="VALIDATION_EXACT_QTY_REQUIRED",
            )

    missing = [row["sales_order_item"] for row in pending if row["sales_order_item"] not in seen]
    if missing:
        return failure(
            f"Missing Sales Order line(s): {', '.join(missing)}",
            code="VALIDATION_MISSING_SO_LINES",
        )
    return None
