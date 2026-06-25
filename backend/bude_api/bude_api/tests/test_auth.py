from unittest.mock import MagicMock, patch

import pytest

from bude_api.api import auth as auth_api
from bude_api.services.auth_service import AuthError, AuthService


@patch("bude_api.services.auth_service.frappe")
def test_login_returns_session_dict_with_api_keys(mock_frappe):
    login_manager = MagicMock()
    mock_frappe.auth.LoginManager.return_value = login_manager
    mock_frappe.session.user = "alice@example.com"

    user_doc = MagicMock()
    user_doc.api_key = "existing_key"
    user_doc.get_password.return_value = "existing_secret"
    user_doc.full_name = "Alice Example"
    mock_frappe.get_doc.return_value = user_doc
    mock_frappe.get_roles.return_value = ["Stock Manager", "System Manager"]
    mock_frappe.db.get_value.return_value = "Stores - A"

    result = AuthService().login("alice@example.com", "hunter2")

    login_manager.authenticate.assert_called_once_with(user="alice@example.com", pwd="hunter2")
    login_manager.post_login.assert_called_once()
    assert result == {
        "user": "alice@example.com",
        "full_name": "Alice Example",
        "api_key": "existing_key",
        "api_secret": "existing_secret",
        "roles": ["Stock Manager", "System Manager"],
        "default_warehouse": "Stores - A",
    }


@patch("bude_api.services.auth_service.frappe")
def test_login_generates_keys_when_missing(mock_frappe):
    login_manager = MagicMock()
    mock_frappe.auth.LoginManager.return_value = login_manager
    mock_frappe.session.user = "bob@example.com"
    mock_frappe.generate_hash.side_effect = ["new_key", "new_secret"]

    user_doc = MagicMock()
    user_doc.api_key = None
    user_doc.get_password.return_value = None
    user_doc.full_name = "Bob Example"
    mock_frappe.get_doc.return_value = user_doc
    mock_frappe.get_roles.return_value = ["Stock User"]
    mock_frappe.db.get_value.return_value = ""

    result = AuthService().login("bob@example.com", "hunter2")

    assert result["api_key"] == "new_key"
    assert result["api_secret"] == "new_secret"
    user_doc.save.assert_called_once_with(ignore_permissions=True)


@patch("bude_api.services.auth_service.frappe")
def test_login_raises_auth_error_on_invalid_credentials(mock_frappe):
    class _AuthError(Exception):
        pass

    mock_frappe.AuthenticationError = _AuthError
    login_manager = MagicMock()
    login_manager.authenticate.side_effect = _AuthError("bad creds")
    mock_frappe.auth.LoginManager.return_value = login_manager

    with pytest.raises(AuthError):
        AuthService().login("nobody", "wrong")


@patch.object(auth_api, "_service")
def test_login_endpoint_returns_failure_envelope_on_auth_error(mock_service):
    mock_service.login.side_effect = AuthError("Invalid username or password.")
    result = auth_api.login("u", "p")
    assert result["ok"] is False
    assert result["code"] == "AUTH_INVALID_CREDENTIALS"


@patch.object(auth_api, "_service")
def test_login_endpoint_returns_success_envelope(mock_service):
    mock_service.login.return_value = {"user": "u", "full_name": "U", "api_key": "k", "api_secret": "s"}
    result = auth_api.login("u", "p")
    assert result["ok"] is True
    assert result["data"]["user"] == "u"


@patch.object(auth_api, "_service")
def test_session_info_returns_failure_when_no_user(mock_service):
    mock_service.current_user.return_value = None
    result = auth_api.session_info()
    assert result["ok"] is False
    assert result["code"] == "AUTH_NO_SESSION"


@patch.object(auth_api, "_service")
@patch("bude_api.api.auth.frappe")
def test_session_info_includes_roles(mock_frappe, mock_service):
    mock_service.current_user.return_value = "alice@example.com"
    mock_frappe.db.get_value.return_value = "Alice"
    mock_frappe.get_roles.return_value = ["Stock Manager", "All"]
    mock_frappe.db.get_value.side_effect = lambda *a, **kw: (
        "Alice" if a[2] == "full_name" else ""
    )

    result = auth_api.session_info()

    assert result["ok"] is True
    assert "Stock Manager" in result["data"]["roles"]


@patch.object(auth_api, "_service")
@patch("bude_api.api.auth.frappe")
def test_session_info_includes_default_warehouse(mock_frappe, mock_service):
    mock_service.current_user.return_value = "alice@example.com"
    mock_frappe.get_roles.return_value = ["All"]
    mock_frappe.db.get_value.side_effect = lambda *a, **kw: (
        "Alice" if a[2] == "full_name" else "Stores - A"
    )

    result = auth_api.session_info()

    assert result["ok"] is True
    assert result["data"]["default_warehouse"] == "Stores - A"
