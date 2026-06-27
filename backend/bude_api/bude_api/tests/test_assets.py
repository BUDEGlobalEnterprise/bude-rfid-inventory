from unittest.mock import MagicMock, patch

from bude_api.api import assets as assets_api


class _FakeValidationError(Exception):
    pass


class _FakePermissionError(Exception):
    pass


def _wire_exceptions(mock_frappe):
    mock_frappe.ValidationError = _FakeValidationError
    mock_frappe.PermissionError = _FakePermissionError


@patch("bude_api.api.assets.frappe")
def test_set_epc_saves_with_permissions(mock_frappe):
    _wire_exceptions(mock_frappe)
    mock_frappe.db.exists.return_value = True
    mock_frappe.get_list.return_value = []
    doc = MagicMock()
    mock_frappe.get_doc.return_value = doc

    result = assets_api.set_epc("Asset", "AST-001", "EPC-001")

    assert result["ok"] is True
    mock_frappe.get_doc.assert_called_once_with("Asset", "AST-001")
    doc.set.assert_called_once_with("bude_epc", "EPC-001")
    doc.save.assert_called_once_with(ignore_permissions=False)
    mock_frappe.db.set_value.assert_not_called()


@patch("bude_api.api.assets.frappe")
def test_set_epc_permission_error_returns_clean_envelope(mock_frappe):
    _wire_exceptions(mock_frappe)
    mock_frappe.db.exists.return_value = True
    mock_frappe.get_list.return_value = []
    doc = MagicMock()
    doc.save.side_effect = _FakePermissionError("no write")
    mock_frappe.get_doc.return_value = doc

    result = assets_api.set_epc("Asset", "AST-001", "EPC-001")

    assert result["ok"] is False
    assert result["code"] == "PERMISSION_DENIED"
    mock_frappe.db.rollback.assert_called_once()


@patch("bude_api.api.assets.frappe")
def test_create_asset_movement_inserts_with_permissions(mock_frappe):
    _wire_exceptions(mock_frappe)
    mock_frappe.db.get_value.return_value = {
        "location": "Stores",
        "custodian": None,
        "company": "Bude",
    }
    mock_frappe.utils.now_datetime.return_value = "2026-06-26"
    doc = MagicMock()
    doc.name = "MOV-001"
    doc.docstatus = 1
    mock_frappe.get_doc.return_value = doc

    result = assets_api.create_asset_movement(
        assets=["AST-001"],
        purpose="Transfer",
        target_location="Floor",
    )

    assert result["ok"] is True
    doc.insert.assert_called_once_with(ignore_permissions=False)
    doc.submit.assert_called_once()


@patch("bude_api.api.assets.frappe")
def test_create_asset_repair_validation_error_returns_clean_envelope(mock_frappe):
    _wire_exceptions(mock_frappe)
    mock_frappe.db.exists.return_value = True
    mock_frappe.utils.now_datetime.return_value = "2026-06-26"
    doc = MagicMock()
    doc.insert.side_effect = _FakeValidationError("Bad repair")
    mock_frappe.get_doc.return_value = doc

    result = assets_api.create_asset_repair(asset="AST-001")

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_ERPNEXT"
    mock_frappe.db.rollback.assert_called_once()


@patch("bude_api.api.assets.frappe")
def test_complete_maintenance_log_saves_with_permissions(mock_frappe):
    _wire_exceptions(mock_frappe)
    mock_frappe.db.exists.return_value = True
    mock_frappe.utils.nowdate.return_value = "2026-06-26"
    doc = MagicMock()
    doc.name = "LOG-001"
    mock_frappe.get_doc.return_value = doc

    result = assets_api.complete_maintenance_log("LOG-001")

    assert result["ok"] is True
    assert doc.maintenance_status == "Completed"
    assert doc.completion_date == "2026-06-26"
    doc.save.assert_called_once_with(ignore_permissions=False)
