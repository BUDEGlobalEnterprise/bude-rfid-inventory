"""Asset tracking endpoints (standard ERPNext Asset module — no custom DocTypes).

Reads:  list_assets, get_asset, get_asset_movements, list_locations,
        list_asset_categories
Writes: set_epc, create_asset_movement, create_asset_repair,
        create_maintenance_log

All persistence uses standard DocTypes: Asset, Asset Movement, Asset Repair,
Asset Maintenance Log, Location, Asset Category, Employee — plus the bude_epc
Custom Field.
"""

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success
from .permissions import require_stock_execution_role

_EPC_DOCTYPES = {"Asset", "Item", "Serial No"}

_ASSET_LIST_FIELDS = [
    "name",
    "asset_name",
    "item_code",
    "asset_category",
    "location",
    "custodian",
    "status",
    "purchase_amount",
    "value_after_depreciation",
    "bude_epc",
]


def _whitelist(methods, allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=methods)


def _erpnext_message(exc):
    msg = (str(exc) or "").strip() or "ERPNext rejected the document."
    try:
        from frappe.utils import strip_html_tags

        msg = strip_html_tags(msg).strip() or msg
    except Exception:
        pass
    return msg


def _mutate(action):
    try:
        return action()
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(_erpnext_message(exc), code="VALIDATION_ERPNEXT")
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure(
            "You do not have permission for this action.", code="PERMISSION_DENIED"
        )


# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------


@_whitelist(methods=["GET", "POST"])
def list_assets(
    search: str | None = None,
    location: str | None = None,
    custodian: str | None = None,
    status: str | None = None,
    category: str | None = None,
    limit: int = 50,
) -> dict:
    """List assets with optional filters. Standard Asset DocType only."""
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 200))
    filters: list = []
    if location:
        filters.append(["location", "=", location])
    if custodian:
        filters.append(["custodian", "=", custodian])
    if status:
        filters.append(["status", "=", status])
    if category:
        filters.append(["asset_category", "=", category])

    or_filters = None
    search = (search or "").strip()
    if search:
        or_filters = [
            ["asset_name", "like", f"%{search}%"],
            ["name", "like", f"%{search}%"],
            ["item_code", "like", f"%{search}%"],
        ]

    rows = frappe.get_list(
        "Asset",
        filters=filters,
        or_filters=or_filters,
        fields=_ASSET_LIST_FIELDS,
        order_by="modified desc",
        limit_page_length=limit,
    )
    for row in rows:
        row["gross_purchase_amount"] = row.pop("purchase_amount", None)
    return success(rows)


@_whitelist(methods=["GET", "POST"])
def get_asset(name: str) -> dict:
    """Full asset detail incl. depreciation schedule + custodian name."""
    name = (name or "").strip()
    if not name:
        return failure("name is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    asset_rows = frappe.get_list(
        "Asset",
        filters=[["name", "=", name]],
        fields=["name"],
        limit=1,
    )
    if not asset_rows:
        return failure(f"Asset '{name}' not found.", code="VALIDATION_NOT_FOUND")

    doc = frappe.get_doc("Asset", name)
    custodian_name = None
    if doc.get("custodian"):
        employee_rows = frappe.get_list(
            "Employee",
            filters=[["name", "=", doc.custodian]],
            fields=["employee_name"],
            limit=1,
        )
        custodian_name = employee_rows[0]["employee_name"] if employee_rows else None

    # Depreciation schedule lives in the `schedules` child table when the asset
    # has calculate_depreciation enabled. Read it defensively across versions.
    schedule = []
    for row in (doc.get("schedules") or []):
        schedule.append(
            {
                "schedule_date": str(row.get("schedule_date") or ""),
                "depreciation_amount": row.get("depreciation_amount"),
                "accumulated_depreciation_amount": row.get(
                    "accumulated_depreciation_amount"
                ),
                "journal_entry": row.get("journal_entry"),
            }
        )

    data = {
        "name": doc.name,
        "asset_name": doc.get("asset_name"),
        "item_code": doc.get("item_code"),
        "asset_category": doc.get("asset_category"),
        "company": doc.get("company"),
        "status": doc.get("status"),
        "location": doc.get("location"),
        "custodian": doc.get("custodian"),
        "custodian_name": custodian_name,
        "purchase_date": str(doc.get("purchase_date") or ""),
        "available_for_use_date": str(doc.get("available_for_use_date") or ""),
        "gross_purchase_amount": doc.get("gross_purchase_amount"),
        "value_after_depreciation": doc.get("value_after_depreciation"),
        "maintenance_required": doc.get("maintenance_required"),
        "bude_epc": doc.get("bude_epc"),
        "depreciation_schedule": schedule,
    }
    return success(data)


@_whitelist(methods=["GET", "POST"])
def get_asset_movements(asset: str, limit: int = 20) -> dict:
    """Movement history for an asset (standard Asset Movement child rows)."""
    asset = (asset or "").strip()
    if not asset:
        return failure("asset is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")

    limit = max(1, min(int(limit), 100))
    # Asset Movement Item child rows carry the per-asset source/target.
    rows = frappe.get_list(
        "Asset Movement Item",
        filters=[["asset", "=", asset]],
        fields=[
            "parent",
            "source_location",
            "target_location",
            "from_employee",
            "to_employee",
        ],
        order_by="creation desc",
        limit_page_length=limit,
    )
    # Decorate with the parent movement's date + purpose.
    parents = {r["parent"] for r in rows}
    meta = {}
    if parents:
        for m in frappe.get_list(
            "Asset Movement",
            filters=[["name", "in", list(parents)]],
            fields=["name", "transaction_date", "purpose"],
            limit_page_length=len(parents),
        ):
            meta[m["name"]] = m
    for r in rows:
        parent = meta.get(r["parent"], {})
        r["transaction_date"] = str(parent.get("transaction_date") or "")
        r["purpose"] = parent.get("purpose")
    return success(rows)


@_whitelist(methods=["GET", "POST"])
def list_locations(limit: int = 200) -> dict:
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    limit = max(1, min(int(limit), 500))
    rows = frappe.get_list(
        "Location",
        fields=[
            "name",
            "location_name",
            "parent_location",
            "latitude",
            "longitude",
            "is_group",
        ],
        order_by="name asc",
        limit_page_length=limit,
    )
    return success(rows)


@_whitelist(methods=["GET", "POST"])
def list_asset_categories(limit: int = 200) -> dict:
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    limit = max(1, min(int(limit), 500))
    rows = frappe.get_list(
        "Asset Category",
        fields=["name"],
        order_by="name asc",
        limit_page_length=limit,
    )
    return success([r["name"] for r in rows])


# ---------------------------------------------------------------------------
# set_epc — bind a scanned EPC to an Asset / Item / Serial No (Custom Field)
# ---------------------------------------------------------------------------


@_whitelist(methods=["POST"])
def set_epc(doctype: str, name: str, epc: str) -> dict:
    """Write `bude_epc` on a standard record so future scans resolve to it."""
    doctype = (doctype or "").strip()
    name = (name or "").strip()
    epc = (epc or "").strip()

    if doctype not in _EPC_DOCTYPES:
        return failure(
            f"doctype must be one of {sorted(_EPC_DOCTYPES)}.",
            code="VALIDATION_BAD_DOCTYPE",
        )
    if not name:
        return failure("name is required.", code="VALIDATION_REQUIRED")
    if not epc:
        return failure("epc is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    permission_error = require_stock_execution_role(frappe)
    if permission_error is not None:
        return permission_error

    existing = frappe.get_list(
        doctype,
        filters=[["name", "=", name]],
        fields=["name"],
        limit=1,
    )
    if not existing:
        return failure(f"{doctype} '{name}' not found.", code="VALIDATION_NOT_FOUND")

    taken = frappe.get_list(
        doctype,
        filters=[["bude_epc", "=", epc], ["name", "!=", name]],
        fields=["name"],
        limit=1,
    )
    if taken:
        return failure(
            f"EPC already bound to {doctype} '{taken[0]['name']}'.",
            code="VALIDATION_EPC_TAKEN",
        )

    def _do():
        doc = frappe.get_doc(doctype, name)
        doc.set("bude_epc", epc)
        doc.save(ignore_permissions=False)
        return success({"doctype": doctype, "name": name, "bude_epc": epc})

    return _mutate(_do)


# ---------------------------------------------------------------------------
# Writes — Asset Movement (check-in / check-out / transfer)
# ---------------------------------------------------------------------------

_MOVE_PURPOSES = {"Issue", "Receipt", "Transfer"}


@_whitelist(methods=["POST"])
def create_asset_movement(
    assets: list,
    purpose: str,
    target_location: str | None = None,
    to_employee: str | None = None,
    transaction_date: str | None = None,
) -> dict:
    """Create + submit a standard Asset Movement.

    `purpose` is Issue (check-out to employee), Receipt (check-in), or
    Transfer (relocate). `assets` is a list of asset names. Each row's current
    location/custodian becomes the source; target_location/to_employee the
    destination.
    """
    purpose = (purpose or "").strip()
    if purpose not in _MOVE_PURPOSES:
        return failure(
            f"purpose must be one of {sorted(_MOVE_PURPOSES)}.",
            code="VALIDATION_BAD_PURPOSE",
        )
    if not assets:
        return failure("At least one asset is required.", code="VALIDATION_REQUIRED")
    if purpose in ("Transfer", "Receipt") and not target_location:
        return failure(
            "target_location is required for Transfer/Receipt.",
            code="VALIDATION_REQUIRED",
        )
    if purpose == "Issue" and not (to_employee or target_location):
        return failure(
            "to_employee or target_location is required for Issue.",
            code="VALIDATION_REQUIRED",
        )
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    permission_error = require_stock_execution_role(frappe)
    if permission_error is not None:
        return permission_error

    asset_names = [str(a).strip() for a in assets if str(a).strip()]
    company = None
    rows = []
    for asset in asset_names:
        current_rows = frappe.get_list(
            "Asset",
            filters=[["name", "=", asset]],
            fields=["location", "custodian", "company"],
            limit=1,
        )
        current = current_rows[0] if current_rows else None
        if not current:
            return failure(f"Asset '{asset}' not found.", code="VALIDATION_NOT_FOUND")
        company = company or current.get("company")
        rows.append(
            {
                "asset": asset,
                "source_location": current.get("location"),
                "from_employee": current.get("custodian"),
                "target_location": target_location,
                "to_employee": to_employee,
            }
        )

    def _do():
        doc = frappe.get_doc(
            {
                "doctype": "Asset Movement",
                "company": company,
                "purpose": purpose,
                "transaction_date": transaction_date or frappe.utils.now_datetime(),
                "assets": rows,
            }
        )
        doc.insert(ignore_permissions=False)
        doc.submit()
        return success({"name": doc.name, "docstatus": doc.docstatus})

    return _mutate(_do)


# ---------------------------------------------------------------------------
# Writes — Asset Repair (report a failure)
# ---------------------------------------------------------------------------


@_whitelist(methods=["POST"])
def create_asset_repair(
    asset: str,
    failure_date: str | None = None,
    description: str | None = None,
    repair_cost: float | None = None,
) -> dict:
    """Create a standard Asset Repair record (status Pending)."""
    asset = (asset or "").strip()
    if not asset:
        return failure("asset is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    permission_error = require_stock_execution_role(frappe)
    if permission_error is not None:
        return permission_error
    existing = frappe.get_list(
        "Asset",
        filters=[["name", "=", asset]],
        fields=["name"],
        limit=1,
    )
    if not existing:
        return failure(f"Asset '{asset}' not found.", code="VALIDATION_NOT_FOUND")

    data = {
        "doctype": "Asset Repair",
        "asset": asset,
        "failure_date": failure_date or frappe.utils.now_datetime(),
        "repair_status": "Pending",
    }
    if description:
        data["description"] = description
    if repair_cost is not None:
        data["repair_cost"] = repair_cost

    def _do():
        doc = frappe.get_doc(data)
        doc.insert(ignore_permissions=False)
        return success({"name": doc.name, "docstatus": doc.docstatus})

    return _mutate(_do)


# ---------------------------------------------------------------------------
# Maintenance logs — list scheduled tasks + mark one complete
# ---------------------------------------------------------------------------


@_whitelist(methods=["GET", "POST"])
def list_maintenance_logs(
    asset: str | None = None,
    status: str = "Planned",
    limit: int = 50,
) -> dict:
    """Scheduled maintenance tasks (standard Asset Maintenance Log)."""
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    limit = max(1, min(int(limit), 200))
    filters: list = []
    if status:
        filters.append(["maintenance_status", "=", status])
    if asset:
        filters.append(["asset_name", "=", asset])
    rows = frappe.get_list(
        "Asset Maintenance Log",
        filters=filters,
        fields=[
            "name",
            "asset_name",
            "item_code",
            "task",
            "maintenance_status",
            "due_date",
            "completion_date",
        ],
        order_by="due_date asc",
        limit_page_length=limit,
    )
    for r in rows:
        r["due_date"] = str(r.get("due_date") or "")
        r["completion_date"] = str(r.get("completion_date") or "")
    return success(rows)


@_whitelist(methods=["POST"])
def complete_maintenance_log(
    log: str, completion_date: str | None = None
) -> dict:
    """Mark a scheduled Asset Maintenance Log as completed."""
    log = (log or "").strip()
    if not log:
        return failure("log is required.", code="VALIDATION_REQUIRED")
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    permission_error = require_stock_execution_role(frappe)
    if permission_error is not None:
        return permission_error
    existing = frappe.get_list(
        "Asset Maintenance Log",
        filters=[["name", "=", log]],
        fields=["name"],
        limit=1,
    )
    if not existing:
        return failure(
            f"Maintenance log '{log}' not found.", code="VALIDATION_NOT_FOUND"
        )

    doc = frappe.get_doc("Asset Maintenance Log", log)
    doc.maintenance_status = "Completed"
    doc.completion_date = completion_date or frappe.utils.nowdate()

    def _do():
        doc.save(ignore_permissions=False)
        return success({"name": doc.name, "maintenance_status": "Completed"})

    return _mutate(_do)
