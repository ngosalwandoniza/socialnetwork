from django.db import models
from django.db.models import Q
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from django.core.validators import MinValueValidator, MaxValueValidator, MinLengthValidator

class Interest(models.Model):
    name = models.CharField(max_length=50, unique=True)
    
    def __str__(self):
        return self.name

class Profile(models.Model):
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
        
    ]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    username = models.CharField(max_length=150, unique=True) # Custom display name
    profile_picture = models.ImageField(upload_to='profiles/', null=True, blank=True)
    age = models.PositiveIntegerField(
        null=True, blank=True,
        validators=[MinValueValidator(13), MaxValueValidator(99)]
    )
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES, null=True, blank=True)
    interests = models.ManyToManyField(Interest, blank=True)
    
    # Matching / Proximity state
    current_location = models.ForeignKey('LocationRoom', on_delete=models.SET_NULL, null=True, blank=True)
    last_active = models.DateTimeField(auto_now=True)
    is_discovery_on = models.BooleanField(default=True)
    fcm_token = models.CharField(max_length=255, null=True, blank=True)

    @property
    def posts_count(self):
        return self.posts.count()

    @property
    def connections_count(self):
        return Connection.objects.filter(
            Q(sender=self, status='CONNECTED') | Q(receiver=self, status='CONNECTED')
        ).count()

    @property
    def social_gravity(self):
        """
        Calculates a Social Gravity score (0.0 to 5.0) based on:
        - Connection count (weight: 40%)
        - Post count (weight: 30%)
        - Activity recency (weight: 30%)
        """
        conn_score = min(self.connections_count / 10, 1) * 2.0  # Max 2.0
        post_score = min(self.posts_count / 20, 1) * 1.5       # Max 1.5
        
        # Recency score
        last_24h = timezone.now() - timedelta(hours=24)
        recency_score = 1.5 if self.last_active > last_24h else 0.5
        
        score = conn_score + post_score + recency_score
        return round(min(max(score, 1.0), 5.0), 1)

    def __str__(self):
        return self.username

class LocationRoom(models.Model):
    name = models.CharField(max_length=100)
    city = models.CharField(max_length=100, null=True, blank=True)
    region = models.CharField(max_length=100, null=True, blank=True) # e.g. Copperbelt, Lusaka
    latitude = models.FloatField()
    longitude = models.FloatField()
    radius_meters = models.FloatField(default=100) # Geofence size

    def __str__(self):
        return f"{self.name} ({self.city or 'No City'}, {self.region or 'No Region'})"

class Post(models.Model):
    POST_TYPE_CHOICES = [
        ('EPHEMERAL', 'Ephemeral (24h)'),
        ('PERSISTENT', 'Persistent (stays on profile)'),
    ]
    
    author = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='posts')
    content_text = models.TextField(blank=True, validators=[MinLengthValidator(0)])
    image = models.ImageField(upload_to='posts/', null=True, blank=True)
    video = models.FileField(upload_to='posts/videos/', null=True, blank=True)
    thumbnail = models.ImageField(upload_to='posts/thumbnails/', null=True, blank=True)
    location = models.ForeignKey(LocationRoom, on_delete=models.SET_NULL, null=True, blank=True)
    contributors = models.ManyToManyField(Profile, blank=True, related_name='collaborative_posts')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    post_type = models.CharField(max_length=10, choices=POST_TYPE_CHOICES, default='EPHEMERAL')
    is_collaborative = models.BooleanField(default=False)
    
    def save(self, *args, **kwargs):
        # Persistent posts never expire
        if self.post_type == 'PERSISTENT':
            self.expires_at = None
        elif not self.expires_at and self.post_type == 'EPHEMERAL':
            self.expires_at = timezone.now() + timedelta(hours=24)
        super().save(*args, **kwargs)

    def is_expired(self):
        if self.post_type == 'PERSISTENT':
            return False
        return self.expires_at and timezone.now() > self.expires_at

    def __str__(self):
        return f"Post by {self.author.username} at {self.location}"

class Like(models.Model):
    user = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='likes')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'post')

class Comment(models.Model):
    user = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='comments')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies')
    content = models.TextField()
    likes = models.ManyToManyField(Profile, blank=True, related_name='liked_comments')
    created_at = models.DateTimeField(auto_now_add=True)

class Streak(models.Model):
    user = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='streaks')
    location = models.ForeignKey(LocationRoom, on_delete=models.CASCADE)
    count = models.PositiveIntegerField(default=1)
    last_post_date = models.DateField(auto_now=True)

    class Meta:
        unique_together = ('user', 'location')

class Connection(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending Request'),
        ('CONNECTED', 'Connected'),
        ('BLOCKED', 'Blocked'),
    ]
    sender = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='sent_connections')
    receiver = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='received_connections')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('sender', 'receiver')
    
    def __str__(self):
        return f"{self.sender.username} -> {self.receiver.username} ({self.status})"

class ChatMessage(models.Model):
    sender = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='sent_messages')
    receiver = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='received_messages')
    content = models.TextField(blank=True)
    image = models.ImageField(upload_to='chat_images/', null=True, blank=True)
    video = models.FileField(upload_to='chat_videos/', null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    expires_at = models.DateTimeField(null=True, blank=True)

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(days=7)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Msg from {self.sender.username} to {self.receiver.username}"


class Report(models.Model):
    """User safety reports for content or account violations."""
    REASON_CHOICES = [
        ('SPAM', 'Spam'),
        ('HARASSMENT', 'Harassment'),
        ('INAPPROPRIATE', 'Inappropriate Content'),
        ('FAKE', 'Fake Account'),
        ('OTHER', 'Other'),
    ]
    reporter = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='reports_made')
    reported_user = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='reports_received')
    reported_post = models.ForeignKey(Post, on_delete=models.CASCADE, null=True, blank=True, related_name='reports')
    reason = models.CharField(max_length=20, choices=REASON_CHOICES)
    details = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_resolved = models.BooleanField(default=False)

    def __str__(self):
        return f"Report by {self.reporter.username} against {self.reported_user.username}"


class Notification(models.Model):
    """Internal log of push notifications sent."""
    TYPE_CHOICES = [
        ('MESSAGE', 'New Message'),
        ('CONNECTION_REQUEST', 'Connection Request'),
        ('CONNECTION_ACCEPTED', 'Connection Accepted'),
        ('COLLABORATION', 'Collaboration Invite'),
        ('RECOVERY_VOUCH', 'Recovery Vouch Request'),
    ]
    
    recipient = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='notifications')
    sender = models.ForeignKey(Profile, on_delete=models.CASCADE, null=True, blank=True)
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    title = models.CharField(max_length=100)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.notification_type} for {self.recipient.username}"


class RecoveryCode(models.Model):
    """Hashed one-time backup codes for password recovery."""
    profile = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='recovery_codes')
    code_hash = models.CharField(max_length=128) 
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Recovery Code for {self.profile.username}"


class RecoveryGuardian(models.Model):
    """Trusted friends who can vouch for a user during social recovery."""
    profile = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='guardians')
    guardian = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='guarded_profiles')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('profile', 'guardian')

    def __str__(self):
        return f"{self.guardian.username} protects {self.profile.username}"


class RecoveryRequest(models.Model):
    """Tracking active social recovery attempts."""
    STATUS_CHOICES = [
        ('PENDING', 'Pending Approvals'),
        ('APPROVED', 'Approved (Ready to Reset)'),
        ('EXPIRED', 'Expired'),
        ('COMPLETED', 'Completed'),
    ]
    profile = models.ForeignKey(Profile, on_delete=models.CASCADE, related_name='recovery_requests')
    token = models.CharField(max_length=6, unique=True) # 6-digit token shared offline
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='PENDING')
    approvals = models.ManyToManyField(Profile, related_name='approved_recoveries', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"Recovery of {self.profile.username} ({self.status})"

    def is_active(self):
        return self.status == 'PENDING' and timezone.now() < self.expires_at

