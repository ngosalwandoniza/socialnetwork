from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Post, Connection

@receiver(post_save, sender=Post)
@receiver(post_delete, sender=Post)
def update_profile_on_post_change(sender, instance, **kwargs):
    """Update profile metrics when a post is created or deleted."""
    instance.author.refresh_gravity()

@receiver(post_save, sender=Connection)
@receiver(post_delete, sender=Connection)
def update_profile_on_connection_change(sender, instance, **kwargs):
    """Update profile metrics when a connection status changes."""
    instance.sender.refresh_gravity()
    instance.receiver.refresh_gravity()
