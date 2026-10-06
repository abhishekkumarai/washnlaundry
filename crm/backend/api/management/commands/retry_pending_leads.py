from django.core.management.base import BaseCommand

from api.services.email_service import EmailService


class Command(BaseCommand):
    help = "Re-send the alert email for website-chat leads that could not be delivered."

    def handle(self, *args, **options):
        result = EmailService.retry_pending()
        self.stdout.write(
            f"Retried {result['retried']} lead(s); {result['sent']} sent, {result['pending']} still pending."
        )
