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
def test_profile_scoped_to_current_employee(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]

    hr_api.profile()

    # The detail fetch must be filtered to the signed-in employee's record.
    _, kwargs = mock_frappe.get_list.call_args
    assert ["name", "=", "EMP-001"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_salary_slips_scoped_to_current_employee(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"name": "SAL-001", "start_date": "2026-06-01",
          "end_date": "2026-06-30", "net_pay": 1000}],
    ]

    hr_api.salary_slips()

    _, kwargs = mock_frappe.get_list.call_args
    assert ["employee", "=", "EMP-001"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_employee_documents_scoped_to_current_employee(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{
            "name": "FILE-001",
            "file_name": "contract.pdf",
            "file_url": "/private/files/contract.pdf",
            "is_private": 1,
        }],
    ]

    result = hr_api.employee_documents()

    assert result["ok"] is True
    assert result["data"][0]["file_name"] == "contract.pdf"
    assert result["data"][0]["is_private"] is True
    # Documents must be scoped to the signed-in employee's record.
    _, kwargs = mock_frappe.get_list.call_args
    assert ["attached_to_name", "=", "EMP-001"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_attendance_status_uses_latest_checkin(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"name": "CHK-001", "time": "2026-07-01 09:00:00", "log_type": "IN"}],
        [{"time": "2026-07-01 09:00:00"}],
        [{"time": "2026-06-30 18:00:00"}],
    ]

    result = hr_api.attendance_status()

    assert result["ok"] is True
    assert result["data"]["checked_in"] is True
    assert result["data"]["last_check_in"] == "2026-07-01 09:00:00"
    assert result["data"]["last_check_out"] == "2026-06-30 18:00:00"


@patch("bude_api.api.hr.frappe")
def test_attendance_history_returns_employee_checkins(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [
            {"name": "CHK-002", "time": "2026-07-01 17:00:00", "log_type": "OUT"},
            {"name": "CHK-001", "time": "2026-07-01 09:00:00", "log_type": "IN"},
        ],
    ]

    result = hr_api.attendance_history(limit=2)

    assert result["ok"] is True
    assert result["data"][0]["name"] == "CHK-002"
    assert result["data"][0]["log_type"] == "OUT"


@patch("bude_api.api.hr.frappe")
def test_check_in_inserts_employee_checkin_with_permissions(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]
    mock_frappe.utils.now_datetime.return_value = "2026-07-01 09:00:00"
    doc = MagicMock()
    doc.name = "CHK-001"
    mock_frappe.get_doc.return_value = doc

    result = hr_api.check_in("IN", latitude=25.2048, longitude=55.2708)

    assert result["ok"] is True
    assert result["data"]["log_type"] == "IN"
    payload = mock_frappe.get_doc.call_args.args[0]
    assert payload["latitude"] == 25.2048
    assert payload["longitude"] == 55.2708
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
        half_day=True,
        half_day_date="2026-07-10",
    )

    assert result["ok"] is True
    payload = mock_frappe.get_doc.call_args.args[0]
    assert payload["half_day"] == 1
    assert payload["half_day_date"] == "2026-07-10"
    doc.insert.assert_called_once_with(ignore_permissions=False)
    mock_frappe.db.commit.assert_called_once()


def _leave_application(**overrides):
    row = {
        "name": "LV-001",
        "leave_type": "Annual Leave",
        "from_date": "2026-07-10",
        "to_date": "2026-07-11",
        "status": "Open",
        "total_leave_days": 2,
        "description": "Trip",
        "docstatus": 1,
    }
    row.update(overrides)
    return row


@patch("bude_api.api.hr.frappe")
def test_leave_requests_lists_employee_applications(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [_leave_application()],
    ]

    result = hr_api.leave_requests()

    assert result["ok"] is True
    assert result["data"][0]["name"] == "LV-001"
    assert result["data"][0]["cancellable"] is True


@patch("bude_api.api.hr.frappe")
def test_leave_request_detail_returns_owned_application(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [_leave_application()],
    ]

    result = hr_api.leave_request_detail("LV-001")

    assert result["ok"] is True
    assert result["data"]["leave_type"] == "Annual Leave"


@patch("bude_api.api.hr.frappe")
def test_leave_request_detail_hides_foreign_application(mock_frappe):
    _wire(mock_frappe)
    # Second get_list (name + employee filter) returns nothing → not owned.
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [],
    ]

    result = hr_api.leave_request_detail("LV-999")

    assert result["ok"] is False
    assert result["code"] == "HR_LEAVE_NOT_FOUND"


@patch("bude_api.api.hr.frappe")
def test_cancel_leave_cancels_submitted_application(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [_leave_application()],
    ]
    doc = MagicMock()
    mock_frappe.get_doc.return_value = doc

    result = hr_api.cancel_leave("LV-001")

    assert result["ok"] is True
    assert result["data"]["status"] == "Cancelled"
    doc.cancel.assert_called_once()
    mock_frappe.db.commit.assert_called_once()


@patch("bude_api.api.hr.frappe")
def test_cancel_leave_rejects_non_cancellable_application(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [_leave_application(docstatus=0, status="Open")],
    ]

    result = hr_api.cancel_leave("LV-001")

    assert result["ok"] is False
    assert result["code"] == "HR_LEAVE_NOT_CANCELLABLE"
    mock_frappe.get_doc.assert_not_called()


@patch("bude_api.api.hr.frappe")
def test_expense_types_lists_claim_types(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [{"name": "Travel"}, {"name": "Food"}]

    result = hr_api.expense_types()

    assert result["ok"] is True
    assert result["data"] == ["Travel", "Food"]


@patch("bude_api.api.hr.frappe")
def test_expense_claim_detail_returns_owned_claim_with_lines(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{
            "name": "EXP-001",
            "status": "Draft",
            "approval_status": "Draft",
            "posting_date": "2026-07-01",
            "total_claimed_amount": 100,
            "total_sanctioned_amount": 0,
        }],
        [{
            "expense_type": "Travel",
            "amount": 100,
            "sanctioned_amount": 0,
            "description": "Taxi",
        }],
    ]

    result = hr_api.expense_claim_detail("EXP-001")

    assert result["ok"] is True
    assert result["data"]["name"] == "EXP-001"
    assert result["data"]["expenses"][0]["expense_type"] == "Travel"


@patch("bude_api.api.hr.frappe")
def test_expense_claim_detail_hides_foreign_claim(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [],
    ]

    result = hr_api.expense_claim_detail("EXP-999")

    assert result["ok"] is False
    assert result["code"] == "HR_EXPENSE_NOT_FOUND"


@patch("bude_api.api.hr.frappe")
def test_submit_expense_claim_sets_optional_posting_date(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [_employee()]
    doc = MagicMock()
    doc.name = "EXP-001"
    doc.get.return_value = "Draft"
    mock_frappe.get_doc.return_value = doc

    result = hr_api.submit_expense_claim(
        expense_type="Travel",
        amount=100,
        posting_date="2026-07-02",
    )

    assert result["ok"] is True
    payload = mock_frappe.get_doc.call_args.args[0]
    assert payload["posting_date"] == "2026-07-02"
    doc.insert.assert_called_once_with(ignore_permissions=False)


@patch("bude_api.api.hr.frappe")
def test_salary_slips_returns_success_envelope(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{
            "name": "SAL-001",
            "start_date": "2026-06-01",
            "end_date": "2026-06-30",
            "net_pay": 1000,
        }],
    ]

    result = hr_api.salary_slips()

    assert result["ok"] is True
    assert result["data"][0]["name"] == "SAL-001"


@patch("bude_api.api.hr.frappe")
def test_salary_slip_detail_returns_owned_slip_with_components(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{
            "name": "SAL-001",
            "start_date": "2026-06-01",
            "end_date": "2026-06-30",
            "gross_pay": 1200,
            "total_deduction": 200,
            "net_pay": 1000,
        }],
        [
            {"parentfield": "earnings", "salary_component": "Basic", "amount": 1200},
            {"parentfield": "deductions", "salary_component": "Tax", "amount": 200},
        ],
    ]

    result = hr_api.salary_slip_detail("SAL-001")

    assert result["ok"] is True
    assert result["data"]["net_pay"] == 1000.0
    assert result["data"]["earnings"][0]["component"] == "Basic"
    assert result["data"]["deductions"][0]["component"] == "Tax"


@patch("bude_api.api.hr.frappe")
def test_salary_slip_detail_hides_foreign_slip(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [[_employee()], []]

    result = hr_api.salary_slip_detail("SAL-999")

    assert result["ok"] is False
    assert result["code"] == "HR_SALARY_NOT_FOUND"


@patch("bude_api.api.hr.frappe")
def test_salary_slip_pdf_url_returns_owned_print_url(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{"name": "SAL-001"}],
    ]
    mock_frappe.utils.get_url.side_effect = lambda path: f"https://erp.test{path}"

    result = hr_api.salary_slip_pdf_url("SAL-001")

    assert result["ok"] is True
    assert result["data"]["name"] == "SAL-001"
    assert "download_pdf" in result["data"]["url"]
    assert "Salary%20Slip" in result["data"]["url"]


@patch("bude_api.api.hr.frappe")
def test_salary_slip_pdf_url_hides_foreign_slip(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.side_effect = [[_employee()], []]

    result = hr_api.salary_slip_pdf_url("SAL-999")

    assert result["ok"] is False
    assert result["code"] == "HR_SALARY_NOT_FOUND"


@patch("bude_api.api.hr.frappe")
def test_manager_direct_reports_returns_active_reports(mock_frappe):
    _wire(mock_frappe, roles=["HR Manager"])
    mock_frappe.get_list.side_effect = [
        [_employee()],
        [{
            "name": "EMP-002",
            "employee_name": "Bob Employee",
            "department": "Operations",
            "designation": "Technician",
            "company_email": "bob@bude.example",
            "cell_number": "+971500000001",
        }],
    ]

    result = hr_api.manager_direct_reports()

    assert result["ok"] is True
    assert result["data"][0]["employee"] == "EMP-002"
    assert result["data"][0]["employee_name"] == "Bob Employee"
    _, kwargs = mock_frappe.get_list.call_args
    assert ["reports_to", "=", "EMP-001"] in kwargs["filters"]
    assert ["status", "=", "Active"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_notifications_lists_only_current_user_logs(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [{
        "name": "NOTIF-001",
        "subject": "Policy update",
        "email_content": "Read the new policy.",
        "read": 0,
        "creation": "2026-07-01",
    }]

    result = hr_api.notifications()

    assert result["ok"] is True
    assert result["data"][0]["title"] == "Policy update"
    assert result["data"][0]["read"] is False
    # Notifications must be scoped to the signed-in user.
    _, kwargs = mock_frappe.get_list.call_args
    assert ["for_user", "=", "employee@example.com"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_mark_notification_read_sets_read_flag(mock_frappe):
    _wire(mock_frappe)
    mock_frappe.get_list.return_value = [{
        "name": "NOTIF-001",
        "subject": "Policy update",
        "email_content": "Read it.",
        "read": 0,
        "creation": "2026-07-01",
    }]

    result = hr_api.mark_notification_read("NOTIF-001")

    assert result["ok"] is True
    assert result["data"]["read"] is True
    mock_frappe.db.set_value.assert_called_once_with(
        "Notification Log", "NOTIF-001", "read", 1
    )


# Every HR endpoint plus the args needed to reach its permission guard.
_HR_ENDPOINTS = [
    ("profile", (), {}),
    ("employee_documents", (), {}),
    ("attendance_status", (), {}),
    ("attendance_history", (), {}),
    ("check_in", ("IN",), {}),
    ("leave_balances", (), {}),
    ("apply_leave", ("Annual Leave", "2026-07-10", "2026-07-11"), {}),
    ("leave_requests", (), {}),
    ("leave_request_detail", ("LV-001",), {}),
    ("cancel_leave", ("LV-001",), {}),
    ("expense_claims", (), {}),
    ("expense_types", (), {}),
    ("expense_claim_detail", ("EXP-001",), {}),
    ("submit_expense_claim", ("Travel", 10), {}),
    ("salary_slips", (), {}),
    ("salary_slip_detail", ("SAL-001",), {}),
    ("salary_slip_pdf_url", ("SAL-001",), {}),
    ("notifications", (), {}),
    ("notification_detail", ("NOTIF-001",), {}),
    ("mark_notification_read", ("NOTIF-001",), {}),
    ("manager_pending_leaves", (), {}),
    ("manager_pending_expenses", (), {}),
    ("manager_summary", (), {}),
    ("manager_direct_reports", (), {}),
    ("decide_leave", ("LV-001", True), {}),
    ("decide_expense", ("EXP-001", True), {}),
]


def test_every_hr_endpoint_denies_non_hr_role():
    for name, args, kwargs in _HR_ENDPOINTS:
        with patch("bude_api.api.hr.frappe") as mock_frappe:
            _wire(mock_frappe, roles=["Stock User"])

            result = getattr(hr_api, name)(*args, **kwargs)

            assert result["ok"] is False, f"{name} should deny non-HR roles"
            assert result["code"] == "PERMISSION_DENIED", f"{name} wrong code"
            # No data access should happen once permission is denied.
            mock_frappe.get_list.assert_not_called()
            mock_frappe.get_doc.assert_not_called()


_MANAGER_ENDPOINTS = [
    ("manager_pending_leaves", (), {}),
    ("manager_pending_expenses", (), {}),
    ("manager_summary", (), {}),
    ("decide_leave", ("LV-001", True), {}),
    ("decide_expense", ("EXP-001", True), {}),
]


def test_manager_endpoints_deny_plain_employee():
    for name, args, kwargs in _MANAGER_ENDPOINTS:
        with patch("bude_api.api.hr.frappe") as mock_frappe:
            _wire(mock_frappe, roles=["Employee"])

            result = getattr(hr_api, name)(*args, **kwargs)

            assert result["ok"] is False, f"{name} should deny plain employees"
            assert result["code"] == "PERMISSION_DENIED", f"{name} wrong code"
            mock_frappe.get_list.assert_not_called()
            mock_frappe.get_doc.assert_not_called()


@patch("bude_api.api.hr.frappe")
def test_manager_pending_leaves_scoped_to_approver(mock_frappe):
    _wire(mock_frappe, roles=["HR Manager"])
    mock_frappe.session.user = "manager@example.com"
    mock_frappe.get_list.return_value = [{
        "name": "LV-001",
        "employee": "EMP-002",
        "employee_name": "Bob",
        "leave_type": "Annual Leave",
        "from_date": "2026-07-10",
        "to_date": "2026-07-11",
        "total_leave_days": 2,
    }]

    result = hr_api.manager_pending_leaves()

    assert result["ok"] is True
    assert result["data"][0]["employee_name"] == "Bob"
    _, kwargs = mock_frappe.get_list.call_args
    assert ["leave_approver", "=", "manager@example.com"] in kwargs["filters"]


@patch("bude_api.api.hr.frappe")
def test_decide_leave_approves_assigned_request(mock_frappe):
    _wire(mock_frappe, roles=["HR Manager"])
    mock_frappe.session.user = "manager@example.com"
    mock_frappe.get_list.return_value = [{"name": "LV-001"}]
    doc = MagicMock()
    mock_frappe.get_doc.return_value = doc

    result = hr_api.decide_leave("LV-001", approved=True, comment="Looks fine")

    assert result["ok"] is True
    assert result["data"]["status"] == "Approved"
    assert doc.status == "Approved"
    doc.add_comment.assert_called_once_with("Comment", "Looks fine")
    doc.save.assert_called_once_with(ignore_permissions=False)


@patch("bude_api.api.hr.frappe")
def test_decide_leave_treats_string_false_as_rejection(mock_frappe):
    _wire(mock_frappe, roles=["HR Manager"])
    mock_frappe.get_list.return_value = [{"name": "LV-001"}]
    doc = MagicMock()
    mock_frappe.get_doc.return_value = doc

    # HTTP delivers booleans as strings; "false" must reject, not approve.
    result = hr_api.decide_leave("LV-001", approved="false")

    assert result["ok"] is True
    assert result["data"]["status"] == "Rejected"
    assert doc.status == "Rejected"


@patch("bude_api.api.hr.frappe")
def test_decide_expense_hides_unassigned_claim(mock_frappe):
    _wire(mock_frappe, roles=["HR Manager"])
    mock_frappe.get_list.return_value = []

    result = hr_api.decide_expense("EXP-999", approved=True)

    assert result["ok"] is False
    assert result["code"] == "HR_APPROVAL_NOT_FOUND"
    mock_frappe.get_doc.assert_not_called()
