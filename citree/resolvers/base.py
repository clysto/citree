from abc import ABC, abstractmethod
from typing import Optional


class BaseResolver(ABC):
    """Abstract base class for metadata resolvers."""

    name: str = "base"

    @classmethod
    @abstractmethod
    def can_resolve(cls, query: str) -> bool:
        """Determine if this resolver can handle the given query."""
        pass

    @abstractmethod
    def resolve(self, query: str) -> dict:
        """Resolve the query to Zotero JSON metadata."""
        pass

    def fetch_pdf(self) -> Optional[bytes]:
        """
        (Optional) Fetch the PDF for the resolved entry.
        Return None if not supported or not available.
        """
        return None
