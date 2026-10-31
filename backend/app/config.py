"""Settings from environment / .env (see .env.example at the repo root)."""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

VERSION = "1.0.0"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    database_url: str = "postgresql+asyncpg://kabangutsi:kabangutsi_dev@localhost:5432/kabangutsi"

    # Models
    ollama_url: str = "http://localhost:11434"
    default_model: str = "gemma:2b"
    hard_task_model: str = "gemma4:e4b"
    model_preference: Annotated[list[str], NoDecode] = ["gemma4:e4b", "gemma4:e2b", "gemma:2b"]
    embed_model: str = "nomic-embed-text"
    ollama_keep_alive: str = "30m"
    models_cache_seconds: float = 30.0
    llm_timeout_seconds: float = 120.0
    embed_on_startup: bool = True

    # Conversation policy (code only)
    confidence_threshold: float = 0.5
    frustration_threshold: float = 0.7
    max_identity_attempts: int = 3
    identity_lock_minutes: int = 15
    card_block_confirm_minutes: int = 5
    default_lang: str = "fr"
    agent_dashboard_lang: str = "fr"
    tz_local: str = "Africa/Bujumbura"
    session_reuse_minutes: int = 30

    # RAG
    rag_min_score: float = 0.12
    rag_k: int = 4

    # Time budgets for hard-task calls (fall back to code when exceeded)
    handoff_summary_timeout: float = 15.0
    suggestion_timeout: float = 2.5
    intent_retry_timeout: float = 30.0

    # Other services
    voice_url: str = "http://localhost:8001"
    ocr_url: str = "http://localhost:8002"
    sms_gateway_url: str = "http://localhost:8003"
    whatsapp_bridge_url: str = "http://localhost:8004"
    service_timeout: float = 30.0

    files_dir: str = "./data/files"
    cors_origins: Annotated[list[str], NoDecode] = ["http://localhost:8080", "http://127.0.0.1:8080"]

    # Start the Postgres LISTEN hub (off in some tests)
    realtime_enabled: bool = True

    @field_validator("model_preference", "cors_origins", mode="before")
    @classmethod
    def _split_csv(cls, v: object) -> object:
        if isinstance(v, str):
            s = v.strip()
            if s.startswith("["):
                import json

                return json.loads(s)
            return [x.strip() for x in s.split(",") if x.strip()]
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()
