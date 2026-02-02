from django.utils import timezone
from .models import Profile, LocationRoom, Post, Connection, Streak
from django.db import models
from django.db.models import Count, Q

class MatchService:
    @staticmethod
    def get_suggested_people(user_profile, limit=10):
        """
        Returns a list of suggested profiles based on:
        1. Proximity (Same LocationRoom)
        2. Gender Bias (Opposite gender gets a boost)
        3. Shared Interests
        4. Recency (Active in the last hour)
        5. Mutual Connections (+15 each)
        6. Shared Location History (Streaks) (+5)
        """
        # Get blocked user IDs (exclude from suggestions)
        blocked_connections = Connection.objects.filter(
            Q(sender=user_profile, status='BLOCKED') | Q(receiver=user_profile, status='BLOCKED')
        ).values_list('sender_id', 'receiver_id')
        blocked_ids = set()
        for sid, rid in blocked_connections:
            blocked_ids.add(sid if sid != user_profile.id else rid)
        
        # Get already connected user IDs (exclude from suggestions - they're already friends)
        connected_connections = Connection.objects.filter(
            Q(sender=user_profile, status='CONNECTED') | Q(receiver=user_profile, status='CONNECTED')
        ).values_list('sender_id', 'receiver_id')
        connected_ids = set()
        for sid, rid in connected_connections:
            connected_ids.add(sid if sid != user_profile.id else rid)
        
        # Exclude only self and discovery-off users. 
        # We NO LONGER exclude already connected users, so they can appear as fallback.
        exclude_ids = blocked_ids | {user_profile.id}
        candidates = Profile.objects.exclude(id__in=exclude_ids).filter(is_discovery_on=True).select_related('user')
        
        # Get user's current connections for mutual connection calculation
        user_friend_ids = connected_ids.copy()
        
        current_interests = set(user_profile.interests.values_list('id', flat=True))
        now = timezone.now()
        
        scored_candidates = []
        for candidate in candidates:
            score = 0
            is_connected = candidate.id in connected_ids
            
            # 1. Unconnected / New User Multipliers
            # Stranger boost (+500)
            if not is_connected:
                score += 500
                # New User boost (last 48h) (+500)
                if candidate.user.date_joined > now - timezone.timedelta(hours=48):
                    score += 500
            
            # 2. Location boost (+50)
            if user_profile.current_location and candidate.current_location == user_profile.current_location:
                score += 50
                
            # 3. Gender Bias: Boys -> Girls, Girls -> Boys (+30)
            if user_profile.gender == 'M' and candidate.gender == 'F':
                score += 30
            elif user_profile.gender == 'F' and candidate.gender == 'M':
                score += 30
            
            # 4. Shared Interests (+10 per tag)
            candidate_interests = set(candidate.interests.values_list('id', flat=True))
            shared = current_interests.intersection(candidate_interests)
            score += len(shared) * 10
            
            # 5. Recency boost (last 10 mins) (+10)
            if candidate.last_active > now - timezone.timedelta(minutes=10):
                score += 10
            
            # 6. Mutual Connections (+15 each)
            candidate_connections = set(Connection.objects.filter(
                Q(sender=candidate, status='CONNECTED') | Q(receiver=candidate, status='CONNECTED')
            ).values_list('sender_id', 'receiver_id'))
            candidate_friend_ids = {sid if sid != candidate.id else rid for sid, rid in candidate_connections}
            
            mutuals = user_friend_ids.intersection(candidate_friend_ids)
            score += len(mutuals) * 15

            # 7. Shared Location History (Streaks) (+5)
            if Streak.objects.filter(user=candidate).exists():
                score += 5
                
            scored_candidates.append({
                'profile': candidate,
                'score': score
            })
            
        # Sort by score descending
        scored_candidates.sort(key=lambda x: x['score'], reverse=True)
        return [item['profile'] for item in scored_candidates[:limit]]

class FeedService:
    @staticmethod
    def get_local_feed(user_profile, limit=20):
        """
        Returns posts ranked by:
        1. Location (Same room: +50)
        2. Engagement (Likes: +2, Comments: +5)
        3. Interest Match (+10 per tag)
        4. Freshness (Penalty for older posts)
        """
        # Filter by expiry
        now = timezone.now()
        posts = Post.objects.filter(expires_at__gt=now).select_related('author', 'location').prefetch_related('likes', 'comments')
        
        user_interests = set(user_profile.interests.values_list('id', flat=True))
        
        scored_posts = []
        for post in posts:
            score = 0
            
            # 1. Location boost (+50)
            if user_profile.current_location and post.location == user_profile.current_location:
                score += 50
                
            # 2. Engagement
            score += post.likes.count() * 2
            score += post.comments.count() * 5
            
            # 3. Interest Match (+10 per tag)
            author_interests = set(post.author.interests.values_list('id', flat=True))
            shared = user_interests.intersection(author_interests)
            score += len(shared) * 10
            
            # 4. Freshness (Subtract score for age in hours)
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 2 # Slight decay
            
            scored_posts.append({
                'post': post,
                'score': score
            })
            
        # Sort by score descending
        scored_posts.sort(key=lambda x: x['score'], reverse=True)
        return [item['post'] for item in scored_posts[:limit]]

    @staticmethod
    def get_user_posts(profile, limit=20):
        """Returns posts by a specific user."""
        return Post.objects.filter(author=profile).order_by('-created_at')[:limit]

    @staticmethod
    def get_trending_feed(limit=20):
        """
        Returns posts ranked globally by engagement and freshness, 
        ignoring user's specific location.
        """
        now = timezone.now()
        posts = Post.objects.filter(expires_at__gt=now).select_related('author', 'location').prefetch_related('likes', 'comments')
        
        scored_posts = []
        for post in posts:
            score = 0
            
            # 1. Engagement (Primary for trending)
            score += post.likes.count() * 5 # Higher weight for trending
            score += post.comments.count() * 10
            
            # 2. Freshness decay
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 5 # Faster decay for trending focus
            
            scored_posts.append({
                'post': post,
                'score': score
            })
            
        scored_posts.sort(key=lambda x: x['score'], reverse=True)
        return [item['post'] for item in scored_posts[:limit]]

class ProximityService:
    @staticmethod
    def update_presence(user_profile, lat, lon):
        """
        Checks if user is inside any predefined LocationRoom geofence.
        """
        rooms = LocationRoom.objects.all()
        for room in rooms:
            # Simple distance calculation proxy
            dist_sq = (room.latitude - lat)**2 + (room.longitude - lon)**2
            threshold = (room.radius_meters / 111000)**2
            
            if dist_sq <= threshold:
                user_profile.current_location = room
                user_profile.save()
                return room
        
        user_profile.current_location = None
        user_profile.save()
        return None

class StreakService:
    @staticmethod
    def update_streak(user_profile, location):
        """
        Updates the streak for a user at a specific location when they post.
        """
        if not location:
            return None
            
        today = timezone.now().date()
        yesterday = today - timezone.timedelta(days=1)
        
        streak, created = Streak.objects.get_or_create(
            user=user_profile, 
            location=location,
            defaults={'last_post_date': today, 'count': 1}
        )
        
        if not created:
            if streak.last_post_date == yesterday:
                streak.count += 1
                streak.last_post_date = today
                streak.save()
            elif streak.last_post_date < yesterday:
                streak.count = 1
                streak.last_post_date = today
                streak.save()
            # If already posted today, do nothing
            
        return streak
