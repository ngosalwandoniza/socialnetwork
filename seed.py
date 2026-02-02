import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')
django.setup()

from core.models import Interest, LocationRoom

def seed_data():
    interests = [
        "Gaming", "Study", "Tech", "Music", "Sports", 
        "Creative", "Learning", "Social", "Engineering", "Arts",
        "Entrepreneurship", "Investing", "Crypto", "Remote Work", "Side Hustles",
        "Mental Health", "Yoga", "Skincare", "Sustainable Living", "Hiking", 
        "Travel", "Anime", "Netflix", "K-pop", "Podcasts", 
        "Photography", "Fashion", "Coffee", "Vegan", "Cooking", 
        "Bars", "Self Improvement", "Relationships", "Social Activism"
    ]
    for name in interests:
        Interest.objects.get_or_create(name=name)
        print(f"Seeded interest: {name}")

    locations = [
        {"name": "Main Campus", "lat": -15.395, "lon": 28.320, "radius": 500},
        {"name": "Engineering Block", "lat": -15.398, "lon": 28.325, "radius": 100},
        {"name": "Central Library", "lat": -15.396, "lon": 28.322, "radius": 150},
        {"name": "Student Mall", "lat": -15.400, "lon": 28.330, "radius": 200},
    ]
    for loc in locations:
        LocationRoom.objects.get_or_create(
            name=loc['name'],
            latitude=loc['lat'],
            longitude=loc['lon'],
            radius_meters=loc['radius']
        )
        print(f"Seeded location: {loc['name']}")

if __name__ == "__main__":
    seed_data()
