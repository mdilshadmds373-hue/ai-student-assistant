set -e
cd /workspaces/ai-student-assistant/backend
source venv/bin/activate

# ---------- BACKEND ----------
pip install requests python-dotenv
python manage.py startapp assistant 2>/dev/null || true

python3 - <<'PYEOF'
import re
p = "config/settings.py"
s = open(p).read()

if not re.search(r"""['"]assistant['"]""", s):
    s = re.sub(r"(INSTALLED_APPS\s*=\s*\[)", r'\1\n    "assistant",', s, count=1)

if "load_dotenv" not in s:
    s = re.sub(r"(BASE_DIR\s*=.*\n)", r'\1\nfrom dotenv import load_dotenv\nimport os\n\nload_dotenv(BASE_DIR / ".env")\n', s, count=1)

if "GEMINI_API_KEY" not in s:
    s += '\n\nGEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")\nGEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")\n'

if '"chat"' not in s:
    s = s.replace('"auth": "20/min"', '"auth": "20/min",\n        "chat": "30/min"')

if "DEFAULT_THROTTLE_CLASSES" not in s and "UserRateThrottle" not in s:
    pass
open(p, "w").write(s)
print("settings ok")
PYEOF

if [ ! -f .env ]; then
cat > .env <<'EOF'
GEMINI_API_KEY=yahan_apni_key_likhein
GEMINI_MODEL=gemini-2.5-flash
EOF
fi

cat > assistant/models.py <<'EOF'
from django.conf import settings
from django.db import models


class Conversation(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="conversations")
    title = models.CharField(max_length=120, default="New chat")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class Message(models.Model):
    ROLES = [("user", "User"), ("assistant", "Assistant")]

    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    role = models.CharField(max_length=10, choices=ROLES)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]
EOF

cat > assistant/services.py <<'EOF'
import requests
from django.conf import settings

SYSTEM_PROMPT = (
    "You are a friendly study assistant for university and school students. "
    "Explain concepts step by step with simple examples. "
    "Reply in the same language the student writes in (English, Urdu or Roman Urdu). "
    "Help the student learn and understand; do not just hand over finished assignments."
)


class AIError(Exception):
    pass


def call_gemini(history):
    """history: list of {"role": "user"|"assistant", "content": str}. Returns reply text."""
    if not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY.startswith("yahan_"):
        raise AIError("AI key set nahi hai. backend/.env mein GEMINI_API_KEY likhein.")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.GEMINI_MODEL}:generateContent"
    payload = {
        "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "contents": [
            {"role": "user" if m["role"] == "user" else "model", "parts": [{"text": m["content"]}]}
            for m in history
        ],
    }
    try:
        r = requests.post(url, json=payload, headers={"x-goog-api-key": settings.GEMINI_API_KEY}, timeout=60)
    except requests.RequestException:
        raise AIError("AI service se connect nahi ho saka. Thori der baad try karein.")

    if r.status_code == 429:
        raise AIError("AI ki free limit poori ho gayi hai. Thori der baad try karein.")
    if r.status_code != 200:
        raise AIError(f"AI service ne error diya ({r.status_code}). Key aur model ka naam check karein.")

    try:
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, ValueError):
        raise AIError("AI ne jawab nahi diya (shayad content block hua). Sawal badal kar dekhein.")
EOF

cat > assistant/serializers.py <<'EOF'
from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ["id", "role", "content", "created_at"]


class ConversationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Conversation
        fields = ["id", "title", "updated_at"]
        read_only_fields = ["id", "updated_at"]


class ConversationDetailSerializer(ConversationSerializer):
    messages = MessageSerializer(many=True, read_only=True)

    class Meta(ConversationSerializer.Meta):
        fields = ConversationSerializer.Meta.fields + ["messages"]
EOF

cat > assistant/views.py <<'EOF'
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
EOF

cat > assistant/urls.py <<'EOF'
from rest_framework.routers import DefaultRouter

from .views import ConversationViewSet

router = DefaultRouter()
router.register("conversations", ConversationViewSet, basename="conversation")

urlpatterns = router.urls
EOF

cat > assistant/tests.py <<'EOF'
from unittest.mock import patch

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()


class ChatTests(APITestCase):
    def setUp(self):
        self.a = User.objects.create_user("a@x.com", "a@x.com", "pw12345678")
        self.b = User.objects.create_user("b@x.com", "b@x.com", "pw12345678")

    @patch("assistant.views.call_gemini", return_value="Jawab")
    def test_chat_and_isolation(self, _mock):
        self.client.force_authenticate(self.a)
        cid = self.client.post("/api/conversations/", {}).data["id"]
        r = self.client.post(f"/api/conversations/{cid}/send/", {"content": "Hello"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(self.client.get(f"/api/conversations/{cid}/").data["messages"]), 2)

        self.client.force_authenticate(self.b)
        self.assertEqual(self.client.get("/api/conversations/").data, [])
        self.assertEqual(self.client.get(f"/api/conversations/{cid}/").status_code, 404)
        self.assertEqual(self.client.post(f"/api/conversations/{cid}/send/", {"content": "x"}).status_code, 404)

    def test_login_required(self):
        self.assertEqual(self.client.get("/api/conversations/").status_code, 401)
EOF

python3 - <<'PYEOF'
p = "config/urls.py"
s = open(p).read()
if "assistant.urls" not in s:
    s = s.replace('path("api/", include("academics.urls")),',
                  'path("api/", include("academics.urls")),\n    path("api/", include("assistant.urls")),')
open(p, "w").write(s)
print("urls ok")
PYEOF

python manage.py makemigrations assistant
python manage.py migrate
python manage.py test assistant
deactivate

# ---------- FRONTEND ----------
cd /workspaces/ai-student-assistant/frontend/src

cat > pages/Assistant.jsx <<'EOF'
import { useEffect, useRef, useState } from "react";
import { MessageSquarePlus, Send, Trash2 } from "lucide-react";
import api from "../api.js";
import { errorText } from "../utils.js";

export default function Assistant() {
  const [chats, setChats] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef(null);

  const loadChats = async () => {
    try {
      const { data } = await api.get("/conversations/");
      setChats(data);
    } catch (err) {
      setError(errorText(err));
    }
  };

  useEffect(() => { loadChats(); }, []);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, sending]);

  const openChat = async (id) => {
    setError("");
    setActiveId(id);
    try {
      const { data } = await api.get(`/conversations/${id}/`);
      setMessages(data.messages);
    } catch (err) {
      setError(errorText(err));
    }
  };

  const newChat = () => {
    setActiveId(null);
    setMessages([]);
    setError("");
  };

  const removeChat = async (id) => {
    try {
      await api.delete(`/conversations/${id}/`);
      if (id === activeId) newChat();
      loadChats();
    } catch (err) {
      setError(errorText(err));
    }
  };

  const send = async (e) => {
    e.preventDefault();
    const content = text.trim();
    if (!content || sending) return;
    setError("");
    setSending(true);
    try {
      let id = activeId;
      if (!id) {
        const { data } = await api.post("/conversations/", {});
        id = data.id;
        setActiveId(id);
      }
      const { data } = await api.post(`/conversations/${id}/send/`, { content });
      setMessages((m) => [...m, ...data.messages]);
      setText("");
      loadChats();
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="flex h-[calc(100vh-3rem)] gap-4">
      <aside className="hidden w-64 flex-col rounded-2xl bg-white p-3 shadow-sm sm:flex">
        <button onClick={newChat}
          className="flex items-center justify-center gap-2 rounded-lg bg-purple-800 py-2 font-semibold text-white hover:bg-purple-900 transition">
          <MessageSquarePlus size={18} /> New chat
        </button>
        <ul className="mt-3 flex-1 space-y-1 overflow-y-auto">
          {chats.map((c) => (
            <li key={c.id}
              className={`group flex items-center justify-between rounded-lg px-3 py-2 text-sm cursor-pointer ${
                c.id === activeId ? "bg-purple-100 text-purple-900" : "hover:bg-slate-100"}`}>
              <span onClick={() => openChat(c.id)} className="flex-1 truncate">{c.title}</span>
              <button onClick={() => removeChat(c.id)} aria-label="Delete chat"
                className="text-slate-400 hover:text-red-600"><Trash2 size={16} /></button>
            </li>
          ))}
        </ul>
      </aside>

      <section className="flex flex-1 flex-col rounded-2xl bg-white p-4 shadow-sm">
        <h1 className="text-xl font-bold text-purple-900">AI Study Assistant</h1>
        <div className="mt-3 flex-1 space-y-3 overflow-y-auto">
          {messages.length === 0 && !sending && (
            <p className="text-slate-500">Koi bhi sawal poochein, Urdu ya English mein.</p>
          )}
          {messages.map((m) => (
            <div key={m.id} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
              <div className={`max-w-[80%] whitespace-pre-wrap rounded-2xl px-4 py-2 ${
                m.role === "user" ? "bg-purple-800 text-white" : "bg-slate-100 text-slate-800"}`}>
                {m.content}
              </div>
            </div>
          ))}
          {sending && <p className="text-sm text-slate-500">Jawab likha ja raha hai...</p>}
          <div ref={bottomRef} />
        </div>
        {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
        <form onSubmit={send} className="mt-3 flex gap-2">
          <input value={text} onChange={(e) => setText(e.target.value)} maxLength={4000}
            placeholder="Apna sawal likhein..."
            className="flex-1 rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600" />
          <button disabled={sending || !text.trim()} aria-label="Send"
            className="rounded-lg bg-purple-800 px-4 text-white hover:bg-purple-900 disabled:opacity-60 transition">
            <Send size={18} />
          </button>
        </form>
      </section>
    </div>
  );
}
EOF

python3 - <<'PYEOF'
p = "App.jsx"
s = open(p).read()
if "pages/Assistant.jsx" not in s:
    s = s.replace('import ComingSoon', 'import Assistant from "./pages/Assistant.jsx";\nimport ComingSoon', 1)
    s = s.replace('<ComingSoon title="AI Study Assistant" phase={6} />', '<Assistant />')
open(p, "w").write(s)
print("App.jsx ok")
PYEOF

cd /workspaces/ai-student-assistant
echo "PHASE 6 SETUP COMPLETE"