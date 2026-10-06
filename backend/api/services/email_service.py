import html
import logging

import requests
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

RESEND_URL = 'https://api.resend.com/emails'


class EmailService:
    """
    Emails website-chat leads to the shop through Resend's HTTPS API. Plain
    SMTP is not an option here: Render's free tier blocks outbound SMTP ports.
    """

    @classmethod
    def _build(cls, lead):
        when = timezone.localtime(lead.created_at).strftime('%d %b %Y, %I:%M %p')
        origin = 'the website chat' if lead.source == 'chat' else 'the website pickup form'
        rows = [
            ('Name', lead.name),
            ('Phone', lead.phone),
            ('Address', lead.address),
            ('Requirements', lead.requirements),
            ('Received', when),
        ]
        text = f'New pickup request from {origin}\n\n' + '\n'.join(f'{k}: {v}' for k, v in rows)
        body = ''.join(
            f'<tr><td style="padding:4px 12px 4px 0;color:#555"><b>{k}</b></td>'
            f'<td style="padding:4px 0">{html.escape(str(v))}</td></tr>'
            for k, v in rows
        )
        markup = (
            f'<p>New pickup request from {origin}</p>'
            f'<table style="font-family:sans-serif;font-size:14px">{body}</table>'
        )
        return f'washnlaundry - New pickup request: {lead.name}', text, markup

    @classmethod
    def send_lead_alert(cls, lead):
        """
        Email one lead and record the outcome on it. Never raises: a provider
        outage must not lose the lead, it just stays PENDING for the cron.
        """
        from api.models import Lead

        lead.email_attempts += 1
        key = getattr(settings, 'RESEND_API_KEY', '')
        if not key:
            ok, error = False, 'RESEND_API_KEY is not set'
        else:
            subject, text, markup = cls._build(lead)
            try:
                resp = requests.post(
                    RESEND_URL,
                    headers={'Authorization': f'Bearer {key}'},
                    json={
                        'from': settings.LEAD_EMAIL_FROM,
                        'to': settings.LEAD_EMAIL_TO,
                        'subject': subject,
                        'text': text,
                        'html': markup,
                    },
                    timeout=10,
                )
                ok = resp.status_code < 300
                error = None if ok else f'Resend {resp.status_code}: {resp.text[:200]}'
            except requests.exceptions.RequestException as e:
                ok, error = False, str(e)

        if ok:
            lead.email_status = Lead.SENT
        else:
            logger.warning('Lead %s email not delivered (attempt %s): %s', lead.pk, lead.email_attempts, error)
            lead.email_status = (
                Lead.FAILED if lead.email_attempts >= Lead.MAX_EMAIL_ATTEMPTS else Lead.PENDING
            )
        lead.save(update_fields=['email_status', 'email_attempts'])
        return ok

    @classmethod
    def retry_pending(cls):
        from api.models import Lead

        pending = list(Lead.objects.filter(email_status=Lead.PENDING).order_by('created_at')[:20])
        sent = sum(1 for lead in pending if cls.send_lead_alert(lead))
        return {
            'retried': len(pending),
            'sent': sent,
            'pending': Lead.objects.filter(email_status=Lead.PENDING).count(),
        }
