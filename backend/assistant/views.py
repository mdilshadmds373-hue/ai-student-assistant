from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from .models import Conversation, Message
from .serializers import ConversationDetailSerializer, ConversationSerializer, MessageSerializer
from .services import AIError, call_gemini

MAX_HISTORY = 20
MAX_LENGTH = 4000


class ChatThrottle(UserRateThrottle):
    scope = "chat"


class ConversationViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user).order_by("-updated_at")

    def get_serializer_class(self):
        return ConversationDetailSerializer if self.action == "retrieve" else ConversationSerializer

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=["post"], throttle_classes=[ChatThrottle])
    def send(self, request, pk=None):
        conversation = self.get_object()  # sirf apni conversation milti hai
        content = str(request.data.get("content", "")).strip()
        if not content:
            return Response({"detail": "Message khali hai."}, status=status.HTTP_400_BAD_REQUEST)
        if len(content) > MAX_LENGTH:
            return Response({"detail": f"Message {MAX_LENGTH} characters se chhota rakhein."},
                            status=status.HTTP_400_BAD_REQUEST)

        past = list(conversation.messages.values("role", "content"))[-MAX_HISTORY:]
        history = past + [{"role": "user", "content": content}]

        try:
            reply = call_gemini(history)
        except AIError as e:
            return Response({"detail": str(e)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        user_msg = Message.objects.create(conversation=conversation, role="user", content=content)
        ai_msg = Message.objects.create(conversation=conversation, role="assistant", content=reply)
        if conversation.title == "New chat":
            conversation.title = content[:50]
        conversation.save()
        return Response({
            "title": conversation.title,
            "messages": MessageSerializer([user_msg, ai_msg], many=True).data,
        })
