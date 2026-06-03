"""Health check endpoint.

Whitelisted so unauthenticated clients can verify connectivity:

    GET /api/method/bude_api.api.health.ping
"""

from datetime import datetime, timezone

try:
    import frappe
except ImportError:
    frappe = None

from .. import __version__


def _whitelist(allow_guest: bool = False):
    if frappe is None:
        def decorator(fn):
            return fn
        return decorator
    return frappe.whitelist(allow_guest=allow_guest)


@_whitelist(allow_guest=True)
def ping() -> dict:
    return {
        "status": "ok",
        "service": "bude_api",
        "version": __version__,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
