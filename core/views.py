import secrets
import string
from datetime import timedelta
from django.utils import timezone
from django.contrib.auth.hashers import make_password, check_password
from rest_framework import status, views, response, permissions
from rest_framework.parsers import MultiPartParser, FormParser
from django.db.models import Q, Max
from .serializers import (
    RegistrationSerializer, ProfileSerializer, PostSerializer, 
    LocationRoomSerializer, ConnectionSerializer, ChatMessageSerializer,
    CommentSerializer, LikeSerializer, StreakSerializer, NotificationSerializer
)
from .models import (
    Profile, Post, LocationRoom, Interest, Connection, ChatMessage, 
    Like, Comment, Streak, Notification, RecoveryCode, RecoveryGuardian, RecoveryRequest
)
from .services import MatchService, FeedService, ProximityService, StreakService


class RegisterView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return response.Response({
                "message": "User registered successfully",
                "profile": ProfileSerializer(user.profile).data
            }, status=status.HTTP_201_CREATED)
        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyProfileView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        serializer = ProfileSerializer(profile, context={'request': request})
        return response.Response(serializer.data)


class ProfileDetailView(views.APIView):
    def get(self, request, pk):
        try:
            profile = Profile.objects.get(pk=pk)
            serializer = ProfileSerializer(profile, context={'request': request})
            return response.Response(serializer.data)
        except Profile.DoesNotExist:
            return response.Response({"error": "Profile not found"}, status=status.HTTP_404_NOT_FOUND)


class UpdateProfileView(views.APIView):
    parser_classes = [MultiPartParser, FormParser]
    
    def put(self, request):
        profile = request.user.profile
        serializer = ProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return response.Response(serializer.data)
        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class FeedView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        posts = FeedService.get_local_feed(profile)
        serializer = PostSerializer(posts, many=True, context={'request': request})
        return response.Response(serializer.data)


class TrendingFeedView(views.APIView):
    def get(self, request):
        posts = FeedService.get_trending_feed()
        serializer = PostSerializer(posts, many=True, context={'request': request})
        return response.Response(serializer.data)


class CreatePostView(views.APIView):
    parser_classes = [MultiPartParser, FormParser]
    
    def post(self, request):
        profile = request.user.profile
        serializer = PostSerializer(data=request.data)
        if serializer.is_valid():
            post = serializer.save(author=profile, location=profile.current_location)
            
            # Update streak
            if profile.current_location:
                StreakService.update_streak(profile, profile.current_location)
                
            return response.Response(PostSerializer(post).data, status=status.HTTP_201_CREATED)
        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LikePostView(views.APIView):
    def post(self, request, pk):
        try:
            post = Post.objects.get(pk=pk)
            profile = request.user.profile
            like, created = Like.objects.get_or_create(user=profile, post=post)
            
            if not created:
                like.delete()
                return response.Response({"message": "Post unliked", "liked": False})
            
            return response.Response({"message": "Post liked", "liked": True})
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)


class CommentPostView(views.APIView):
    def post(self, request, pk):
        try:
            post = Post.objects.get(pk=pk)
            profile = request.user.profile
            content = request.data.get('content', '')
            
            if not content:
                return response.Response({"error": "Comment content required"}, status=status.HTTP_400_BAD_REQUEST)
                
            comment = Comment.objects.create(user=profile, post=post, content=content)
            serializer = CommentSerializer(comment)
            return response.Response(serializer.data, status=status.HTTP_201_CREATED)
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)


class CommentListView(views.APIView):
    def get(self, request, pk):
        try:
            post = Post.objects.get(pk=pk)
            comments = post.comments.all().order_by('-created_at')
            serializer = CommentSerializer(comments, many=True)
            return response.Response(serializer.data)
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)


class UserStreaksView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        streaks = Streak.objects.filter(user=profile)
        serializer = StreakSerializer(streaks, many=True)
        return response.Response(serializer.data)


class UserPostsView(views.APIView):
    def get(self, request):
        user_id = request.query_params.get('user_id')
        if user_id:
            try:
                profile = Profile.objects.get(pk=user_id)
            except Profile.DoesNotExist:
                return response.Response({"error": "Profile not found"}, status=status.HTTP_404_NOT_FOUND)
        else:
            profile = request.user.profile
            
        posts = FeedService.get_user_posts(profile)
        serializer = PostSerializer(posts, many=True, context={'request': request})
        return response.Response(serializer.data)


class SuggestedPeopleView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        suggestions = MatchService.get_suggested_people(profile)
        
        # Get user's current connections for mutual connection calculation
        user_connections = set(Connection.objects.filter(
            Q(sender=profile, status='CONNECTED') | Q(receiver=profile, status='CONNECTED')
        ).values_list('sender_id', 'receiver_id'))
        user_friend_ids = {sid if sid != profile.id else rid for sid, rid in user_connections}
        
        for cand in suggestions:
            # Mutuals
            cand_connections = set(Connection.objects.filter(
                Q(sender=cand, status='CONNECTED') | Q(receiver=cand, status='CONNECTED')
            ).values_list('sender_id', 'receiver_id'))
            cand_friend_ids = {sid if sid != cand.id else rid for sid, rid in cand_connections}
            cand.mutual_connections_count = len(user_friend_ids.intersection(cand_friend_ids))
            
            # Shared Room
            if profile.current_location and cand.current_location == profile.current_location:
                cand.shared_room_name = profile.current_location.name
            else:
                cand.shared_room_name = None
                
        serializer = ProfileSerializer(suggestions, many=True, context={'request': request})
        return response.Response(serializer.data)


class DisconnectView(views.APIView):
    def post(self, request, pk):
        profile = request.user.profile
        try:
            other = Profile.objects.get(pk=pk)
            Connection.objects.filter(
                Q(sender=profile, receiver=other) | Q(sender=other, receiver=profile)
            ).delete()
            return response.Response({"message": "Successfully disconnected"})
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)


class UpdateLocationView(views.APIView):
    def post(self, request):
        lat = request.data.get('latitude')
        lon = request.data.get('longitude')
        if lat is None or lon is None:
            return response.Response({"error": "Latitude and Longitude required"}, status=status.HTTP_400_BAD_REQUEST)
        
        room = ProximityService.update_presence(request.user.profile, float(lat), float(lon))
        return response.Response({
            "message": "Location updated",
            "current_location": room.name if room else None
        })


class InterestsListView(views.APIView):
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        interests = Interest.objects.all()
        return response.Response([{"id": i.id, "name": i.name} for i in interests])


class UpdateInterestsView(views.APIView):
    def post(self, request):
        interest_ids = request.data.get('interest_ids', [])
        profile = request.user.profile
        profile.interests.set(interest_ids)
        return response.Response({"message": "Interests updated"})


# Connection Views
class ConnectionListView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        connections = Connection.objects.filter(
            Q(sender=profile, status='CONNECTED') | Q(receiver=profile, status='CONNECTED')
        )
        serializer = ConnectionSerializer(connections, many=True)
        return response.Response(serializer.data)


class SendConnectionRequestView(views.APIView):
    def post(self, request):
        profile = request.user.profile
        receiver_id = request.data.get('receiver_id')
        
        try:
            receiver = Profile.objects.get(pk=receiver_id)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        
        if profile.id == receiver.id:
            return response.Response({"error": "Cannot connect with yourself"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if connection already exists
        existing = Connection.objects.filter(
            Q(sender=profile, receiver=receiver) | Q(sender=receiver, receiver=profile)
        ).first()
        
        if existing:
            return response.Response({
                "message": "Connection already exists",
                "status": existing.status
            })
        
        connection = Connection.objects.create(sender=profile, receiver=receiver, status='PENDING')
        
        # Log Notification
        Notification.objects.create(
            recipient=receiver,
            sender=profile,
            notification_type='CONNECTION_REQUEST',
            title='New Connection Request',
            body=f'{profile.username} wants to connect with you!'
        )
        
        serializer = ConnectionSerializer(connection)
        return response.Response(serializer.data, status=status.HTTP_201_CREATED)


class AcceptConnectionView(views.APIView):
    def post(self, request, pk):
        profile = request.user.profile
        try:
            connection = Connection.objects.get(pk=pk, receiver=profile, status='PENDING')
            connection.status = 'CONNECTED'
            connection.save()
            
            # Log Notification
            Notification.objects.create(
                recipient=connection.sender,
                sender=profile,
                notification_type='CONNECTION_ACCEPTED',
                title='Request Accepted',
                body=f'{profile.username} accepted your connection request!'
            )
            
            serializer = ConnectionSerializer(connection)
            return response.Response(serializer.data)
        except Connection.DoesNotExist:
            return response.Response({"error": "Connection request not found"}, status=status.HTTP_404_NOT_FOUND)


class RejectConnectionView(views.APIView):
    def post(self, request, pk):
        profile = request.user.profile
        try:
            connection = Connection.objects.get(pk=pk, receiver=profile, status='PENDING')
            connection.delete()
            return response.Response({"message": "Connection rejected"})
        except Connection.DoesNotExist:
            return response.Response({"error": "Connection request not found"}, status=status.HTTP_404_NOT_FOUND)


# Chat Views
class ConversationListView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        
        # Get all unique conversation partners
        sent_to = ChatMessage.objects.filter(sender=profile).values('receiver').annotate(last_msg=Max('timestamp'))
        received_from = ChatMessage.objects.filter(receiver=profile).values('sender').annotate(last_msg=Max('timestamp'))
        
        # Combine and get unique users
        partner_ids = set()
        conversations = []
        
        for msg in sent_to:
            partner_ids.add(msg['receiver'])
        for msg in received_from:
            partner_ids.add(msg['sender'])
        
        for partner_id in partner_ids:
            partner = Profile.objects.get(pk=partner_id)
            last_message = ChatMessage.objects.filter(
                Q(sender=profile, receiver=partner) | Q(sender=partner, receiver=profile)
            ).order_by('-timestamp').first()
            
            unread_count = ChatMessage.objects.filter(
                sender=partner, receiver=profile, is_read=False
            ).count()
            
            conversations.append({
                'partner_id': partner.id,
                'partner_name': partner.username,
                'partner_pic': partner.profile_picture.url if partner.profile_picture else None,
                'last_message': last_message.content if last_message else '',
                'last_timestamp': last_message.timestamp if last_message else None,
                'unread_count': unread_count
            })
        
        # Sort by last message timestamp
        conversations.sort(key=lambda x: x['last_timestamp'] or '', reverse=True)
        return response.Response(conversations)


class ChatMessagesView(views.APIView):
    def get(self, request, user_id):
        profile = request.user.profile
        try:
            other_user = Profile.objects.get(pk=user_id)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        
        messages = ChatMessage.objects.filter(
            Q(sender=profile, receiver=other_user) | Q(sender=other_user, receiver=profile)
        ).order_by('timestamp')
        
        # Mark messages as read
        ChatMessage.objects.filter(sender=other_user, receiver=profile, is_read=False).update(is_read=True)
        
        serializer = ChatMessageSerializer(messages, many=True)
        return response.Response(serializer.data)


class SendMessageView(views.APIView):
    def post(self, request, user_id):
        profile = request.user.profile
        try:
            receiver = Profile.objects.get(pk=user_id)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        
        content = request.data.get('content', '')
        if not content:
            return response.Response({"error": "Message content required"}, status=status.HTTP_400_BAD_REQUEST)
        
        message = ChatMessage.objects.create(sender=profile, receiver=receiver, content=content)
        
        # Log Notification
        Notification.objects.create(
            recipient=receiver,
            sender=profile,
            notification_type='MESSAGE',
            title=f'New message from {profile.username}',
            body=content[:50] + ('...' if len(content) > 50 else '')
        )
        
        serializer = ChatMessageSerializer(message)
        return response.Response(serializer.data, status=status.HTTP_201_CREATED)


class DeleteAccountView(views.APIView):
    def post(self, request):
        user = request.user
        # All related data (Profile, Posts, etc) will be deleted due to CASCADE
        user.delete()
        return response.Response({"message": "Account permanently deleted"}, status=status.HTTP_204_NO_CONTENT)


class BlockUserView(views.APIView):
    def post(self, request, pk):
        """Block a user. Creates or updates connection status to BLOCKED."""
        profile = request.user.profile
        try:
            target = Profile.objects.get(pk=pk)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        
        if profile.id == target.id:
            return response.Response({"error": "Cannot block yourself"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if connection exists in either direction
        connection = Connection.objects.filter(
            Q(sender=profile, receiver=target) | Q(sender=target, receiver=profile)
        ).first()
        
        if connection:
            connection.status = 'BLOCKED'
            # Ensure the blocker is the sender so we know who initiated the block
            if connection.receiver == profile:
                connection.sender, connection.receiver = connection.receiver, connection.sender
            connection.save()
        else:
            connection = Connection.objects.create(
                sender=profile,
                receiver=target,
                status='BLOCKED'
            )
        
        return response.Response({"message": f"User {target.username} has been blocked"})
    
    def delete(self, request, pk):
        """Unblock a user."""
        profile = request.user.profile
        try:
            target = Profile.objects.get(pk=pk)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        
        # Find and delete any BLOCKED connection
        Connection.objects.filter(
            Q(sender=profile, receiver=target, status='BLOCKED') | 
            Q(sender=target, receiver=profile, status='BLOCKED')
        ).delete()
        
        return response.Response({"message": f"User {target.username} has been unblocked"})


class ReportUserView(views.APIView):
    def post(self, request):
        """Report a user or post for policy violation."""
        from .models import Report
        
        profile = request.user.profile
        reported_user_id = request.data.get('reported_user_id')
        reported_post_id = request.data.get('reported_post_id')
        reason = request.data.get('reason')
        details = request.data.get('details', '')
        
        if not reported_user_id:
            return response.Response({"error": "reported_user_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        if not reason:
            return response.Response({"error": "reason is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        valid_reasons = ['SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'FAKE', 'OTHER']
        if reason not in valid_reasons:
            return response.Response({"error": f"Invalid reason. Must be one of: {valid_reasons}"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            reported_user = Profile.objects.get(pk=reported_user_id)
        except Profile.DoesNotExist:
            return response.Response({"error": "Reported user not found"}, status=status.HTTP_404_NOT_FOUND)
        
        reported_post = None
        if reported_post_id:
            try:
                reported_post = Post.objects.get(pk=reported_post_id)
            except Post.DoesNotExist:
                return response.Response({"error": "Reported post not found"}, status=status.HTTP_404_NOT_FOUND)
        
        if profile.id == reported_user.id:
            return response.Response({"error": "Cannot report yourself"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Create the report
        Report.objects.create(
            reporter=profile,
            reported_user=reported_user,
            reported_post=reported_post,
            reason=reason,
            details=details
        )
        
        return response.Response({"message": "Report submitted successfully. Our team will review it."}, status=status.HTTP_201_CREATED)


# Collaborative Posts Views
class InviteContributorView(views.APIView):
    def post(self, request, pk):
        """Invite a friend to contribute to your post."""
        profile = request.user.profile
        contributor_id = request.data.get('contributor_id')
        
        try:
            post = Post.objects.get(pk=pk, author=profile)
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found or you're not the author"}, status=status.HTTP_404_NOT_FOUND)
        
        if not contributor_id:
            return response.Response({"error": "contributor_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            contributor = Profile.objects.get(pk=contributor_id)
        except Profile.DoesNotExist:
            return response.Response({"error": "Contributor not found"}, status=status.HTTP_404_NOT_FOUND)
        
        # Check if they're connected
        is_connected = Connection.objects.filter(
            Q(sender=profile, receiver=contributor, status='CONNECTED') |
            Q(sender=contributor, receiver=profile, status='CONNECTED')
        ).exists()
        
        if not is_connected:
            return response.Response({"error": "You can only invite connected friends"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check contributor limit (max 10)
        if post.contributors.count() >= 10:
            return response.Response({"error": "Maximum 10 contributors allowed"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Mark as collaborative and add contributor
        post.is_collaborative = True
        post.save()
        post.contributors.add(contributor)
        
        # Log Notification
        Notification.objects.create(
            recipient=contributor,
            sender=profile,
            notification_type='COLLABORATION',
            title='Collaboration Invite',
            body=f'{profile.username} invited you to collaborate on a moment!'
        )
        
        return response.Response({
            "message": f"{contributor.username} has been invited to contribute",
            "contributors": [{"id": c.id, "username": c.username} for c in post.contributors.all()]
        })


class ContributeToPostView(views.APIView):
    parser_classes = [MultiPartParser, FormParser]
    
    def post(self, request, pk):
        """Add content to a collaborative post as a contributor."""
        profile = request.user.profile
        
        try:
            post = Post.objects.get(pk=pk)
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)
        
        # Check if user is author or contributor
        is_author = post.author == profile
        is_contributor = post.contributors.filter(id=profile.id).exists()
        
        if not (is_author or is_contributor):
            return response.Response({"error": "You're not authorized to contribute to this post"}, status=status.HTTP_403_FORBIDDEN)
        
        # Get content to add
        text = request.data.get('text', '')
        image = request.FILES.get('image')
        
        if not text and not image:
            return response.Response({"error": "Text or image required"}, status=status.HTTP_400_BAD_REQUEST)
        
        # For now, append text to existing content (simple approach)
        # In a more complex system, you'd have a PostContribution model
        if text:
            separator = "\n---\n" if post.content_text else ""
            post.content_text += f"{separator}📝 {profile.username}: {text}"
        
        # If adding image and post doesn't have one, set it
        if image and not post.image:
            post.image = image
        
        post.save()
        
        return response.Response({
            "message": "Contribution added successfully",
            "post": PostSerializer(post).data
        })


class CollaborativePostsView(views.APIView):
    def get(self, request):
        """Get posts where user is a contributor (not author)."""
        profile = request.user.profile
        posts = Post.objects.filter(contributors=profile).order_by('-created_at')
        serializer = PostSerializer(posts, many=True)
        return response.Response(serializer.data)


class PostContributorsView(views.APIView):
    def get(self, request, pk):
        """Get list of contributors for a post."""
        try:
            post = Post.objects.get(pk=pk)
        except Post.DoesNotExist:
            return response.Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)
        
        contributors = post.contributors.all()
        return response.Response({
            "author": {"id": post.author.id, "username": post.author.username},
            "contributors": [{"id": c.id, "username": c.username, "profile_picture": c.profile_picture.url if c.profile_picture else None} for c in contributors],
            "is_collaborative": post.is_collaborative
        })


class RegisterDeviceView(views.APIView):
    def post(self, request):
        fcm_token = request.data.get('fcm_token')
        if not fcm_token:
            return response.Response({"error": "fcm_token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        profile = request.user.profile
        profile.fcm_token = fcm_token
        profile.save()
        return response.Response({"message": "Device registered successfully"})


class PendingConnectionsView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        pending = Connection.objects.filter(receiver=profile, status='PENDING')
        serializer = ConnectionSerializer(pending, many=True)
        return response.Response(serializer.data)


class NotificationListView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        notifications = Notification.objects.filter(recipient=profile).order_by('-created_at')
        serializer = NotificationSerializer(notifications, many=True)
        return response.Response(serializer.data)


class MarkNotificationReadView(views.APIView):
    def post(self, request, pk):
        profile = request.user.profile
        try:
            notification = Notification.objects.get(pk=pk, recipient=profile)
            notification.is_read = True
            notification.save()
            return response.Response({"message": "Notification marked as read"})
        except Notification.DoesNotExist:
            return response.Response({"error": "Notification not found"}, status=status.HTTP_404_NOT_FOUND)


# Password Recovery Views
class GenerateRecoveryCodesView(views.APIView):
    def post(self, request):
        profile = request.user.profile
        RecoveryCode.objects.filter(profile=profile).delete()
        
        new_codes = []
        plain_codes = []
        for _ in range(10):
            plain = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
            plain_codes.append(plain)
            new_codes.append(RecoveryCode(
                profile=profile,
                code_hash=make_password(plain)
            ))
        
        RecoveryCode.objects.bulk_create(new_codes)
        return response.Response({"codes": plain_codes})


class InitiateRecoveryView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = request.data.get('username')
        try:
            profile = Profile.objects.get(username=username)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
            
        token = ''.join(secrets.choice(string.digits) for _ in range(6))
        while RecoveryRequest.objects.filter(token=token).exists():
            token = ''.join(secrets.choice(string.digits) for _ in range(6))
            
        RecoveryRequest.objects.filter(profile=profile, status='PENDING').update(status='EXPIRED')
        
        request_obj = RecoveryRequest.objects.create(
            profile=profile,
            token=token,
            expires_at=timezone.now() + timedelta(hours=2)
        )

        # Notify guardians
        guardians = RecoveryGuardian.objects.filter(profile=profile)
        for g in guardians:
            Notification.objects.create(
                recipient=g.guardian,
                sender=profile,
                notification_type='RECOVERY_VOUCH',
                title='Vouch Requested',
                body=f'{profile.username} needs a security vouch to recover their account.'
            )
        
        return response.Response({
            "message": "Recovery initiated",
            "token": token,
            "expires_at": request_obj.expires_at
        })


class GuardianApprovalView(views.APIView):
    def post(self, request):
        profile = request.user.profile
        token = request.data.get('token')
        
        try:
            req = RecoveryRequest.objects.get(token=token, status='PENDING')
        except RecoveryRequest.DoesNotExist:
            return response.Response({"error": "Invalid or expired recovery token"}, status=status.HTTP_404_NOT_FOUND)
            
        if not RecoveryGuardian.objects.filter(profile=req.profile, guardian=profile).exists():
            return response.Response({"error": "You are not a designated guardian for this user"}, status=status.HTTP_403_FORBIDDEN)
            
        req.approvals.add(profile)
        
        guardian_count = RecoveryGuardian.objects.filter(profile=req.profile).count()
        required = 2 if guardian_count >= 2 else 1
        
        if req.approvals.count() >= required:
            req.status = 'APPROVED'
            req.save()
            return response.Response({"message": "Recovery approved. The user can now reset their password."})
            
        return response.Response({"message": "Approval recorded. Waiting for more guardians."})


class ResetPasswordRecoveryView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = request.data.get('username')
        new_password = request.data.get('password')
        recovery_code = request.data.get('recovery_code') 
        token = request.data.get('token') 
        
        try:
            profile = Profile.objects.get(username=username)
        except Profile.DoesNotExist:
            return response.Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
            
        success = False
        
        if recovery_code:
            codes = RecoveryCode.objects.filter(profile=profile, is_used=False)
            for c in codes:
                if check_password(recovery_code, c.code_hash):
                    c.is_used = True
                    c.save()
                    success = True
                    break
        elif token:
            try:
                req = RecoveryRequest.objects.get(profile=profile, token=token, status='APPROVED')
                if timezone.now() < req.expires_at:
                    req.status = 'COMPLETED'
                    req.save()
                    success = True
            except RecoveryRequest.DoesNotExist:
                pass
                
        if success:
            user = profile.user
            user.set_password(new_password)
            user.save()
            return response.Response({"message": "Password reset successfully"})
            
        return response.Response({"error": "Invalid recovery data or approvals incomplete"}, status=status.HTTP_400_BAD_REQUEST)


class ManageGuardiansView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        guardians = RecoveryGuardian.objects.filter(profile=profile)
        return response.Response([
            {"id": g.guardian.id, "username": g.guardian.username} for g in guardians
        ])

    def post(self, request):
        profile = request.user.profile
        guardian_ids = request.data.get('guardian_ids', [])
        
        friends_ids = set()
        connections = Connection.objects.filter(
            Q(sender=profile, status='CONNECTED') | Q(receiver=profile, status='CONNECTED')
        )
        for conn in connections:
            friends_ids.add(conn.sender_id if conn.sender_id != profile.id else conn.receiver_id)
            
        valid_guardians = [gid for gid in guardian_ids if gid in friends_ids]
        
        RecoveryGuardian.objects.filter(profile=profile).delete()
        for gid in valid_guardians:
            RecoveryGuardian.objects.create(profile=profile, guardian_id=gid)
            
        return response.Response({"message": "Guardians updated successfully"})


class PendingGuardianRequestsView(views.APIView):
    def get(self, request):
        profile = request.user.profile
        guardian_for_profiles = RecoveryGuardian.objects.filter(guardian=profile).values_list('profile', flat=True)
        pending = RecoveryRequest.objects.filter(
            profile_id__in=guardian_for_profiles, 
            status='PENDING',
            expires_at__gt=timezone.now()
        ).exclude(approvals=profile)
        
        return response.Response([{
            "id": r.id,
            "username": r.profile.username,
            "token": r.token,
            "expires_at": r.expires_at
        } for r in pending])
