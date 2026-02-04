from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
    RegisterView, FeedView, TrendingFeedView, SuggestedPeopleView, 
    UpdateLocationView, InterestsListView, UpdateInterestsView,
    MyProfileView, ProfileDetailView, UpdateProfileView,
    CreatePostView, LikePostView, CommentPostView, CommentListView, UserStreaksView, UserPostsView,
    ConnectionListView, SendConnectionRequestView, AcceptConnectionView, RejectConnectionView, DisconnectView,
    ConversationListView, ChatMessagesView, SendMessageView,
    BlockUserView, ReportUserView,
    InviteContributorView, ContributeToPostView, CollaborativePostsView, PostContributorsView,
    RegisterDeviceView, PendingConnectionsView, NotificationListView, MarkNotificationReadView,
    GenerateRecoveryCodesView, InitiateRecoveryView, GuardianApprovalView, ResetPasswordRecoveryView,
    ManageGuardiansView, PendingGuardianRequestsView,
    LeaderboardView, TrendingLocallyView, LikeCommentView
)

urlpatterns = [
    # Authentication
    path('auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/recovery/codes/', GenerateRecoveryCodesView.as_view(), name='generate_codes'),
    path('auth/recovery/initiate/', InitiateRecoveryView.as_view(), name='initiate_recovery'),
    path('auth/recovery/approve/', GuardianApprovalView.as_view(), name='approve_recovery'),
    path('auth/recovery/reset/', ResetPasswordRecoveryView.as_view(), name='reset_password_recovery'),
    path('auth/recovery/guardians/', ManageGuardiansView.as_view(), name='manage_guardians'),
    path('auth/recovery/pending-requests/', PendingGuardianRequestsView.as_view(), name='pending_guardian_requests'),
    
    # Profile
    path('profile/me/', MyProfileView.as_view(), name='my_profile'),
    path('profile/<int:pk>/', ProfileDetailView.as_view(), name='profile_detail'),
    path('profile/update/', UpdateProfileView.as_view(), name='update_profile'),
    
    # Feed & Posts
    path('feed/', FeedView.as_view(), name='feed'),
    path('feed/trending/', TrendingFeedView.as_view(), name='trending_feed'),
    path('posts/', CreatePostView.as_view(), name='create_post'),
    path('posts/me/', UserPostsView.as_view(), name='user_posts'),
    path('posts/<int:pk>/like/', LikePostView.as_view(), name='like_post'),
    path('posts/<int:pk>/comment/', CommentPostView.as_view(), name='comment_post'),
    path('posts/<int:pk>/comments/', CommentListView.as_view(), name='post_comments'),
    path('comments/<int:pk>/like/', LikeCommentView.as_view(), name='like_comment'),
    path('streaks/', UserStreaksView.as_view(), name='user_streaks'),
    
    # Discovery
    path('suggested/', SuggestedPeopleView.as_view(), name='suggested'),
    path('location/', UpdateLocationView.as_view(), name='update_location'),
    path('interests/', InterestsListView.as_view(), name='interests_list'),
    path('interests/update/', UpdateInterestsView.as_view(), name='update_interests'),
    path('leaderboard/', LeaderboardView.as_view(), name='leaderboard'),
    path('trending-locally/', TrendingLocallyView.as_view(), name='trending_locally'),
    
    # Connections
    path('connections/', ConnectionListView.as_view(), name='connections_list'),
    path('connections/request/', SendConnectionRequestView.as_view(), name='send_connection'),
    path('connections/<int:pk>/accept/', AcceptConnectionView.as_view(), name='accept_connection'),
    path('connections/<int:pk>/reject/', RejectConnectionView.as_view(), name='reject_connection'),
    path('connections/<int:pk>/disconnect/', DisconnectView.as_view(), name='disconnect_connection'),
    
    # Chat
    path('chat/conversations/', ConversationListView.as_view(), name='conversations'),
    path('chat/<int:user_id>/', ChatMessagesView.as_view(), name='chat_messages'),
    path('chat/<int:user_id>/send/', SendMessageView.as_view(), name='send_message'),
    
    # Safety
    path('users/<int:pk>/block/', BlockUserView.as_view(), name='block_user'),
    path('report/', ReportUserView.as_view(), name='report'),
    
    # Collaborative Posts
    path('posts/<int:pk>/invite/', InviteContributorView.as_view(), name='invite_contributor'),
    path('posts/<int:pk>/contribute/', ContributeToPostView.as_view(), name='contribute_to_post'),
    path('posts/<int:pk>/contributors/', PostContributorsView.as_view(), name='post_contributors'),
    path('posts/collaborative/', CollaborativePostsView.as_view(), name='collaborative_posts'),
    
    # Notifications
    path('notifications/', NotificationListView.as_view(), name='notifications_list'),
    path('notifications/<int:pk>/read/', MarkNotificationReadView.as_view(), name='mark_notification_read'),
    path('notifications/register-device/', RegisterDeviceView.as_view(), name='register_device'),
    path('connections/pending/', PendingConnectionsView.as_view(), name='pending_connections'),
]
