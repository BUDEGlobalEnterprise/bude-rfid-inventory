"""Deterministic names and payload builders for demo data/API tests."""

from __future__ import annotations

import hashlib


def short_tag(run_id: str) -> str:
    return "".join(ch for ch in run_id if ch.isalnum())[-10:]


def company_name(run_id: str, index: int) -> str:
    return f"{run_id} Company {index:02d}"


def company_abbr(run_id: str, index: int) -> str:
    digest = hashlib.sha1(run_id.encode("utf-8")).hexdigest()[:5]
    return f"B{index:02d}{digest}".upper()[:10]


def warehouse_name(run_id: str, index: int) -> str:
    return f"{run_id} WH {index:03d}"


def item_group_name(run_id: str, index: int) -> str:
    return f"{run_id} Group {index:03d}"


def item_code(run_id: str, index: int) -> str:
    return f"{run_id}-ITEM-{index:05d}"


def barcode(run_id: str, index: int) -> str:
    return f"{short_tag(run_id)}BC{index:08d}"


def epc(run_id: str, kind: str, index: int) -> str:
    return f"{short_tag(run_id)}{kind.upper()[:3]}{index:08d}"


def supplier_name(run_id: str, index: int) -> str:
    return f"{run_id} Supplier {index:03d}"


def asset_category_name(run_id: str, index: int) -> str:
    return f"{run_id} Asset Category {index:03d}"


def location_name(run_id: str, index: int) -> str:
    return f"{run_id} Location {index:03d}"


def asset_name(run_id: str, index: int) -> str:
    return f"{run_id} Asset {index:05d}"


def transfer_payload(
    item: str,
    source_warehouse: str,
    target_warehouse: str,
    company: str | None = None,
) -> dict:
    payload = {
        "items": [{"item_code": item, "qty": 1}],
        "source_warehouse": source_warehouse,
        "target_warehouse": target_warehouse,
    }
    if company:
        payload["company"] = company
    return payload


def receipt_payload(
    item: str,
    target_warehouse: str,
    against_po: str | None = None,
    company: str | None = None,
) -> dict:
    payload = {
        "items": [{"item_code": item, "qty": 1}],
        "target_warehouse": target_warehouse,
    }
    if against_po:
        payload["against_po"] = against_po
    if company:
        payload["company"] = company
    return payload


def reconciliation_payload(item: str, warehouse: str, company: str | None = None) -> dict:
    payload = {"counts": [{"item_code": item, "qty": 1}], "warehouse": warehouse}
    if company:
        payload["company"] = company
    return payload


def navigation_payload() -> dict:
    return {
        "roles": {
            "admin": ["dashboard", "search", "transfer", "receipt", "count", "settings"],
            "manager": ["dashboard", "analytics", "reports", "alerts"],
            "operator": ["dashboard", "search", "transfer", "receipt", "count", "sync"],
        },
        "order": [
            "dashboard",
            "search",
            "transfer",
            "receipt",
            "count",
            "analytics",
            "reports",
            "alerts",
            "sync",
            "settings",
        ],
    }
