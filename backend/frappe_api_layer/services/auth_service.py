"""Authentication service — wraps Frappe's built-in login/session APIs.

Phase 1: contracts only. Implementations land in Phase 2.
"""

from typing import Optional

try:
    import frappe
except ImportError:
    frappe = None


class AuthService:
    def login(self, username: str, password: str) -> dict:
        """Authenticate against Frappe and return a session dict.

        Returns: { "user": str, "full_name": str, "api_key": str, "api_secret": str }
        """
        raise NotImplementedError("Phase 1 skeleton — implement in Phase 2.")

    def logout(self) -> None:
        raise NotImplementedError("Phase 1 skeleton — implement in Phase 2.")

    def current_user(self) -> Optional[str]:
        if frappe is None:
            return None
        user = getattr(frappe.session, "user", None)
        if user in (None, "Guest"):
            return None
        return user
