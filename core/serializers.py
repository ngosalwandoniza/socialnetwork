from rest_framework import serializers
from django.contrib.auth.models import User
from django.db.models import Q
from django.db import models
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
    is_active = serializers.SerializerMethodField()
    smart_snippet = serializers.SerializerMethodField()
    mutual_friend_pics = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = [
            'id', 'username', 'profile_picture', 'age', 'gender', 
            'interests', 'interest_ids', 'is_discovery_on', 'current_location',
            'mutual_connections_count', 'shared_room_name', 'connection_status',
            'posts_count', 'connections_count', 'social_gravity', 'fcm_token',
            'streak_count', 'latest_post', 'is_active', 'smart_snippet', 'mutual_friend_pics'
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
        """Pre-load connection statuses, streaks, and latest posts in bulk."""
        result = super().many_init(*args, **kwargs)
        request = kwargs.get('context', {}).get('request')
        instances = args[0] if args else kwargs.get('instance', [])
        profile_ids = [p.id for p in instances] if instances else []

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

        # Bulk-load streaks for all profiles
        if profile_ids:
            yesterday = timezone.now().date() - timezone.timedelta(days=1)
            streaks = Streak.objects.filter(
                user_id__in=profile_ids, last_post_date__gte=yesterday
            ).values('user_id', 'count')
            streak_map = {s['user_id']: s['count'] for s in streaks}
            result.child.context['_streak_map'] = streak_map

            # Bulk-load latest post per profile using a subquery
            from django.db.models import Subquery, OuterRef
            latest_ids = Post.objects.filter(
                author_id__in=profile_ids
            ).values('author_id').annotate(
                latest_id=models.Max('id')
            ).values_list('latest_id', flat=True)
            latest_posts = Post.objects.filter(id__in=latest_ids)
            post_map = {}
            for p in latest_posts:
                post_map[p.author_id] = {
                    'id': p.id,
                    'image': p.image.url if p.image else None,
                    'video': p.video.url if p.video else None,
                    'content_text': p.content_text,
                    'created_at': p.created_at
                }
            result.child.context['_latest_post_map'] = post_map

            # Bulk-load mutual friend pics
            mutual_pics_map = {}
            user_friend_ids = set(Connection.objects.filter(
                Q(sender=user_profile) | Q(receiver=user_profile),
                status='CONNECTED'
            ).values_list('sender_id', 'receiver_id'))
            
            # Flatten user friend ids
            u_friends = set()
            for s, r in user_friend_ids:
                u_friends.add(s if s != user_profile.id else r)
                
            # For each candidate, find connections with u_friends
            candidate_connections = Connection.objects.filter(
                (Q(sender_id__in=profile_ids) & Q(receiver_id__in=u_friends)) |
                (Q(receiver_id__in=profile_ids) & Q(sender_id__in=u_friends)),
                status='CONNECTED'
            ).select_related('sender', 'receiver')
            
            for conn in candidate_connections:
                sid, rid = conn.sender_id, conn.receiver_id
                # Determine which one is the candidate and which is the mutual friend
                cand_id = sid if sid in profile_ids else rid
                friend = conn.receiver if sid in profile_ids else conn.sender
                
                if cand_id not in mutual_pics_map:
                    mutual_pics_map[cand_id] = []
                if len(mutual_pics_map[cand_id]) < 3:
                    if friend.profile_picture:
                        mutual_pics_map[cand_id].append(friend.profile_picture.url)
            
            result.child.context['_mutual_pics_map'] = mutual_pics_map

        return result

    def get_streak_count(self, obj):
        # Use bulk-loaded data if available
        streak_map = self.context.get('_streak_map')
        if streak_map is not None:
            return streak_map.get(obj.id, 0)
        # Fallback for single-profile serialization
        if obj.current_location:
            streak = Streak.objects.filter(user=obj, location=obj.current_location).first()
            if streak:
                today = timezone.now().date()
                yesterday = today - timezone.timedelta(days=1)
                if streak.last_post_date >= yesterday:
                    return streak.count
        return 0

    def get_latest_post(self, obj):
        # Use bulk-loaded data if available
        post_map = self.context.get('_latest_post_map')
        if post_map is not None:
            return post_map.get(obj.id)
        # Fallback for single-profile serialization
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

    def get_is_active(self, obj):
        if not obj.last_active:
            return False
        return obj.last_active > timezone.now() - timezone.timedelta(minutes=5)

    def get_smart_snippet(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
            
        user_profile = request.user.profile
        
        # 1. New User
        if obj.user.date_joined > timezone.now() - timezone.timedelta(hours=48):
            return "New here! 👋"
            
        # 2. Shared Interests
        user_interests = set(user_profile.interests.values_list('name', flat=True))
        obj_interests = set(obj.interests.values_list('name', flat=True))
        shared = user_interests.intersection(obj_interests)
        if shared:
            return f"Both into {list(shared)[0]}"
            
        # 3. Location
        if user_profile.current_location and obj.current_location and user_profile.current_location == obj.current_location:
            return f"Also in {user_profile.current_location.name}"
            
        return None

    def get_mutual_friend_pics(self, obj):
        pics_map = self.context.get('_mutual_pics_map')
        if pics_map is not None:
            return pics_map.get(obj.id, [])
        return []

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
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = [
            'id', 'author', 'author_name', 'author_pic', 'content_text', 'image', 'video', 'thumbnail',
            'location', 'contributors', 'created_at', 'expires_at', 'likes_count', 'comments_count',
            'post_type', 'is_collaborative', 'is_liked'
        ]
        read_only_fields = ['author', 'expires_at', 'created_at']

    @classmethod
    def many_init(cls, *args, **kwargs):
        """Pre-load is_liked statuses in bulk when serializing many posts."""
        result = super().many_init(*args, **kwargs)
        request = kwargs.get('context', {}).get('request')
        instances = args[0] if args else kwargs.get('instance', [])
        if request and request.user.is_authenticated and instances:
            user_profile = request.user.profile
            post_ids = [p.id for p in instances]
            liked_ids = set(
                Like.objects.filter(
                    user=user_profile, post_id__in=post_ids
                ).values_list('post_id', flat=True)
            )
            result.child.context['_liked_post_ids'] = liked_ids
        return result

    def get_likes_count(self, obj):
        # Use annotated value if available (from FeedService), otherwise fallback
        if hasattr(obj, 'likes_count'):
            return obj.likes_count
        return obj.likes.count()

    def get_comments_count(self, obj):
        # Use annotated value if available (from FeedService), otherwise fallback
        if hasattr(obj, 'comments_count'):
            return obj.comments_count
        return obj.comments.count()

    def get_is_liked(self, obj):
        # Use bulk-loaded data if available
        liked_ids = self.context.get('_liked_post_ids')
        if liked_ids is not None:
            return obj.id in liked_ids
        # Fallback for single-post serialization
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

