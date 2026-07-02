"""Employee self-service endpoints for the Bude HR Flutter app.

All persistence uses standard ERPNext/HRMS DocTypes. These endpoints are a
clean-room implementation inspired by common ESS flows, not copied from the
reference HR apps in the repository.
"""

from datetime import date, timedelta

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success

HR_ROLES = {"Employee", "HR User", "HR Manager", "System Manager"}
# Roles allowed to view team data and act on approvals.
MANAGER_ROLES = {"HR User", "HR Manager", "System Manager", "Leave Approver", "Expense Approver"}


def _whitelist(methods=None, allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=methods or ["GET", "POST"])


def _require_hr_role() -> dict | None:
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    user = getattr(getattr(frappe, "session", None), "user", None)
    if user == "Administrator":
        return None
    roles = set(frappe.get_roles(user) or [])
    if roles.intersection(HR_ROLES):
        return None
    return failure("An HR role is required for this action.", code="PERMISSION_DENIED")


def _require_manager() -> dict | None:
    if frappe is None:
        return failure("Frappe not available.", code="ENV_NO_FRAPPE")
    user = getattr(getattr(frappe, "session", None), "user", None)
    if user == "Administrator":
        return None
    roles = set(frappe.get_roles(user) or [])
    if roles.intersection(MANAGER_ROLES):
        return None
    return failure("A manager role is required for this action.", code="PERMISSION_DENIED")


def _current_employee() -> dict | None:
    user = getattr(getattr(frappe, "session", None), "user", None)
    rows = frappe.get_list(
        "Employee",
        filters=[["user_id", "=", user], ["status", "=", "Active"]],
        fields=[
            "name",
            "employee_name",
            "company",
            "department",
            "designation",
            "user_id",
        ],
        limit_page_length=1,
    )
    return rows[0] if rows else None


def _employee_or_failure() -> tuple[dict | None, dict | None]:
    denied = _require_hr_role()
    if denied:
        return None, denied
    employee = _current_employee()
    if not employee:
        return None, failure(
            "No active Employee record is linked to this user.",
            code="HR_EMPLOYEE_NOT_FOUND",
        )
    return employee, None


@_whitelist(["GET", "POST"])
def profile() -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Employee",
        filters=[["name", "=", employee["name"]]],
        fields=[
            "name",
            "employee_name",
            "company",
            "department",
            "designation",
            "date_of_joining",
            "reports_to",
            "cell_number",
            "personal_email",
            "company_email",
            "emergency_phone_number",
            "person_to_be_contacted",
            "relation",
            "user_id",
        ],
        limit_page_length=1,
    )
    detail = rows[0] if rows else employee
    return success(detail)


@_whitelist(["GET", "POST"])
def employee_documents(limit: int = 50) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "File",
        filters=[
            ["attached_to_doctype", "=", "Employee"],
            ["attached_to_name", "=", employee["name"]],
        ],
        fields=["name", "file_name", "file_url", "is_private"],
        order_by="creation desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([
        {
            "name": row.get("name"),
            "file_name": row.get("file_name") or "",
            "file_url": row.get("file_url") or "",
            "is_private": bool(row.get("is_private")),
        }
        for row in rows
    ])


@_whitelist(["GET", "POST"])
def attendance_status() -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    latest = frappe.get_list(
        "Employee Checkin",
        filters=[["employee", "=", employee["name"]]],
        fields=["name", "time", "log_type"],
        order_by="time desc",
        limit_page_length=1,
    )
    latest_in = frappe.get_list(
        "Employee Checkin",
        filters=[["employee", "=", employee["name"]], ["log_type", "=", "IN"]],
        fields=["time"],
        order_by="time desc",
        limit_page_length=1,
    )
    latest_out = frappe.get_list(
        "Employee Checkin",
        filters=[["employee", "=", employee["name"]], ["log_type", "=", "OUT"]],
        fields=["time"],
        order_by="time desc",
        limit_page_length=1,
    )
    last = latest[0] if latest else {}
    return success({
        "checked_in": last.get("log_type") == "IN",
        "last_check_in": str(latest_in[0].get("time")) if latest_in else None,
        "last_check_out": str(latest_out[0].get("time")) if latest_out else None,
    })


@_whitelist(["GET", "POST"])
def attendance_history(limit: int = 30) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Employee Checkin",
        filters=[["employee", "=", employee["name"]]],
        fields=["name", "time", "log_type"],
        order_by="time desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([{
        "name": row.get("name"),
        "time": str(row.get("time") or ""),
        "log_type": row.get("log_type"),
    } for row in rows])


@_whitelist(["POST"])
def check_in(
    type: str = "IN",
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    log_type = str(type or "").upper()
    if log_type not in {"IN", "OUT"}:
        return failure("type must be IN or OUT.", code="VALIDATION_BAD_TYPE")
    try:
        payload = {
            "doctype": "Employee Checkin",
            "employee": employee["name"],
            "log_type": log_type,
            "time": frappe.utils.now_datetime(),
        }
        if latitude is not None and longitude is not None:
            payload["latitude"] = latitude
            payload["longitude"] = longitude
        doc = frappe.get_doc(payload)
        doc.insert(ignore_permissions=False)
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": doc.name, "log_type": log_type})


@_whitelist(["GET", "POST"])
def leave_balances() -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    allocations = frappe.get_list(
        "Leave Allocation",
        filters=[
            ["employee", "=", employee["name"]],
            ["docstatus", "=", 1],
        ],
        fields=["leave_type", "total_leaves_allocated"],
        limit_page_length=200,
    )
    applications = frappe.get_list(
        "Leave Application",
        filters=[
            ["employee", "=", employee["name"]],
            ["docstatus", "=", 1],
            ["status", "in", ["Approved", "Open"]],
        ],
        fields=["leave_type", "total_leave_days"],
        limit_page_length=500,
    )
    used_by_type: dict[str, float] = {}
    for row in applications:
        used_by_type[row["leave_type"]] = used_by_type.get(row["leave_type"], 0) + float(
            row.get("total_leave_days") or 0
        )
    rows = []
    for row in allocations:
        allocated = float(row.get("total_leaves_allocated") or 0)
        used = used_by_type.get(row["leave_type"], 0)
        rows.append({
            "leave_type": row["leave_type"],
            "allocated": allocated,
            "used": used,
            "available": allocated - used,
        })
    return success(rows)


@_whitelist(["POST"])
def apply_leave(
    leave_type: str,
    from_date: str,
    to_date: str,
    reason: str | None = None,
    half_day: bool = False,
    half_day_date: str | None = None,
) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    if not leave_type or not from_date or not to_date:
        return failure(
            "leave_type, from_date, and to_date are required.",
            code="VALIDATION_REQUIRED",
        )
    try:
        is_half_day = _as_bool(half_day)
        doc = frappe.get_doc({
            "doctype": "Leave Application",
            "employee": employee["name"],
            "company": employee.get("company"),
            "leave_type": leave_type,
            "from_date": from_date,
            "to_date": to_date,
            "description": reason,
            "half_day": 1 if is_half_day else 0,
            "half_day_date": half_day_date or from_date if is_half_day else None,
        })
        doc.insert(ignore_permissions=False)
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": doc.name, "status": doc.get("status")})


def _leave_is_cancellable(row: dict) -> bool:
    # ERPNext only allows cancelling a submitted application that is not
    # already cancelled/rejected.
    return int(row.get("docstatus") or 0) == 1 and row.get("status") not in {
        "Cancelled",
        "Rejected",
    }


def _leave_row(row: dict) -> dict:
    return {
        "name": row.get("name"),
        "leave_type": row.get("leave_type"),
        "from_date": str(row.get("from_date") or ""),
        "to_date": str(row.get("to_date") or ""),
        "status": row.get("status"),
        "total_leave_days": float(row.get("total_leave_days") or 0),
        "description": row.get("description") or "",
        "cancellable": _leave_is_cancellable(row),
    }


@_whitelist(["GET", "POST"])
def leave_requests(limit: int = 50) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Leave Application",
        filters=[["employee", "=", employee["name"]]],
        fields=[
            "name",
            "leave_type",
            "from_date",
            "to_date",
            "status",
            "total_leave_days",
            "description",
            "docstatus",
        ],
        order_by="from_date desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([_leave_row(row) for row in rows])


def _owned_leave(name: str) -> tuple[dict | None, dict | None]:
    """Fetch a leave application only if it belongs to the current employee.

    Returns (row, error). A missing/foreign record yields HR_LEAVE_NOT_FOUND
    so we never leak the existence of another employee's application.
    """
    employee, error = _employee_or_failure()
    if error:
        return None, error
    rows = frappe.get_list(
        "Leave Application",
        filters=[["name", "=", name], ["employee", "=", employee["name"]]],
        fields=[
            "name",
            "leave_type",
            "from_date",
            "to_date",
            "status",
            "total_leave_days",
            "description",
            "docstatus",
        ],
        limit_page_length=1,
    )
    if not rows:
        return None, failure("Leave application not found.", code="HR_LEAVE_NOT_FOUND")
    return rows[0], None


@_whitelist(["GET", "POST"])
def leave_request_detail(name: str) -> dict:
    row, error = _owned_leave(name)
    if error:
        return error
    return success(_leave_row(row))


@_whitelist(["POST"])
def cancel_leave(name: str) -> dict:
    row, error = _owned_leave(name)
    if error:
        return error
    if not _leave_is_cancellable(row):
        return failure(
            "This leave application cannot be cancelled.",
            code="HR_LEAVE_NOT_CANCELLABLE",
        )
    try:
        doc = frappe.get_doc("Leave Application", name)
        doc.cancel()
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": name, "status": "Cancelled"})


@_whitelist(["GET", "POST"])
def expense_claims(limit: int = 50) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Expense Claim",
        filters=[["employee", "=", employee["name"]]],
        fields=["name", "status", "total_claimed_amount", "posting_date"],
        order_by="modified desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success(rows)


@_whitelist(["POST"])
def submit_expense_claim(
    expense_type: str,
    amount: float,
    description: str | None = None,
    posting_date: str | None = None,
) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    if not expense_type or float(amount or 0) <= 0:
        return failure("expense_type and positive amount are required.", code="VALIDATION_REQUIRED")
    try:
        doc = frappe.get_doc({
            "doctype": "Expense Claim",
            "employee": employee["name"],
            "company": employee.get("company"),
            "posting_date": posting_date,
            "expenses": [{
                "expense_type": expense_type,
                "amount": amount,
                "sanctioned_amount": amount,
                "description": description,
            }],
        })
        doc.insert(ignore_permissions=False)
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": doc.name, "status": doc.get("status")})


@_whitelist(["GET", "POST"])
def expense_types() -> dict:
    denied = _require_hr_role()
    if denied:
        return denied
    rows = frappe.get_list(
        "Expense Claim Type",
        fields=["name"],
        order_by="name asc",
        limit_page_length=200,
    )
    return success([row.get("name") for row in rows])


@_whitelist(["GET", "POST"])
def expense_claim_detail(name: str) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Expense Claim",
        filters=[["name", "=", name], ["employee", "=", employee["name"]]],
        fields=[
            "name",
            "status",
            "approval_status",
            "posting_date",
            "total_claimed_amount",
            "total_sanctioned_amount",
        ],
        limit_page_length=1,
    )
    if not rows:
        return failure("Expense claim not found.", code="HR_EXPENSE_NOT_FOUND")
    claim = rows[0]
    lines = frappe.get_list(
        "Expense Claim Detail",
        filters=[["parent", "=", name]],
        fields=["expense_type", "amount", "sanctioned_amount", "description"],
        limit_page_length=100,
    )
    return success({
        "name": claim.get("name"),
        "status": claim.get("status"),
        "approval_status": claim.get("approval_status"),
        "posting_date": str(claim.get("posting_date") or ""),
        "total_claimed_amount": float(claim.get("total_claimed_amount") or 0),
        "total_sanctioned_amount": float(claim.get("total_sanctioned_amount") or 0),
        "expenses": [
            {
                "expense_type": line.get("expense_type"),
                "amount": float(line.get("amount") or 0),
                "sanctioned_amount": float(line.get("sanctioned_amount") or 0),
                "description": line.get("description") or "",
            }
            for line in lines
        ],
    })


# Receipt uploads: images and PDFs only, ~5MB decoded.
ATTACHMENT_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "heic", "pdf"}
MAX_ATTACHMENT_BASE64_LENGTH = 7_000_000


def _owned_expense_claim(name: str) -> tuple[dict | None, dict | None]:
    employee, error = _employee_or_failure()
    if error:
        return None, error
    rows = frappe.get_list(
        "Expense Claim",
        filters=[["name", "=", name], ["employee", "=", employee["name"]]],
        fields=["name"],
        limit_page_length=1,
    )
    if not rows:
        return None, failure("Expense claim not found.", code="HR_EXPENSE_NOT_FOUND")
    return rows[0], None


@_whitelist(["POST"])
def upload_expense_attachment(
    claim_name: str,
    file_name: str,
    content_base64: str,
) -> dict:
    extension = (file_name or "").rsplit(".", 1)[-1].lower()
    if not file_name or "." not in file_name or extension not in ATTACHMENT_EXTENSIONS:
        return failure(
            "A receipt file name ending in jpg, jpeg, png, webp, heic, or pdf is required.",
            code="VALIDATION_REQUIRED",
        )
    if not content_base64 or len(content_base64) > MAX_ATTACHMENT_BASE64_LENGTH:
        return failure(
            "Attachment content is missing or larger than 5MB.",
            code="VALIDATION_REQUIRED",
        )
    claim, error = _owned_expense_claim(claim_name)
    if error:
        return error
    try:
        doc = frappe.get_doc({
            "doctype": "File",
            "file_name": file_name,
            "attached_to_doctype": "Expense Claim",
            "attached_to_name": claim["name"],
            "is_private": 1,
            "content": content_base64,
            "decode": True,
        })
        doc.insert(ignore_permissions=False)
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": doc.name, "file_url": doc.get("file_url") or ""})


@_whitelist(["GET", "POST"])
def expense_attachments(claim_name: str, limit: int = 20) -> dict:
    claim, error = _owned_expense_claim(claim_name)
    if error:
        return error
    rows = frappe.get_list(
        "File",
        filters=[
            ["attached_to_doctype", "=", "Expense Claim"],
            ["attached_to_name", "=", claim["name"]],
        ],
        fields=["name", "file_name", "file_url", "is_private"],
        order_by="creation desc",
        limit_page_length=max(1, min(int(limit), 50)),
    )
    return success([
        {
            "name": row.get("name"),
            "file_name": row.get("file_name") or "",
            "file_url": row.get("file_url") or "",
            "is_private": bool(row.get("is_private")),
        }
        for row in rows
    ])


@_whitelist(["GET", "POST"])
def salary_slips(limit: int = 24) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Salary Slip",
        filters=[["employee", "=", employee["name"]], ["docstatus", "=", 1]],
        fields=["name", "start_date", "end_date", "net_pay"],
        order_by="start_date desc",
        limit_page_length=max(1, min(int(limit), 60)),
    )
    return success(rows)


@_whitelist(["GET", "POST"])
def salary_slip_detail(name: str) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    rows = frappe.get_list(
        "Salary Slip",
        filters=[
            ["name", "=", name],
            ["employee", "=", employee["name"]],
            ["docstatus", "=", 1],
        ],
        fields=[
            "name",
            "start_date",
            "end_date",
            "gross_pay",
            "total_deduction",
            "net_pay",
        ],
        limit_page_length=1,
    )
    if not rows:
        return failure("Salary slip not found.", code="HR_SALARY_NOT_FOUND")
    slip = rows[0]
    components = frappe.get_list(
        "Salary Detail",
        filters=[["parent", "=", name]],
        fields=["parentfield", "salary_component", "amount"],
        limit_page_length=200,
    )

    def _by(field: str) -> list[dict]:
        return [
            {"component": row.get("salary_component"), "amount": float(row.get("amount") or 0)}
            for row in components
            if row.get("parentfield") == field
        ]

    return success({
        "name": slip.get("name"),
        "start_date": str(slip.get("start_date") or ""),
        "end_date": str(slip.get("end_date") or ""),
        "gross_pay": float(slip.get("gross_pay") or 0),
        "total_deduction": float(slip.get("total_deduction") or 0),
        "net_pay": float(slip.get("net_pay") or 0),
        "earnings": _by("earnings"),
        "deductions": _by("deductions"),
    })


def _owned_salary_slip(name: str) -> tuple[dict | None, dict | None]:
    employee, error = _employee_or_failure()
    if error:
        return None, error
    rows = frappe.get_list(
        "Salary Slip",
        filters=[
            ["name", "=", name],
            ["employee", "=", employee["name"]],
            ["docstatus", "=", 1],
        ],
        fields=["name"],
        limit_page_length=1,
    )
    if not rows:
        return None, failure("Salary slip not found.", code="HR_SALARY_NOT_FOUND")
    return rows[0], None


@_whitelist(["GET", "POST"])
def salary_slip_pdf_url(name: str, print_format: str = "Standard") -> dict:
    slip, error = _owned_salary_slip(name)
    if error:
        return error
    path = (
        "/api/method/frappe.utils.print_format.download_pdf"
        f"?doctype=Salary%20Slip&name={slip['name']}"
        f"&format={print_format or 'Standard'}&no_letterhead=0"
    )
    get_url = getattr(getattr(frappe, "utils", None), "get_url", None)
    return success({
        "name": slip["name"],
        "url": get_url(path) if callable(get_url) else path,
    })


@_whitelist(["GET", "POST"])
def notifications(limit: int = 50) -> dict:
    denied = _require_hr_role()
    if denied:
        return denied
    user = getattr(getattr(frappe, "session", None), "user", None)
    rows = frappe.get_list(
        "Notification Log",
        filters=[["for_user", "=", user]],
        fields=["name", "subject", "email_content", "read", "creation"],
        order_by="creation desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([
        {
            "name": row.get("name"),
            "title": row.get("subject") or "Notification",
            "message": row.get("email_content") or "",
            "read": bool(row.get("read")),
            "date": str(row.get("creation") or ""),
        }
        for row in rows
    ])


def _owned_notification(name: str) -> tuple[dict | None, dict | None]:
    denied = _require_hr_role()
    if denied:
        return None, denied
    user = getattr(getattr(frappe, "session", None), "user", None)
    rows = frappe.get_list(
        "Notification Log",
        filters=[["name", "=", name], ["for_user", "=", user]],
        fields=["name", "subject", "email_content", "read", "creation"],
        limit_page_length=1,
    )
    if not rows:
        return None, failure("Notification not found.", code="HR_NOTIFICATION_NOT_FOUND")
    return rows[0], None


@_whitelist(["GET", "POST"])
def notification_detail(name: str) -> dict:
    row, error = _owned_notification(name)
    if error:
        return error
    return success({
        "name": row.get("name"),
        "title": row.get("subject") or "Notification",
        "message": row.get("email_content") or "",
        "read": bool(row.get("read")),
        "date": str(row.get("creation") or ""),
    })


@_whitelist(["POST"])
def mark_notification_read(name: str) -> dict:
    row, error = _owned_notification(name)
    if error:
        return error
    try:
        frappe.db.set_value("Notification Log", name, "read", 1)
        frappe.db.commit()
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    return success({"name": name, "read": True})


# ---------------------------------------------------------------------------
# Manager and approvals
#
# Every read is scoped to the approver assigned on the ERPNext document
# (leave_approver / expense_approver), so a manager only ever sees and acts on
# requests routed to them. A record assigned to a different approver reads as
# "not found" rather than leaking its existence.
# ---------------------------------------------------------------------------


def _current_user() -> str | None:
    return getattr(getattr(frappe, "session", None), "user", None)


@_whitelist(["GET", "POST"])
def manager_pending_leaves(limit: int = 50) -> dict:
    denied = _require_manager()
    if denied:
        return denied
    rows = frappe.get_list(
        "Leave Application",
        filters=[
            ["leave_approver", "=", _current_user()],
            ["docstatus", "=", 1],
            ["status", "=", "Open"],
        ],
        fields=[
            "name",
            "employee",
            "employee_name",
            "leave_type",
            "from_date",
            "to_date",
            "total_leave_days",
        ],
        order_by="from_date asc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([
        {
            "name": row.get("name"),
            "employee": row.get("employee"),
            "employee_name": row.get("employee_name"),
            "leave_type": row.get("leave_type"),
            "from_date": str(row.get("from_date") or ""),
            "to_date": str(row.get("to_date") or ""),
            "total_leave_days": float(row.get("total_leave_days") or 0),
        }
        for row in rows
    ])


@_whitelist(["GET", "POST"])
def manager_pending_expenses(limit: int = 50) -> dict:
    denied = _require_manager()
    if denied:
        return denied
    rows = frappe.get_list(
        "Expense Claim",
        filters=[
            ["expense_approver", "=", _current_user()],
            ["approval_status", "=", "Draft"],
        ],
        fields=[
            "name",
            "employee",
            "employee_name",
            "total_claimed_amount",
            "posting_date",
        ],
        order_by="posting_date asc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([
        {
            "name": row.get("name"),
            "employee": row.get("employee"),
            "employee_name": row.get("employee_name"),
            "total_claimed_amount": float(row.get("total_claimed_amount") or 0),
            "posting_date": str(row.get("posting_date") or ""),
        }
        for row in rows
    ])


@_whitelist(["GET", "POST"])
def manager_summary() -> dict:
    denied = _require_manager()
    if denied:
        return denied
    user = _current_user()
    pending_leaves = len(frappe.get_list(
        "Leave Application",
        filters=[
            ["leave_approver", "=", user],
            ["docstatus", "=", 1],
            ["status", "=", "Open"],
        ],
        limit_page_length=0,
    ))
    pending_expenses = len(frappe.get_list(
        "Expense Claim",
        filters=[["expense_approver", "=", user], ["approval_status", "=", "Draft"]],
        limit_page_length=0,
    ))
    return success({
        "pending_leaves": pending_leaves,
        "pending_expenses": pending_expenses,
    })


@_whitelist(["GET", "POST"])
def manager_direct_reports(limit: int = 100) -> dict:
    denied = _require_manager()
    if denied:
        return denied
    manager = _current_employee()
    if not manager:
        return failure(
            "No active Employee record is linked to this user.",
            code="HR_EMPLOYEE_NOT_FOUND",
        )
    rows = frappe.get_list(
        "Employee",
        filters=[
            ["reports_to", "=", manager["name"]],
            ["status", "=", "Active"],
        ],
        fields=[
            "name",
            "employee_name",
            "department",
            "designation",
            "company_email",
            "cell_number",
        ],
        order_by="employee_name asc",
        limit_page_length=max(1, min(int(limit), 200)),
    )
    return success([
        {
            "employee": row.get("name"),
            "employee_name": row.get("employee_name") or "",
            "department": row.get("department") or "",
            "designation": row.get("designation") or "",
            "company_email": row.get("company_email") or "",
            "cell_number": row.get("cell_number") or "",
        }
        for row in rows
    ])


@_whitelist(["GET", "POST"])
def manager_team_attendance_exceptions(days: int = 7, limit: int = 100) -> dict:
    """Absent / half-day / on-leave attendance for direct reports."""
    denied = _require_manager()
    if denied:
        return denied
    manager = _current_employee()
    if not manager:
        return failure(
            "No active Employee record is linked to this user.",
            code="HR_EMPLOYEE_NOT_FOUND",
        )
    reports = frappe.get_list(
        "Employee",
        filters=[
            ["reports_to", "=", manager["name"]],
            ["status", "=", "Active"],
        ],
        fields=["name"],
        limit_page_length=200,
    )
    if not reports:
        return success([])
    window_days = max(1, min(int(days), 60))
    cutoff = (date.today() - timedelta(days=window_days)).isoformat()
    rows = frappe.get_list(
        "Attendance",
        filters=[
            ["employee", "in", [row["name"] for row in reports]],
            ["status", "in", ["Absent", "Half Day", "On Leave"]],
            ["attendance_date", ">=", cutoff],
            ["docstatus", "=", 1],
        ],
        fields=["name", "employee", "employee_name", "attendance_date", "status"],
        order_by="attendance_date desc",
        limit_page_length=max(1, min(int(limit), 200)),
    )
    return success([
        {
            "name": row.get("name"),
            "employee": row.get("employee"),
            "employee_name": row.get("employee_name") or "",
            "attendance_date": str(row.get("attendance_date") or ""),
            "status": row.get("status") or "",
        }
        for row in rows
    ])


def _assigned_approval(
    doctype: str,
    name: str,
    approver_field: str,
) -> tuple[dict | None, dict | None]:
    denied = _require_manager()
    if denied:
        return None, denied
    rows = frappe.get_list(
        doctype,
        filters=[["name", "=", name], [approver_field, "=", _current_user()]],
        fields=["name"],
        limit_page_length=1,
    )
    if not rows:
        return None, failure("Approval request not found.", code="HR_APPROVAL_NOT_FOUND")
    return rows[0], None


def _as_bool(value) -> bool:
    # Whitelisted args arrive as strings over HTTP, so "false"/"0" must be
    # treated as False rather than truthy non-empty strings.
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes"}
    return bool(value)


def _apply_decision(doc, comment: str | None) -> None:
    if comment:
        doc.add_comment("Comment", comment)
    doc.save(ignore_permissions=False)
    frappe.db.commit()


@_whitelist(["POST"])
def decide_leave(name: str, approved: bool, comment: str | None = None) -> dict:
    _, error = _assigned_approval("Leave Application", name, "leave_approver")
    if error:
        return error
    status = "Approved" if _as_bool(approved) else "Rejected"
    try:
        doc = frappe.get_doc("Leave Application", name)
        doc.status = status
        _apply_decision(doc, comment)
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": name, "status": status})


@_whitelist(["POST"])
def decide_expense(name: str, approved: bool, comment: str | None = None) -> dict:
    _, error = _assigned_approval("Expense Claim", name, "expense_approver")
    if error:
        return error
    status = "Approved" if _as_bool(approved) else "Rejected"
    try:
        doc = frappe.get_doc("Expense Claim", name)
        doc.approval_status = status
        _apply_decision(doc, comment)
    except frappe.PermissionError:
        frappe.db.rollback()
        return failure("You do not have permission for this action.", code="PERMISSION_DENIED")
    except frappe.ValidationError as exc:
        frappe.db.rollback()
        return failure(str(exc), code="VALIDATION_ERPNEXT")
    return success({"name": name, "approval_status": status})
