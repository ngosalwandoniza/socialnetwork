import requests
import json

BASE_URL = "http://localhost:8000/api"

def get_token():
    # Attempt to use a test user or just assume the server is running and we need a token
    # For simplicity in this script, we'll try to login as 'admin' if possible
    # In a real test, we'd create a user
    try:
        response = requests.post(f"{BASE_URL}/auth/token/", json={"username": "admin", "password": "password123"})
        return response.json().get('access')
    except:
        return None

def test_leaderboard(token):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/leaderboard/", headers=headers)
    print(f"Leaderboard Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Profiles in Leaderboard: {len(data)}")
        if data:
            print(f"Top user: {data[0].get('username')} - Gravity: {data[0].get('social_gravity')}")

def test_trending_locally(token):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/trending-locally/", headers=headers)
    print(f"Trending Locally Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Trending Post: {data.get('content_text')}")

if __name__ == "__main__":
    token = get_token()
    if token:
        test_leaderboard(token)
        test_trending_locally(token)
    else:
        print("Could not get token. Make sure server is running and user exists.")
