"""
ASGI config for latent_backend project.

Includes Django Channels routing for WebSocket support (real-time chat).
"""

import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'latent_backend.settings')

# Initialize Django FIRST so apps are loaded before importing consumers
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from core.middleware import JWTAuthMiddleware
from core.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JWTAuthMiddleware(
        URLRouter(websocket_urlpatterns)
    ),
})
