"""Standard envelope for API responses returned by `bude_api` endpoints."""

from typing import Any, Optional


def success(data: Any = None, message: Optional[str] = None) -> dict:
    return {"ok": True, "data": data, "message": message}


def failure(message: str, code: Optional[str] = None, data: Any = None) -> dict:
    return {"ok": False, "data": data, "message": message, "code": code}
