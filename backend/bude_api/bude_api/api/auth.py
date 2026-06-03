"""Authentication endpoints.

    POST /api/method/bude_api.api.auth.login         (guest)
    POST /api/method/bude_api.api.auth.logout        (auth required)
    GET  /api/method/bude_api.api.auth.session_info  (auth required)
"""

try:
    import frappe
except ImportError:
    frappe = None

from ..services.auth_service import AuthError, AuthService
from ..utils.response import failure, success


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["POST", "GET"])


_service = AuthService()


@_whitelist(allow_guest=True)
def login(usr: str, pwd: str) -> dict:
    try:
        session = _service.login(usr, pwd)
    except AuthError as exc:
        return failure(str(exc), code="AUTH_INVALID_CREDENTIALS")
    return success(session)


@_whitelist(allow_guest=False)
def logout() -> dict:
    _service.logout()
    return success(message="Logged out.")


@_whitelist(allow_guest=False)
def session_info() -> dict:
    user = _service.current_user()
    if user is None:
        return failure("No active session.", code="AUTH_NO_SESSION")

    full_name = None
    if frappe is not None:
        full_name = frappe.db.get_value("User", user, "full_name")

    return success({"user": user, "full_name": full_name})
