from rest_framework import serializers

from .models import Note, Subject, Task


class OwnedSerializer(serializers.ModelSerializer):
    """subject dropdown sirf current user ke subjects tak mehdood rakhta hai."""

    def get_fields(self):
        fields = super().get_fields()
        request = self.context.get("request")
        if request and "subject" in fields:
            fields["subject"].queryset = Subject.objects.filter(user=request.user)
        return fields


class SubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subject
        fields = ["id", "name", "code", "created_at"]
        read_only_fields = ["id", "created_at"]


class NoteSerializer(OwnedSerializer):
    class Meta:
        model = Note
        fields = ["id", "subject", "title", "content", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class TaskSerializer(OwnedSerializer):
    class Meta:
        model = Task
        fields = ["id", "subject", "title", "due_date", "priority", "is_done", "created_at"]
        read_only_fields = ["id", "created_at"]
