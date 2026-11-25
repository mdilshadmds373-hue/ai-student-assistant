from rest_framework import viewsets

from .models import Note, Subject, Task
from .serializers import NoteSerializer, SubjectSerializer, TaskSerializer


class OwnedViewSet(viewsets.ModelViewSet):
    """Har query user se filter hoti hai, aur naya object usi user ka banta hai."""

    model = None

    def get_queryset(self):
        return self.model.objects.filter(user=self.request.user).order_by("-created_at")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class SubjectViewSet(OwnedViewSet):
    model = Subject
    serializer_class = SubjectSerializer


class NoteViewSet(OwnedViewSet):
    model = Note
    serializer_class = NoteSerializer


class TaskViewSet(OwnedViewSet):
    model = Task
    serializer_class = TaskSerializer
