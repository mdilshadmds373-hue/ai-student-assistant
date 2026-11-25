from django.contrib import admin
from django.urls import include, path

from accounts import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", views.health),
    path("api/auth/register/", views.register),
    path("api/auth/login/", views.login),
    path("api/auth/logout/", views.logout),
    path("api/auth/me/", views.me),
    path("api/", include("academics.urls")),
    path("api/", include("assistant.urls")),
]
