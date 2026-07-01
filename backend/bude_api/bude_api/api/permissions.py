"""Permission helpers shared by mobile API endpoints."""

from ..utils.response import failure

STOCK_EXECUTION_ROLES = {"Stock User", "Stock Manager", "System Manager"}


def permission_denied(
    message: str = "You do not have permission for this action.",
) -> dict:
    return failure(message, code="PERMISSION_DENIED")


def has_any_role(frappe_module, allowed_roles: set[str]) -> bool:
    if frappe_module is None:
        return False
    if _session_user(frappe_module) == "Administrator":
        return True
    return bool(_current_roles(frappe_module).intersection(allowed_roles))


def require_any_role(
    frappe_module,
    allowed_roles: set[str],
    message: str = "You do not have permission for this action.",
) -> dict | None:
    if has_any_role(frappe_module, allowed_roles):
        return None
    return permission_denied(message)


def require_stock_execution_role(frappe_module) -> dict | None:
    return require_any_role(
        frappe_module,
        STOCK_EXECUTION_ROLES,
        "A stock role is required for this action.",
    )


def _session_user(frappe_module) -> str | None:
    try:
        return getattr(getattr(frappe_module, "session", None), "user", None)
    except Exception:
        return None


def _current_roles(frappe_module) -> set[str]:
    try:
        roles = frappe_module.get_roles()
    except Exception:
        return set()
    if not roles:
        return set()
    return {str(role) for role in roles}
