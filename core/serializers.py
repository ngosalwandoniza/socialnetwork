from rest_framework import serializers
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone
from .models import Profile, Interest, LocationRoom, Post, Connection, ChatMessage, Like, Comment, Streak, Notification, RecoveryRequest

class InterestSerializer(serializers.ModelSerializer):
    class Meta:
        model = Interest
        fields = ['id', 'name']

class ProfileSerializer(serializers.ModelSerializer):
    interests = InterestSerializer(many=True, read_only=True)
    interest_ids = serializers.PrimaryKeyRelatedField(
        many=True, write_only=True, queryset=Interest.objects.all(), source='interests'
    )
    
    mutual_connections_count = serializers.IntegerField(read_only=True)
    shared_room_name = serializers.CharField(read_only=True)
    connection_status = serializers.SerializerMethodField()
    posts_count = serializers.IntegerField(read_only=True)
    connections_count = serializers.IntegerField(read_only=True)
    social_gravity = serializers.FloatField(read_only=True)
    streak_count = serializers.SerializerMethodField()
    latest_post = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = [
            'id', 'username', 'profile_picture', 'age', 'gender', 
            'interests', 'interest_ids', 'is_discovery_on', 'current_location',
            'mutual_connections_count', 'shared_room_name', 'connection_status',
            'posts_count', 'connections_count', 'social_gravity', 'fcm_token',
            'streak_count', 'latest_post'
        ]

    def get_connection_status(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return 'NONE'
        
        # Use pre-loaded connection map if available (bulk optimization)
        conn_map = self.context.get('_connection_map')
        if conn_map is not None:
            return conn_map.get(obj.id, 'NONE')
        
        user_profile = request.user.profile
        connection = Connection.objects.filter(
            Q(sender=user_profile, receiver=obj) | Q(sender=obj, receiver=user_profile)
        ).first()
        
        return connection.status if connection else 'NONE'

    @classmethod
    def many_init(cls, *args, **kwargs):
        """Pre-load connection statuses in bulk when serializing many profiles."""
        result = super().many_init(*args, **kwargs)
        request = kwargs.get('context', {}).get('request')
        if request and request.user.is_authenticated:
            user_profile = request.user.profile
            connections = Connection.objects.filter(
                Q(sender=user_profile) | Q(receiver=user_profile)
            ).values('sender_id', 'receiver_id', 'status')
            conn_map = {}
            for c in connections:
                other_id = c['sender_id'] if c['sender_id'] != user_profile.id else c['receiver_id']
                conn_map[other_id] = c['status']
            result.child.context['_connection_map'] = conn_map
        return result

    def get_streak_count(self, obj):
        if obj.current_location:
            streak = Streak.objects.filter(user=obj, location=obj.current_location).first()
            if streak:
                # Basic check: is the streak still "active" (last post was today or yesterday)?
                today = timezone.now().date()
                yesterday = today - timezone.timedelta(days=1)
                if streak.last_post_date >= yesterday:
                    return streak.count
        return 0

    def get_latest_post(self, obj):
        latest = Post.objects.filter(author=obj).order_by('-created_at').first()
        if latest:
            return {
                'id': latest.id,
                'image': latest.image.url if latest.image else None,
                'video': latest.video.url if latest.video else None,
                'content_text': latest.content_text,
                'created_at': latest.created_at
            }
        return None

class RegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    profile_picture = serializers.ImageField(required=False)
    age = serializers.IntegerField(required=False, min_value=13, max_value=99)
    gender = serializers.ChoiceField(choices=Profile.GENDER_CHOICES, required=False)
    interest_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True, required=False
    )

    class Meta:
        model = User
        fields = ['username', 'password', 'profile_picture', 'age', 'gender', 'interest_ids']

    def validate_username(self, value):
        import re
        if not re.match(r'^[a-zA-Z0-9_]+$', value):
            raise serializers.ValidationError("Usernames can only contain letters, numbers, and underscores.")
        if len(value) < 3:
            raise serializers.ValidationError("Username must be at least 3 characters long.")
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def create(self, validated_data):
        profile_data = {
            'username': validated_data.get('username'),
            'profile_picture': validated_data.get('profile_picture'),
            'age': validated_data.get('age'),
            'gender': validated_data.get('gender'),
        }
        user = User.objects.create_user(
            username=validated_data['username'],
            password=validated_data['password']
        )
        profile = Profile.objects.create(user=user, **profile_data)
        
        interest_ids = validated_data.get('interest_ids', [])
        if interest_ids:
            profile.interests.set(interest_ids)
            
        return user

class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.ReadOnlyField(source='author.username')
    author_pic = serializers.ImageField(source='author.profile_picture', read_only=True)
    likes_count = serializers.IntegerField(source='likes.count', read_only=True)
    comments_count = serializers.IntegerField(source='comments.count', read_only=True)
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = [
            'id', 'author', 'author_name', 'author_pic', 'content_text', 'image', 'video', 'thumbnail',
            'location', 'contributors', 'created_at', 'expires_at', 'likes_count', 'comments_count',
            'post_type', 'is_collaborative', 'is_liked'
        ]
        read_only_fields = ['author', 'expires_at', 'created_at']

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user.profile).exists()
        return False

    def validate(self, data):
        """Ensure at least one form of content exists."""
        if not data.get('content_text') and not data.get('image') and not data.get('video'):
            raise serializers.ValidationError("Post must contain text, an image, or a video.")
        return data

    def validate_image(self, value):
        if value and value.size > 10 * 1024 * 1024: # 10MB limit
            raise serializers.ValidationError("Image file size too large (max 10MB).")
        return value

    def validate_video(self, value):
        if value and value.size > 50 * 1024 * 1024: # 50MB limit
            raise serializers.ValidationError("Video file size too large (max 50MB).")
        return value

class LikeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Like
        fields = '__all__'

class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.ReadOnlyField(source='user.username')
    author_pic = serializers.ImageField(source='user.profile_picture', read_only=True)
    replies_count = serializers.IntegerField(source='replies.count', read_only=True)
    likes_count = serializers.IntegerField(source='likes.count', read_only=True)
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ['id', 'user', 'author_name', 'author_pic', 'post', 'parent', 'content', 'created_at', 'replies_count', 'likes_count', 'is_liked']

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.profile.id).exists()
        return False

class StreakSerializer(serializers.ModelSerializer):
    location_name = serializers.ReadOnlyField(source='location.name')

    class Meta:
        model = Streak
        fields = ['id', 'location', 'location_name', 'count', 'last_post_date']

class LocationRoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationRoom
        fields = ['id', 'name', 'latitude', 'longitude', 'radius_meters']

class ConnectionSerializer(serializers.ModelSerializer):
    sender_name = serializers.ReadOnlyField(source='sender.username')
    receiver_name = serializers.ReadOnlyField(source='receiver.username')
    sender_pic = serializers.ImageField(source='sender.profile_picture', read_only=True)
    receiver_pic = serializers.ImageField(source='receiver.profile_picture', read_only=True)

    class Meta:
        model = Connection
        fields = ['id', 'sender', 'sender_name', 'sender_pic', 'receiver', 'receiver_name', 'receiver_pic', 'status', 'created_at']

class ChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.ReadOnlyField(source='sender.username')
    receiver_name = serializers.ReadOnlyField(source='receiver.username')

    class Meta:
        model = ChatMessage
        fields = ['id', 'sender', 'sender_name', 'receiver', 'receiver_name', 'content', 'image', 'video', 'thumbnail', 'timestamp', 'is_read', 'expires_at']


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'

class RecoverySerializer(serializers.ModelSerializer):
    class Meta:
        model = RecoveryRequest
        fields = ['id', 'profile', 'status', 'created_at', 'expires_at', 'attempts']

class PasswordResetSerializer(serializers.Serializer):
    username = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=6)

