import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')
django.setup()

from core.models import Profile, Connection, Notification
from django.contrib.auth import get_user_model

User = get_user_model()

def create_test_data():
    # Get current user (assuming 'admin' or first user)
    current_user = User.objects.first()
    if not current_user:
        print("No users found. Please register a user first.")
        return
    
    profile_a = current_user.profile
    print(f"Target profile: {profile_a.username}")

    # Create dummy user B
    user_b, created = User.objects.get_or_create(username='test_user_b')
    if created:
        user_b.set_password('password123')
        user_b.save()
        profile_b = Profile.objects.create(user=user_b, username='test_user_b')
    else:
        profile_b = user_b.profile

    # 1. Create a pending connection request from B to A
    conn, created = Connection.objects.get_or_create(
        sender=profile_b,
        receiver=profile_a,
        status='PENDING'
    )
    if created:
        print(f"Created pending connection from {profile_b.username} to {profile_a.username}")
        # Create notification for the request
        Notification.objects.create(
            recipient=profile_a,
            sender=profile_b,
            notification_type='CONNECTION_REQUEST',
            title='New Connection Request',
            body=f'{profile_b.username} wants to connect with you!'
        )
    else:
        print("Pending connection already exists.")

    # 2. Create a generic message notification
    Notification.objects.create(
        recipient=profile_a,
        sender=profile_b,
        notification_type='MESSAGE',
        title='New Message',
        body='Hey! Just seeing if notifications work.'
    )
    print("Created test message notification.")

if __name__ == "__main__":
    create_test_data()
