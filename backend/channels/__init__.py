"""Channel adapters (T4): USSD menus, SMS and WhatsApp formatting rules.

Pure Python + Pydantic: no database, no network. See README.md for how T1 mounts them.
"""

from .base import ChannelAdapter
from .schema import Attachment, InboundMessage, OutgoingReply
from .sms import SmsAdapter
from .ussd import UssdAdapter
from .whatsapp import WhatsAppAdapter

__all__ = ["Attachment", "ChannelAdapter", "InboundMessage", "OutgoingReply",
           "SmsAdapter", "UssdAdapter", "WhatsAppAdapter"]
