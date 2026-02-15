"""JWT authentication middleware for Django Channels WebSocket connections."""

from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from django.contrib.auth.models import User
from urllib.parse import parse_qs


class JWTAuthMiddleware(BaseMiddleware):
    """
    Authenticates WebSocket connections using a JWT token passed as a query parameter.
    Usage: ws://host/ws/chat/123/?token=<jwt_access_token>
    """

    async def __call__(self, scope, receive, send):
        # Extract token from query string
        query_string = scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)
        token = query_params.get("token", [None])[0]

        if token:
            scope["user"] = await self.get_user_from_token(token)
        else:
            scope["user"] = AnonymousUser()

        return await super().__call__(scope, receive, send)

    @database_sync_to_async
    def get_user_from_token(self, token_str):
        try:
            access_token = AccessToken(token_str)
            user_id = access_token["user_id"]
            return User.objects.get(id=user_id)
        except Exception:
            return AnonymousUser()
