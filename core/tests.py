"""
Core App Tests - Beta Readiness Suite
Tests for critical authentication, profile, and connection flows.
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from .models import Profile, Interest, Connection, Post, Notification


class AuthenticationTests(APITestCase):
    """Test authentication flows."""
    
    def setUp(self):
        self.client = APIClient()
        self.register_url = '/api/auth/register/'
        self.token_url = '/api/auth/token/'
    
    def test_user_registration(self):
        """Test new user can register."""
        data = {
            'username': 'testuser',
            'password': 'testpass123',
            'gender': 'M',
            'age': 25
        }
        response = self.client.post(self.register_url, data, format='json')
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_200_OK])
        self.assertTrue(User.objects.filter(username='testuser').exists())
    
    def test_user_login(self):
        """Test user can login and receive tokens."""
        # Create user first
        user = User.objects.create_user(username='loginuser', password='pass123')
        Profile.objects.create(user=user, username='loginuser')
        
        response = self.client.post(self.token_url, {
            'username': 'loginuser',
            'password': 'pass123'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
    
    def test_invalid_login(self):
        """Test invalid credentials fail."""
        response = self.client.post(self.token_url, {
            'username': 'nonexistent',
            'password': 'wrongpass'
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class ProfileTests(APITestCase):
    """Test profile management."""
    
    def setUp(self):
        self.user = User.objects.create_user(username='profileuser', password='test123')
        self.profile = Profile.objects.create(user=self.user, username='profileuser', age=25)
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def test_get_my_profile(self):
        """Test fetching own profile."""
        response = self.client.get('/api/profile/me/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'profileuser')
    
    def test_profile_has_social_gravity(self):
        """Test social gravity is calculated."""
        response = self.client.get('/api/profile/me/')
        self.assertIn('social_gravity', response.data)
        self.assertIsInstance(response.data['social_gravity'], (int, float))
    
    def test_profile_counts(self):
        """Test posts_count and connections_count are returned."""
        response = self.client.get('/api/profile/me/')
        self.assertIn('posts_count', response.data)
        self.assertIn('connections_count', response.data)


class ConnectionTests(APITestCase):
    """Test connection/friend request system."""
    
    def setUp(self):
        self.user1 = User.objects.create_user(username='user1', password='pass123')
        self.profile1 = Profile.objects.create(user=self.user1, username='user1')
        
        self.user2 = User.objects.create_user(username='user2', password='pass123')
        self.profile2 = Profile.objects.create(user=self.user2, username='user2')
        
        self.client = APIClient()
    
    def test_send_connection_request(self):
        """Test sending a connection request."""
        self.client.force_authenticate(user=self.user1)
        response = self.client.post('/api/connections/request/', {
            'receiver_id': self.profile2.id
        })
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_200_OK])
        
        # Verify connection exists
        self.assertTrue(Connection.objects.filter(
            sender=self.profile1, receiver=self.profile2, status='PENDING'
        ).exists())
    
    def test_accept_connection(self):
        """Test accepting a connection request."""
        # Create pending connection
        connection = Connection.objects.create(
            sender=self.profile1, receiver=self.profile2, status='PENDING'
        )
        
        # User2 accepts
        self.client.force_authenticate(user=self.user2)
        response = self.client.post(f'/api/connections/{connection.id}/accept/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        connection.refresh_from_db()
        self.assertEqual(connection.status, 'CONNECTED')
    
    def test_reject_connection(self):
        """Test rejecting a connection request."""
        connection = Connection.objects.create(
            sender=self.profile1, receiver=self.profile2, status='PENDING'
        )
        
        self.client.force_authenticate(user=self.user2)
        response = self.client.post(f'/api/connections/{connection.id}/reject/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class PostTests(APITestCase):
    """Test post creation and interactions."""
    
    def setUp(self):
        self.user = User.objects.create_user(username='poster', password='pass123')
        self.profile = Profile.objects.create(user=self.user, username='poster')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def test_create_text_post(self):
        """Test creating a text post."""
        response = self.client.post('/api/posts/', {
            'content_text': 'Hello, world!'
        })
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_200_OK])
        self.assertTrue(Post.objects.filter(author=self.profile).exists())
    
    def test_post_requires_content(self):
        """Test post without content fails."""
        response = self.client.post('/api/posts/', {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_like_post(self):
        """Test liking a post."""
        post = Post.objects.create(author=self.profile, content_text='Likeable post')
        response = self.client.post(f'/api/posts/{post.id}/like/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class NotificationTests(APITestCase):
    """Test notification system."""
    
    def setUp(self):
        self.user = User.objects.create_user(username='notifuser', password='pass123')
        self.profile = Profile.objects.create(user=self.user, username='notifuser')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def test_get_notifications(self):
        """Test fetching notifications."""
        # Create a test notification
        Notification.objects.create(
            recipient=self.profile,
            notification_type='MESSAGE',
            title='New Message',
            body='You have a new message'
        )
        
        response = self.client.get('/api/notifications/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
    
    def test_mark_notification_read(self):
        """Test marking notification as read."""
        notif = Notification.objects.create(
            recipient=self.profile,
            notification_type='MESSAGE',
            title='Test',
            body='Test notification'
        )
        
        response = self.client.post(f'/api/notifications/{notif.id}/read/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        notif.refresh_from_db()
        self.assertTrue(notif.is_read)


class ModelTests(TestCase):
    """Test model methods and properties."""
    
    def test_social_gravity_calculation(self):
        """Test social gravity score is within expected range."""
        user = User.objects.create_user(username='gravityuser', password='pass123')
        profile = Profile.objects.create(user=user, username='gravityuser')
        
        # Should return value between 1.0 and 5.0
        gravity = profile.social_gravity
        self.assertGreaterEqual(gravity, 1.0)
        self.assertLessEqual(gravity, 5.0)
    
    def test_posts_count_property(self):
        """Test posts_count property."""
        user = User.objects.create_user(username='countuser', password='pass123')
        profile = Profile.objects.create(user=user, username='countuser')
        
        # Initially 0
        self.assertEqual(profile.posts_count, 0)
        
        # Create posts
        Post.objects.create(author=profile, content_text='Post 1')
        Post.objects.create(author=profile, content_text='Post 2')
        
        self.assertEqual(profile.posts_count, 2)
    
    def test_connections_count_property(self):
        """Test connections_count property."""
        user1 = User.objects.create_user(username='connuser1', password='pass123')
        profile1 = Profile.objects.create(user=user1, username='connuser1')
        
        user2 = User.objects.create_user(username='connuser2', password='pass123')
        profile2 = Profile.objects.create(user=user2, username='connuser2')
        
        # Initially 0
        self.assertEqual(profile1.connections_count, 0)
        
        # Create connection
        Connection.objects.create(sender=profile1, receiver=profile2, status='CONNECTED')
        
        self.assertEqual(profile1.connections_count, 1)
