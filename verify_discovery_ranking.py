import os
import django
from django.utils import timezone
from datetime import timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')
django.setup()

from core.models import Profile, Connection
from core.services import MatchService
from django.contrib.auth.models import User

def verify_ranking():
    # 1. Setup test users if they don't exist
    # (Simplified for existing DB)
    me = Profile.objects.first()
    if not me:
        print("No profiles found. Run seed.py first.")
        return

    print(f"Checking suggestions for: {me.username}")
    suggestions = MatchService.get_suggested_people(me, limit=20)
    
    print("\n--- Discovery Rankings ---")
    for i, p in enumerate(suggestions, 1):
        status = 'FRIEND' if Connection.objects.filter(sender=me, receiver=p, status='CONNECTED').exists() or \
                           Connection.objects.filter(sender=p, receiver=me, status='CONNECTED').exists() else 'STRANGER'
        
        is_new = p.user.date_joined > timezone.now() - timedelta(hours=48)
        print(f"{i}. {p.username} | {status} | {'NEW' if is_new else 'OLD'} | Joined: {p.user.date_joined}")

if __name__ == "__main__":
    verify_ranking()
