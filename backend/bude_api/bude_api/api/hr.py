"""Employee self-service endpoints for the Bude HR Flutter app.

All persistence uses standard ERPNext/HRMS DocTypes. These endpoints are a
clean-room implementation inspired by common ESS flows, not copied from the
reference HR apps in the repository.
"""

try:
    import frappe
except ImportError:
    frappe = None

from ..utils.response import failure, success

HR_ROLES = {"Employee", "HR User", "HR Manager", "System Manager"}


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
    return success(employee)


@_whitelist(["GET", "POST"])
def attendance_status() -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    logs = frappe.get_list(
        "Employee Checkin",
        filters=[["employee", "=", employee["name"]]],
        fields=["name", "time", "log_type"],
        order_by="time desc",
        limit_page_length=1,
    )
    last = logs[0] if logs else {}
    return success({
        "checked_in": last.get("log_type") == "IN",
        "last_check_in": str(last.get("time") or "") if last.get("log_type") == "IN" else None,
        "last_check_out": str(last.get("time") or "") if last.get("log_type") == "OUT" else None,
    })


@_whitelist(["POST"])
def check_in(type: str = "IN") -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    log_type = str(type or "").upper()
    if log_type not in {"IN", "OUT"}:
        return failure("type must be IN or OUT.", code="VALIDATION_BAD_TYPE")
    try:
        doc = frappe.get_doc({
            "doctype": "Employee Checkin",
            "employee": employee["name"],
            "log_type": log_type,
            "time": frappe.utils.now_datetime(),
        })
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
) -> dict:
    employee, error = _employee_or_failure()
    if error:
        return error
    if not leave_type or not from_date or not to_date:
        return failure("leave_type, from_date, and to_date are required.", code="VALIDATION_REQUIRED")
    try:
        doc = frappe.get_doc({
            "doctype": "Leave Application",
            "employee": employee["name"],
            "company": employee.get("company"),
            "leave_type": leave_type,
            "from_date": from_date,
            "to_date": to_date,
            "description": reason,
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
def submit_expense_claim(expense_type: str, amount: float, description: str | None = None) -> dict:
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
def notifications(limit: int = 50) -> dict:
    denied = _require_hr_role()
    if denied:
        return denied
    rows = frappe.get_list(
        "Notification Log",
        fields=["subject", "email_content", "creation"],
        order_by="creation desc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    return success([
        {
            "title": row.get("subject") or "Notification",
            "message": row.get("email_content") or "",
            "date": str(row.get("creation") or ""),
        }
        for row in rows
    ])
