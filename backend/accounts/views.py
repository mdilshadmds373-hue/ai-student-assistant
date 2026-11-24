from django.contrib.auth import authenticate
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from .models import Profile
from .serializers import RegisterSerializer, UserSerializer


class AuthThrottle(AnonRateThrottle):
    scope = "auth"


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    return Response({"status": "ok", "message": "Backend chal raha hai"})


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AuthThrottle])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    token, _ = Token.objects.get_or_create(user=user)
    return Response(
        {"token": token.key, "user": UserSerializer(user).data},
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AuthThrottle])
def login(request):
    email = str(request.data.get("email", "")).strip().lower()
    password = request.data.get("password", "")
    user = authenticate(request, username=email, password=password)
    if user is None:
        return Response(
            {"detail": "Email ya password ghalat hai."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    Profile.objects.get_or_create(user=user)
    token, _ = Token.objects.get_or_create(user=user)
    return Response({"token": token.key, "user": UserSerializer(user).data})


@api_view(["POST"])
def logout(request):
    request.auth.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET", "PATCH"])
def me(request):
    Profile.objects.get_or_create(user=request.user)
    if request.method == "PATCH":
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
    return Response(UserSerializer(request.user).data)
