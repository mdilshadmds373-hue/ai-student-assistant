from django.conf import settings
from django.db import models


class Profile(models.Model):
    LANGUAGES = [("en", "English"), ("ur", "Urdu")]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="profile"
    )
    university = models.CharField(max_length=150, blank=True)
    program = models.CharField(max_length=100, blank=True)
    semester = models.PositiveSmallIntegerField(null=True, blank=True)
    language = models.CharField(max_length=2, choices=LANGUAGES, default="en")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Profile of {self.user.email}"
