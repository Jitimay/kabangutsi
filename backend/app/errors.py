"""Contract Error responses: {"code", "message", "details"}."""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, details: dict[str, Any] | None = None) -> None:
        self.status, self.code, self.message, self.details = status, code, message, details or {}


def error_body(code: str, message: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"code": code, "message": message, "details": details or {}}


def not_found(what: str = "Resource") -> ApiError:
    return ApiError(404, "not_found", f"{what} not found")


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_: Request, e: ApiError) -> JSONResponse:
        return JSONResponse(error_body(e.code, e.message, e.details), status_code=e.status)

    @app.exception_handler(RequestValidationError)
    async def _val(_: Request, e: RequestValidationError) -> JSONResponse:
        errs = e.errors()
        field = ".".join(str(x) for x in errs[0]["loc"][1:]) if errs else None
        msg = errs[0]["msg"] if errs else "Invalid request"
        # never echo input values back (could be a PIN)
        return JSONResponse(error_body("validation_error", msg, {"field": field}), status_code=422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, e: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "validation_error", 413: "too_large", 415: "unsupported_media_type"}.get(
            e.status_code, "internal_error"
        )
        return JSONResponse(error_body(code, str(e.detail)), status_code=e.status_code)
