"""Branding aggregator endpoint.

    GET /api/method/bude_api.api.branding.get   (auth required)

Returns a single payload that the mobile client uses to render the customer's
company identity (name, logo, address) plus version info for the connection-
info screen. Reads only standard ERPNext DocTypes (Company, Address) plus
the Frappe version helper — no custom DocTypes.
"""

from typing import Optional

try:
    import frappe
    from frappe.utils.change_log import get_versions
except ImportError:
    frappe = None
    get_versions = None

from .. import __version__
from ..utils.response import success


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest, methods=["GET"])


@_whitelist()
def get() -> dict:
    if frappe is None:
        return success({
            "company_name": None,
            "company_logo": None,
            "company_address": None,
            "erpnext_version": None,
            "bude_api_version": __version__,
        })

    company_name = _resolve_company_name()
    company = _load_company(company_name) if company_name else None

    return success({
        "company_name": company_name,
        "company_logo": (company.get("company_logo") if company else None),
        "company_address": _resolve_address(company),
        "erpnext_version": _resolve_erpnext_version(),
        "bude_api_version": __version__,
    })


def _resolve_company_name() -> Optional[str]:
    name = frappe.db.get_default("company")
    if name:
        return name
    rows = frappe.get_list("Company", fields=["name"], limit=1, order_by="creation asc")
    return rows[0]["name"] if rows else None


def _load_company(name: str) -> Optional[dict]:
    fields = ["name", "company_logo", "country", "default_currency"]
    rows = frappe.get_list(
        "Company",
        filters=[["name", "=", name]],
        fields=fields,
        limit=1,
    )
    return rows[0] if rows else None


def _resolve_address(company: Optional[dict]) -> Optional[str]:
    if not company:
        return None
    # Use the standard Address dynamic-link pattern: Address links to the
    # Company via Dynamic Link. Pull the first display string we can find.
    rows = frappe.get_list(
        "Dynamic Link",
        filters=[
            ["link_doctype", "=", "Company"],
            ["link_name", "=", company["name"]],
            ["parenttype", "=", "Address"],
        ],
        fields=["parent"],
        limit=1,
    )
    if not rows:
        return None
    address = frappe.get_list(
        "Address",
        filters=[["name", "=", rows[0]["parent"]]],
        fields=["address_line1", "address_line2", "city", "state", "country", "pincode"],
        limit=1,
    )
    if not address:
        return None
    a = address[0]
    parts = [a.get("address_line1"), a.get("address_line2"), a.get("city"),
             a.get("state"), a.get("country"), a.get("pincode")]
    return ", ".join(p for p in parts if p)


def _resolve_erpnext_version() -> Optional[str]:
    if get_versions is None:
        return None
    try:
        versions = get_versions()
    except Exception:
        return None
    erpnext = versions.get("erpnext")
    if not erpnext:
        return None
    return erpnext.get("version")
