import os
import django
import random
from datetime import timedelta
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')
django.setup()

from core.models import Profile, Post, Interest, Connection
from django.contrib.auth.models import User
from django.core.files.base import ContentFile

def seed_discovery_activity():
    print("Seeding discovery activity...")
    
    # Get some profiles (not the superuser)
    profiles = Profile.objects.exclude(user__is_superuser=True)
    
    if not profiles.exists():
        print("No profiles found to seed posts for.")
        return

    # Ensure everyone has some interests
    all_interests = list(Interest.objects.all())
    if not all_interests:
        print("No interests found to assign.")
    
    for profile in profiles:
        # Give them 2-3 interests if they have none
        if profile.interests.count() < 2 and all_interests:
            profile.interests.set(random.sample(all_interests, min(3, len(all_interests))))
            print(f"Assigned interests to {profile.username}")

        # Create 1-2 posts for each
        if not Post.objects.filter(author=profile).exists():
            post = Post.objects.create(
                author=profile,
                content_text=f"Check out my latest moment! #discovery #vibe",
                post_type='PERSISTENT',
                expires_at=timezone.now() + timedelta(days=7)
            )
            print(f"Created post for {profile.username}")

    print("Seeding complete.")

if __name__ == "__main__":
    seed_discovery_activity()
