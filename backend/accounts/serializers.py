from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Profile

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(max_length=150)
    password = serializers.CharField(write_only=True, min_length=8)

    def validate_email(self, value):
        value = value.lower()
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Is email se account pehle se maujood hai.")
        return value

    def validate_password(self, value):
        validate_password(value)
        return value

    def create(self, data):
        user = User.objects.create_user(
            username=data["email"],
            email=data["email"],
            password=data["password"],
            first_name=data["full_name"],
        )
        Profile.objects.create(user=user)
        return user


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = ["university", "program", "semester", "language"]


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="first_name", max_length=150)
    profile = ProfileSerializer()

    class Meta:
        model = User
        fields = ["id", "email", "full_name", "profile"]
        read_only_fields = ["id", "email"]

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("profile", {})
        for key, value in validated_data.items():
            setattr(instance, key, value)
        instance.save()
        profile, _ = Profile.objects.get_or_create(user=instance)
        for key, value in profile_data.items():
            setattr(profile, key, value)
        profile.save()
        return instance
