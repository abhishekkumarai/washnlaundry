import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)


class RagServiceError(Exception):
    pass


class RagService:
    """
    Proxy for the washnlaundry-rag Cloudflare Worker (KAN-112). Keeps
    RAG_API_KEY server-side — a Flutter web build can't hide a secret baked
    into its JS bundle, so the client only ever talks to this backend.
    """

    @classmethod
    def get_worker_url(cls):
        return getattr(settings, 'RAG_WORKER_URL', '').rstrip('/')

    @classmethod
    def get_api_key(cls):
        return getattr(settings, 'RAG_API_KEY', '')

    @classmethod
    def stream_chat(cls, message, history=None):
        """
        Returns a `requests` streaming iterator of the worker's raw SSE
        bytes. Raises RagServiceError before any bytes are yielded if the
        worker is unreachable or rejects the request, so the Django view can
        turn that into a clean JSON error instead of a half-open stream.
        """
        url = f"{cls.get_worker_url()}/api/rag/chat"
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f"Bearer {cls.get_api_key()}",
        }
        payload = {'message': message}
        if history:
            payload['history'] = history

        try:
            resp = requests.post(
                url, json=payload, headers=headers, stream=True, timeout=(5, 120)
            )
        except requests.exceptions.RequestException as e:
            logger.error(f"RAG worker connection failed: {e}")
            raise RagServiceError(f"Could not reach the RAG service: {e}")

        if resp.status_code != 200:
            body = resp.text[:300]
            resp.close()
            raise RagServiceError(f"RAG worker returned {resp.status_code}: {body}")

        return resp.iter_content(chunk_size=None)
