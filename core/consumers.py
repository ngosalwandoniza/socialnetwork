"""WebSocket consumers for real-time chat functionality."""

import json
from channels.generic.websocket import AsyncWebSocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from .models import ChatMessage, Profile, Notification
from .serializers import ChatMessageSerializer


class ChatConsumer(AsyncWebSocketConsumer):
    """
    Handles real-time chat via WebSocket.
    
    Each user gets their own channel group: 'chat_<profile_id>'
    When a message is sent, it is saved to DB and broadcast to both
    the sender's and receiver's groups for instant delivery.
    """

    async def connect(self):
        self.user = self.scope.get("user")
        
        if isinstance(self.user, AnonymousUser) or not self.user:
            await self.close()
            return

        self.profile = await self.get_profile(self.user)
        if not self.profile:
            await self.close()
            return

        # Join user's personal channel group
        self.group_name = f"chat_{self.profile.id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        """Handle incoming messages from the WebSocket client."""
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({"error": "Invalid JSON"}))
            return

        msg_type = data.get("type", "chat_message")

        if msg_type == "chat_message":
            await self.handle_chat_message(data)
        elif msg_type == "mark_read":
            await self.handle_mark_read(data)
        elif msg_type == "typing":
            await self.handle_typing(data)

    async def handle_chat_message(self, data):
        """Save a text message to DB and broadcast to both sender + receiver."""
        receiver_id = data.get("receiver_id")
        content = data.get("content", "").strip()

        if not receiver_id or not content:
            await self.send(text_data=json.dumps({"error": "receiver_id and content are required"}))
            return

        # Save to database
        message_data = await self.save_message(receiver_id, content)
        if not message_data:
            await self.send(text_data=json.dumps({"error": "Failed to save message"}))
            return

        # Broadcast to receiver's channel group
        receiver_group = f"chat_{receiver_id}"
        await self.channel_layer.group_send(
            receiver_group,
            {
                "type": "chat.message",
                "message": message_data,
            }
        )

        # Also send confirmation back to sender
        await self.send(text_data=json.dumps({
            "type": "message_sent",
            "message": message_data,
        }))

    async def handle_mark_read(self, data):
        """Mark all messages from a sender as read."""
        sender_id = data.get("sender_id")
        if sender_id:
            count = await self.mark_messages_read(sender_id)
            await self.send(text_data=json.dumps({
                "type": "messages_read",
                "sender_id": sender_id,
                "count": count,
            }))

    async def handle_typing(self, data):
        """Broadcast typing indicator to the other user."""
        receiver_id = data.get("receiver_id")
        if receiver_id:
            receiver_group = f"chat_{receiver_id}"
            await self.channel_layer.group_send(
                receiver_group,
                {
                    "type": "chat.typing",
                    "sender_id": self.profile.id,
                    "sender_name": self.profile.username,
                }
            )

    # ─── Channel Layer Event Handlers ───

    async def chat_message(self, event):
        """Called when a message is received from the channel layer."""
        await self.send(text_data=json.dumps({
            "type": "new_message",
            "message": event["message"],
        }))

    async def chat_typing(self, event):
        """Called when a typing indicator is received."""
        await self.send(text_data=json.dumps({
            "type": "typing",
            "sender_id": event["sender_id"],
            "sender_name": event["sender_name"],
        }))

    # ─── Database Operations (sync → async) ───

    @database_sync_to_async
    def get_profile(self, user):
        try:
            return user.profile
        except Profile.DoesNotExist:
            return None

    @database_sync_to_async
    def save_message(self, receiver_id, content):
        try:
            receiver = Profile.objects.get(pk=receiver_id)
            message = ChatMessage.objects.create(
                sender=self.profile,
                receiver=receiver,
                content=content,
            )
            # Create notification
            preview = content[:50]
            Notification.objects.create(
                recipient=receiver,
                sender=self.profile,
                notification_type='MESSAGE',
                title=f'New message from {self.profile.username}',
                body=preview + ('...' if len(content) > 50 else '')
            )
            serializer = ChatMessageSerializer(message)
            return serializer.data
        except Profile.DoesNotExist:
            return None

    @database_sync_to_async
    def mark_messages_read(self, sender_id):
        return ChatMessage.objects.filter(
            sender_id=sender_id,
            receiver=self.profile,
            is_read=False,
        ).update(is_read=True)
