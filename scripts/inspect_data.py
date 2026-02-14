from django.contrib.auth.models import User
from core.models import Profile, Post, Connection, ChatMessage
print('Users:', User.objects.count())
print('Profiles:', Profile.objects.count())
print('Posts:', Post.objects.count())
print('Connections:', Connection.objects.count())
print('ChatMessages:', ChatMessage.objects.count())
