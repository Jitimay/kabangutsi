"""Error shape from contracts/voice_api.yaml: {code, message, details?}."""
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, details: dict | None = None):
        self.status, self.code, self.message, self.details = status, code, message, details


def _body(code: str, message: str, details: dict | None) -> dict:
    body = {"code": code, "message": message}
    if details:
        body["details"] = details
    return body


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_: Request, e: ApiError):
        return JSONResponse(_body(e.code, e.message, e.details), status_code=e.status)

    @app.exception_handler(RequestValidationError)
    async def _val(_: Request, e: RequestValidationError):
        errs = e.errors()
        first = errs[0] if errs else {}
        field = ".".join(str(x) for x in first.get("loc", [])[1:])
        if field == "lang" and first.get("type") in ("enum", "literal_error"):
            return JSONResponse(_body("unsupported_language", "lang must be fr, en or rn", {"field": "lang"}),
                                status_code=422)
        return JSONResponse(_body("validation_error", first.get("msg", "invalid request"),
                                  {"field": field} if field else None), status_code=422)

    @app.exception_handler(Exception)
    async def _any(_: Request, e: Exception):
        return JSONResponse(_body("internal_error", "voice service error", {"type": type(e).__name__}),
                            status_code=500)
