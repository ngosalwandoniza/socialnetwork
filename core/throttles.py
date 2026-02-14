from rest_framework.throttling import AnonRateThrottle

class AuthThrottle(AnonRateThrottle):
    scope = 'auth'

class RecoveryThrottle(AnonRateThrottle):
    scope = 'recovery'
