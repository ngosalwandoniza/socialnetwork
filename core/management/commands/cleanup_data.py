from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import ChatMessage, RecoveryRequest

class Command(BaseCommand):
    help = 'Cleans up expired chat messages and recovery requests'

    def handle(self, *args, **options):
        now = timezone.now()
        
        # 1. Delete expired chat messages
        expired_messages = ChatMessage.objects.filter(expires_at__lt=now)
        msg_count = expired_messages.count()
        expired_messages.delete()
        
        # 2. Cleanup expired recovery requests
        # We don't delete them immediately, we mark as EXPIRED first if not already
        active_expired_reqs = RecoveryRequest.objects.filter(status='PENDING', expires_at__lt=now)
        req_update_count = active_expired_reqs.update(status='EXPIRED')
        
        # 3. Physically delete requests older than 30 days
        month_ago = now - timezone.timedelta(days=30)
        old_reqs = RecoveryRequest.objects.filter(created_at__lt=month_ago)
        old_req_count = old_reqs.count()
        old_reqs.delete()

        self.stdout.write(self.style.SUCCESS(
            f'Successfully cleaned up: {msg_count} messages, '
            f'{req_update_count} recovery requests expired, '
            f'{old_req_count} old requests deleted.'
        ))
