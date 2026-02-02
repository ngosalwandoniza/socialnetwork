from django.contrib import admin
from .models import Profile, Post, LocationRoom, Interest, Connection, ChatMessage, Like, Comment, Streak

@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ('username', 'user', 'gender', 'age', 'current_location', 'last_active')
    search_fields = ('username', 'user__username')
    list_filter = ('gender', 'is_discovery_on')

@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ('author', 'location', 'created_at', 'expires_at')
    list_filter = ('created_at', 'location')
    search_fields = ('content_text', 'author__username')

@admin.register(LocationRoom)
class LocationRoomAdmin(admin.ModelAdmin):
    list_display = ('name', 'latitude', 'longitude', 'radius_meters')
    search_fields = ('name',)

@admin.register(Interest)
class InterestAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Connection)
class ConnectionAdmin(admin.ModelAdmin):
    list_display = ('sender', 'receiver', 'status', 'created_at')
    list_filter = ('status',)

@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'receiver', 'timestamp', 'is_read')
    list_filter = ('is_read', 'timestamp')

@admin.register(Like)
class LikeAdmin(admin.ModelAdmin):
    list_display = ('user', 'post', 'created_at')

@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ('user', 'post', 'created_at')
    search_fields = ('content',)

@admin.register(Streak)
class StreakAdmin(admin.ModelAdmin):
    list_display = ('user', 'location', 'count', 'last_post_date')
    list_filter = ('location',)
