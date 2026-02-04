import math
from django.utils import timezone
from .models import Profile, LocationRoom, Post, Connection, Streak
from django.db import models
from django.db.models import Count, Q

def haversine_distance(lat1, lon1, lat2, lon2):
    """
    Calculates the great-circle distance between two points in meters.
    """
    R = 6371000 # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    
    a = math.sin(dphi / 2)**2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

class MatchService:
    @staticmethod
    def get_suggested_people(user_profile, limit=10):
        """
        Optimized version: Fetches candidates and connection data in bulk to avoid N+1 queries.
        """
        # 1. Identity blocked and already connected users in one go
        connections = Connection.objects.filter(
            Q(sender=user_profile) | Q(receiver=user_profile)
        ).values('sender_id', 'receiver_id', 'status')
        
        blocked_ids = set()
        connected_ids = set()
        for conn in connections:
            other_id = conn['sender_id'] if conn['sender_id'] != user_profile.id else conn['receiver_id']
            if conn['status'] == 'BLOCKED':
                blocked_ids.add(other_id)
            elif conn['status'] == 'CONNECTED':
                connected_ids.add(other_id)
        
        exclude_ids = blocked_ids | {user_profile.id}
        
        # 2. Query candidates with necessary related data prefetched
        candidates = Profile.objects.filter(is_discovery_on=True).exclude(id__in=exclude_ids)\
            .select_related('user', 'current_location')\
            .prefetch_related('interests')[:limit * 10] # Fetch a buffer for scoring
        
        # 3. Pre-fetch connections of all candidates in bulk for mutual connection count
        candidate_ids = [c.id for c in candidates]
        all_candidate_connections = Connection.objects.filter(
            Q(sender_id__in=candidate_ids) | Q(receiver_id__in=candidate_ids),
            status='CONNECTED'
        ).values('sender_id', 'receiver_id')
        
        # Map of profile_id -> set of friend_ids
        friend_map = {cid: set() for cid in candidate_ids}
        for conn in all_candidate_connections:
            s_id, r_id = conn['sender_id'], conn['receiver_id']
            if s_id in friend_map: friend_map[s_id].add(r_id)
            if r_id in friend_map: friend_map[r_id].add(s_id)

        user_friend_ids = connected_ids
        current_interests = set(user_profile.interests.values_list('id', flat=True))
        now = timezone.now()
        user_loc = user_profile.current_location
        
        scored_candidates = []
        for candidate in candidates:
            score = 0
            
            # 1. New User Boost
            if candidate.user.date_joined > now - timezone.timedelta(hours=48):
                score += 500
            
            # 2. Tiered Location Score
            cand_loc = candidate.current_location
            if user_loc and cand_loc:
                if user_loc.id == cand_loc.id:
                    score += 1000  # Exact same room
                elif user_loc.city and cand_loc.city and user_loc.city == cand_loc.city:
                    score += 400   # Same city
                elif user_loc.region and cand_loc.region and user_loc.region == cand_loc.region:
                    score += 200   # Same region
            
            # 3. Social Gravity Influence
            score += candidate.social_gravity * 30
            
            # 4. Shared Interests
            candidate_interests = {i.id for i in candidate.interests.all()}
            shared_interests_count = len(current_interests.intersection(candidate_interests))
            score += shared_interests_count * 20
            
            # 5. Mutual Connections
            candidate_friend_ids = friend_map.get(candidate.id, set())
            mutuals_count = len(user_friend_ids.intersection(candidate_friend_ids))
            score += mutuals_count * 25
            
            # 6. Recency
            if candidate.last_active > now - timezone.timedelta(minutes=30):
                score += 50

            scored_candidates.append({
                'profile': candidate,
                'score': score
            })
            
        scored_candidates.sort(key=lambda x: x['score'], reverse=True)
        return [item['profile'] for item in scored_candidates[:limit]]

class FeedService:
    @staticmethod
    def get_local_feed(user_profile, limit=20):
        """
        Returns posts ranked using optimizations to avoid N+1 queries.
        """
        now = timezone.now()
        # Use annotation to fetch counts in the main query
        posts = Post.objects.filter(Q(expires_at__gt=now) | Q(expires_at__isnull=True))\
            .select_related('author', 'location')\
            .annotate(
                likes_count=Count('likes', distinct=True),
                comments_count=Count('comments', distinct=True)
            ).prefetch_related('author__interests')
        
        user_interests = set(user_profile.interests.values_list('id', flat=True))
        user_loc = user_profile.current_location
        
        scored_posts = []
        for post in posts:
            score = 0
            
            # 1. Tiered Location Boost
            if user_loc and post.location:
                if user_loc.id == post.location.id:
                    score += 500  # Same room
                elif user_loc.city and post.location.city and user_loc.city == post.location.city:
                    score += 200  # Same city
                elif user_loc.region and post.location.region and user_loc.region == post.location.region:
                    score += 100  # Same region
            
            # 2. Engagement
            score += post.likes_count * 3
            score += post.comments_count * 6
            
            # 3. Interest Match
            author_interests = {i.id for i in post.author.interests.all()}
            shared = user_interests.intersection(author_interests)
            score += len(shared) * 15
            
            # 4. Freshness 
            # Posts are ephemeral (24h), so we score heavily on recency
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 10 # -10 points per hour age
            
            # 5. Social Gravity of Author
            score += post.author.social_gravity * 10
            
            scored_posts.append({
                'post': post,
                'score': score
            })
            
        scored_posts.sort(key=lambda x: x['score'], reverse=True)
        return [item['post'] for item in scored_posts[:limit]]

    @staticmethod
    def get_user_posts(profile, limit=20):
        """Returns posts by a specific user."""
        return Post.objects.filter(author=profile).order_by('-created_at')[:limit]

    @staticmethod
    def get_trending_feed(limit=20):
        """
        Returns trending posts globally with engagement and freshness.
        """
        now = timezone.now()
        posts = Post.objects.filter(Q(expires_at__gt=now) | Q(expires_at__isnull=True))\
            .select_related('author', 'location')\
            .annotate(
                likes_count=Count('likes', distinct=True),
                comments_count=Count('comments', distinct=True)
            )
        
        scored_posts = []
        for post in posts:
            score = 0
            
            # 1. Engagement
            score += post.likes_count * 5 
            score += post.comments_count * 10
            
            # 2. Freshness decay
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 5
            
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
        Checks if user is inside any predefined LocationRoom geofence using Haversine.
        """
        rooms = LocationRoom.objects.all()
        best_room = None
        min_dist = float('inf')
        
        # Bounding box optimization (1 degree latitude is approx 111km)
        # We only check Haversine if within roughly 0.1 degree (11km)
        for room in rooms:
            if abs(room.latitude - lat) > 0.1 or abs(room.longitude - lon) > 0.1:
                continue
                
            dist_m = haversine_distance(lat, lon, room.latitude, room.longitude)
            
            if dist_m <= room.radius_meters:
                if dist_m < min_dist:
                    min_dist = dist_m
                    best_room = room
        
        if best_room:
            user_profile.current_location = best_room
            user_profile.save()
            return best_room
        
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
