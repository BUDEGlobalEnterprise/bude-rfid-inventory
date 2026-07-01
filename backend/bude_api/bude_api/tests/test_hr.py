from unittest.mock import MagicMock, patch

from bude_api.api import hr as hr_api


class _FakePermissionError(Exception):
    pass


class _FakeValidationError(Exception):
    pass


def _wire(mock_frappe, roles=None):
    mock_frappe.PermissionError = _FakePermissionError
    mock_frappe.ValidationError = _FakeValidationError
    mock_frappe.session.user = "employee@example.com"
    mock_frappe.get_roles.return_value = roles or ["Employee"]


def _employee():
    return {
        "name": "EMP-001",
        "employee_name": "Alice Employee",
        "company": "Bude",
        "department": "Operations",
        "designation": "Associate",
        "user_id": "employee@example.com",
    }


@patch("bude_api.api.hr.frappe")
def test_profile_requires_hr_role(mock_frappe):
    _wire(mock_frappe, roles=["Stock User"])

    result = hr_api.profile()

    assert result["ok"] is False
    assert result["code"] == "PERMISSION_DENIED"
    mock_frappe.get_list.assert_not_called()


@patch("bude_api.api.hr.frappe")
def test_profile_returns_linked_employee(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]

    result = hr_api.profile()

    assert result["ok"] is True
    assert result["data"]["name"] == "EMP-001"


@patch("bude_api.api.hr.frappe")
def test_attendance_status_uses_latest_checkin(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"name": "CHK-001", "time": "2026-07-01 09:00:00", "log_type": "IN"}],
    ]

    result = hr_api.attendance_status()

    assert result["ok"] is True
    assert result["data"]["checked_in"] is True
    assert result["data"]["last_check_in"] == "2026-07-01 09:00:00"


@patch("bude_api.api.hr.frappe")
def test_check_in_inserts_employee_checkin_with_permissions(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]
    mock_frappe.utils.now_datetime.return_value = "2026-07-01 09:00:00"
    doc = MagicMock()
    doc.name = "CHK-001"
    mock_frappe.get_doc.return_value = doc

    result = hr_api.check_in("IN")

    assert result["ok"] is True
    assert result["data"]["log_type"] == "IN"
    doc.insert.assert_called_once_with(ignore_permissions=False)
    mock_frappe.db.commit.assert_called_once()


def test_check_in_rejects_unknown_type():
    with patch("bude_api.api.hr.frappe") as mock_frappe:
        _wire(mock_frappe)
        mock_frappe.get_list.return_value = [_employee()]

        result = hr_api.check_in("BREAK")

    assert result["ok"] is False
    assert result["code"] == "VALIDATION_BAD_TYPE"


@patch("bude_api.api.hr.frappe")
def test_leave_balances_merges_allocations_and_used_days(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"leave_type": "Annual Leave", "total_leaves_allocated": 20}],
        [{"leave_type": "Annual Leave", "total_leave_days": 3}],
    ]

    result = hr_api.leave_balances()

    assert result["ok"] is True
    assert result["data"] == [{
        "leave_type": "Annual Leave",
        "allocated": 20.0,
        "used": 3.0,
        "available": 17.0,
    }]


@patch("bude_api.api.hr.frappe")
def test_apply_leave_inserts_leave_application(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]
    doc = MagicMock()
    doc.name = "LV-001"
    doc.get.return_value = "Open"
    mock_frappe.get_doc.return_value = doc

    result = hr_api.apply_leave(
        leave_type="Annual Leave",
        from_date="2026-07-10",
        to_date="2026-07-11",
    )

    assert result["ok"] is True
    doc.insert.assert_called_once_with(ignore_permissions=False)
    mock_frappe.db.commit.assert_called_once()


@patch("bude_api.api.hr.frappe")
def test_salary_slips_returns_success_envelope(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"name": "SAL-001", "start_date": "2026-06-01", "end_date": "2026-06-30", "net_pay": 1000}],
    ]

    result = hr_api.salary_slips()

    assert result["ok"] is True
    assert result["data"][0]["name"] == "SAL-001"


@patch("bude_api.api.hr.frappe")
def test_notifications_maps_notification_log(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [{
        "subject": "Policy update",
        "email_content": "Read the new policy.",
        "creation": "2026-07-01",
    }]

    result = hr_api.notifications()

    assert result["ok"] is True
    assert result["data"][0]["title"] == "Policy update"
