"""Channel adapter interface.

Every adapter converts its channel's raw payload to the standard InboundMessage and the
backend's OutgoingReply back to its channel's raw form. Adapters never touch the database.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, ClassVar

from .schema import Channel, InboundMessage, OutgoingReply


class ChannelAdapter(ABC):
    channel: ClassVar[Channel]

    @abstractmethod
    def parse_inbound(self, raw: Any) -> InboundMessage:
        """Channel payload -> standard message. Raises ValueError on an unusable payload."""

    @abstractmethod
    def format_outbound(self, reply: OutgoingReply) -> Any:
        """Standard reply -> channel payload."""
