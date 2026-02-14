import os
import django
import math
import sys

# Setup Django
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')
django.setup()

from core.models import Profile, LocationRoom, Connection, Interest, User
from core.services import haversine_distance, ProximityService, MatchService
from django.utils import timezone

def test_haversine():
    print("--- Testing Haversine Accuracy ---")
    # Lusaka to Kitwe (roughly 280km air distance)
    lusaka = (-15.3875, 28.3228)
    kitwe = (-12.7983, 28.2325)
    
    dist = haversine_distance(lusaka[0], lusaka[1], kitwe[0], kitwe[1])
    print(f"Distance Lusaka to Kitwe: {dist/1000:.2f} km")
    # Expected is ~288km.
    if 280000 < dist < 300000:
        print("[OK] Haversine distance is accurate.")
    else:
        print("[FAIL] Haversine distance seems off.")

def verify_tiered_matching():
    print("\n--- Testing Tiered Matching Logic ---")
    # Setup some test data
    # Delete existing test data if any
    User.objects.filter(username__startswith='test_user_').delete()
    LocationRoom.objects.filter(name__startswith='Test Room').delete()

    # Create rooms
    room_a = LocationRoom.objects.create(name="Test Room A", city="Lusaka", region="Lusaka", latitude=-15.4, longitude=28.3, radius_meters=500)
    room_b = LocationRoom.objects.create(name="Test Room B", city="Lusaka", region="Lusaka", latitude=-15.41, longitude=28.31, radius_meters=500)
    room_c = LocationRoom.objects.create(name="Test Room C", city="Ndola", region="Copperbelt", latitude=-12.9, longitude=28.6, radius_meters=500)

    # Create users
    u_main = User.objects.create_user(username='test_user_main')
    p_main = Profile.objects.create(user=u_main, username='MainUser', current_location=room_a)

    u1 = User.objects.create_user(username='test_user_room')
    p1 = Profile.objects.create(user=u1, username='SameRoomUser', current_location=room_a)

    u2 = User.objects.create_user(username='test_user_city')
    p2 = Profile.objects.create(user=u2, username='SameCityUser', current_location=room_b)

    u3 = User.objects.create_user(username='test_user_region')
    p3 = Profile.objects.create(user=u3, username='SameRegionUser', current_location=room_c)

    # Test suggestions
    suggestions = MatchService.get_suggested_people(p_main)
    usernames = [p.username for p in suggestions]
    print(f"Suggestions for {p_main.username} (Location: {room_a}):")
    for i, name in enumerate(usernames):
        print(f"{i+1}. {name}")

    if 'SameRoomUser' in usernames and usernames.index('SameRoomUser') == 0:
        print("[OK] Tier 1 (Same Room) correctly ranked first.")
    
    if 'SameCityUser' in usernames:
        print("[OK] Tier 2 (Same City) correctly suggested.")

    # Cleanup
    User.objects.filter(username__startswith='test_user_').delete()
    LocationRoom.objects.filter(name__startswith='Test Room').delete()

if __name__ == "__main__":
    test_haversine()
    verify_tiered_matching()
