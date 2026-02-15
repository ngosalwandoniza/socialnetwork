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

def get_interest_rarity_weights():
    """
    Returns a mapping of interest_id -> rarity_multiplier.
    Rare interests (few users) get a higher multiplier.
    """
    total_profiles = Profile.objects.count() or 1
    rarity = {}
    
    # Annotate interests with user count
    from .models import Interest
    interests_data = Interest.objects.annotate(user_count=Count('profile'))
    
    for interest in interests_data:
        # If less than 10% of users have this interest, it's "Rare"
        usage_pct = interest.user_count / total_profiles
        if usage_pct < 0.1:
            rarity[interest.id] = 3.0 # 3x boost for rare interests
        elif usage_pct < 0.3:
            rarity[interest.id] = 1.5 # 1.5x for uncommon
        else:
            rarity[interest.id] = 1.0 # Standard
            
    return rarity

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

        interest_weights = get_interest_rarity_weights()
        user_interests = set(user_profile.interests.values_list('id', flat=True))
        now = timezone.now()
        user_loc = user_profile.current_location
        user_lat = user_profile.latitude
        user_lon = user_profile.longitude
        
        scored_candidates = []
        for candidate in candidates:
            score = 0
            
            # 1. New User Boost (Last 48 hours)
            if candidate.user.date_joined > now - timezone.timedelta(hours=48):
                score += 500
            
            # 2. Tiered Proximity Score
            cand_loc = candidate.current_location
            if user_loc and cand_loc:
                if user_loc.id == cand_loc.id:
                    score += 1000  # Exact same room
                elif user_loc.city and cand_loc.city and user_loc.city == cand_loc.city:
                    score += 400   # Same city
            
            # 2b. Roaming Discovery (Coord-based)
            if user_lat and user_lon and candidate.latitude and candidate.longitude:
                dist = haversine_distance(user_lat, user_lon, candidate.latitude, candidate.longitude)
                if dist < 500: # Within 500m
                    score += 800
                elif dist < 2000: # Within 2km
                    score += 300
            
            # 3. Social Gravity Influence
            score += candidate.social_gravity * 30
            
            # 4. Weighted Shared Interests
            candidate_interests = {i.id for i in candidate.interests.all()}
            shared_ids = user_interests.intersection(candidate_interests)
            
            interest_score = 0
            for i_id in shared_ids:
                multiplier = interest_weights.get(i_id, 1.0)
                interest_score += 20 * multiplier
            score += interest_score
            
            # 5. Mutual Connections
            candidate_friend_ids = friend_map.get(candidate.id, set())
            mutuals_count = len(user_friend_ids.intersection(candidate_friend_ids))
            score += mutuals_count * 25
            
            # 6. Exponential Activity Decay
            if candidate.last_active:
                diff_sec = (now - candidate.last_active).total_seconds()
                # 100 points for active now, decaying to 0 over 1 hour
                decay_score = max(0, 100 * (1 - (diff_sec / 3600)))
                score += decay_score
            
            scored_candidates.append({
                'profile': candidate,
                'score': score
            })
            
        # Sort by score
        scored_candidates.sort(key=lambda x: x['score'], reverse=True)
        
        # 7. Exploration Factor: Randomly shuffle the top buffer slightly
        # We take the top limit*1.5 and shuffle them to keep results fresh
        top_pool = scored_candidates[:int(limit * 1.5)]
        import random
        random.shuffle(top_pool)
        
        return [item['profile'] for item in top_pool[:limit]]

class FeedService:
    @staticmethod
    def get_local_feed(user_profile, page=1, page_size=20, shuffle=False):
        """
        Returns posts ranked using optimizations to avoid N+1 queries.
        Handles pagination at the DB level.
        """
        offset = (page - 1) * page_size
        now = timezone.now()
        
        # 1. Fetch a pool for scoring — larger pool when shuffling for more variety
        pool_size = 200 if shuffle else 50
        posts = Post.objects.filter(Q(expires_at__gt=now) | Q(expires_at__isnull=True))\
            .select_related('author', 'location')\
            .annotate(
                likes_count=Count('likes', distinct=True),
                comments_count=Count('comments', distinct=True)
            ).prefetch_related('author__interests')\
            .order_by('-created_at')[offset:offset + pool_size]
        
        user_interests = set(user_profile.interests.values_list('id', flat=True))
        user_loc = user_profile.current_location
        
        scored_posts = []
        for post in posts:
            score = 0
            # ... (scoring logic same as before) ...
            if user_loc and post.location:
                if user_loc.id == post.location.id: score += 500
                elif user_loc.city and post.location.city and user_loc.city == post.location.city: score += 200
            
            score += post.likes_count * 3
            score += post.comments_count * 6
            
            author_interests = {i.id for i in post.author.interests.all()}
            shared = user_interests.intersection(author_interests)
            score += len(shared) * 15
            
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 10
            score += post.author.social_gravity * 10
            
            scored_posts.append({'post': post, 'score': score})
            
        if shuffle:
            import random
            random.shuffle(scored_posts)
        else:
            scored_posts.sort(key=lambda x: x['score'], reverse=True)
            
        return [item['post'] for item in scored_posts[:page_size]]

    @staticmethod
    def get_user_posts(profile, limit=20):
        """Returns posts by a specific user."""
        return Post.objects.filter(author=profile).order_by('-created_at')[:limit]

    @staticmethod
    def get_trending_feed(page=1, page_size=20, shuffle=False):
        """
        Returns trending posts globally with engagement and freshness.
        """
        offset = (page - 1) * page_size
        now = timezone.now()
        pool_size = 200 if shuffle else 50
        posts = Post.objects.filter(Q(expires_at__gt=now) | Q(expires_at__isnull=True))\
            .select_related('author', 'location')\
            .annotate(
                likes_count=Count('likes', distinct=True),
                comments_count=Count('comments', distinct=True)
            ).order_by('-created_at')[offset:offset + pool_size]
        
        scored_posts = []
        for post in posts:
            score = 0
            score += post.likes_count * 5 
            score += post.comments_count * 10
            
            age_hours = (now - post.created_at).total_seconds() / 3600
            score -= age_hours * 5
            
            scored_posts.append({'post': post, 'score': score})
            
        if shuffle:
            import random
            random.shuffle(scored_posts)
        else:
            scored_posts.sort(key=lambda x: x['score'], reverse=True)
            
        return [item['post'] for item in scored_posts[:page_size]]

class ProximityService:
    @staticmethod
    def update_presence(user_profile, lat, lon):
        """
        Checks if user is inside any predefined LocationRoom geofence using Haversine.
        Also updates Profile coordinates for roaming discovery.
        """
        user_profile.latitude = lat
        user_profile.longitude = lon
        user_profile.save(update_fields=['latitude', 'longitude'])
        
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
