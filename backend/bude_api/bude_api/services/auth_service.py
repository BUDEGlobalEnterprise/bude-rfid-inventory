"""Authentication service — wraps Frappe's built-in login/session APIs.

Returns API key/secret pairs so the mobile client can authenticate subsequent
requests via `Authorization: token <key>:<secret>` without storing passwords.
"""

from typing import Optional

try:
    import frappe
    from frappe.utils.password import update_password
except ImportError:
    frappe = None
    update_password = None


class AuthError(Exception):
    pass


class AuthService:
    def login(self, username: str, password: str) -> dict:
        """Authenticate against Frappe and return a session dict.

        Returns: {
            "user": str,
            "full_name": str,
            "api_key": str,
            "api_secret": str,
            "roles": list[str],
            "default_warehouse": str,
        }
        """
        if frappe is None:
            raise RuntimeError("Frappe is not available — run inside a Frappe bench.")

        login_manager = frappe.auth.LoginManager()
        try:
            login_manager.authenticate(user=username, pwd=password)
            login_manager.post_login()
        except frappe.AuthenticationError as exc:
            raise AuthError("Invalid username or password.") from exc

        user_name = frappe.session.user
        user_doc = frappe.get_doc("User", user_name)

        api_key, api_secret = self._ensure_api_keys(user_doc)

        return {
            "user": user_name,
            "full_name": user_doc.full_name,
            "api_key": api_key,
            "api_secret": api_secret,
            "roles": frappe.get_roles(user_name),
            "default_warehouse": (
                frappe.db.get_value("User", user_name, "default_warehouse")
                or ""
            ),
        }

    def logout(self) -> None:
        if frappe is None:
            raise RuntimeError("Frappe is not available — run inside a Frappe bench.")
        frappe.local.login_manager.logout()
        frappe.db.commit()

    def current_user(self) -> Optional[str]:
        if frappe is None:
            return None
        user = getattr(frappe.session, "user", None)
        if user in (None, "Guest"):
            return None
        return user

    def _ensure_api_keys(self, user_doc) -> tuple[str, str]:
        api_key = user_doc.api_key
        api_secret = user_doc.get_password("api_secret", raise_exception=False) if api_key else None

        if not api_key or not api_secret:
            if not api_key:
                api_key = frappe.generate_hash(length=15)
                user_doc.api_key = api_key
            api_secret = frappe.generate_hash(length=15)
            user_doc.api_secret = api_secret
            user_doc.save(ignore_permissions=True)
            frappe.db.commit()

        return api_key, api_secret
