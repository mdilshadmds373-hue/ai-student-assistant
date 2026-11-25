set -e
cd /workspaces/ai-student-assistant/backend
source venv/bin/activate

# ---------- BACKEND ----------
python manage.py startapp academics 2>/dev/null || true

python3 - <<'PYEOF'
import re
p = "config/settings.py"
s = open(p).read()
if not re.search(r"""['"]academics['"]""", s):
    s = re.sub(r"(INSTALLED_APPS\s*=\s*\[)", r'\1\n    "academics",', s, count=1)
open(p, "w").write(s)
print("settings ok")
PYEOF

cat > academics/models.py <<'EOF'
from django.conf import settings
from django.db import models


class Subject(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subjects")
    name = models.CharField(max_length=100)
    code = models.CharField(max_length=30, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Note(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notes")
    subject = models.ForeignKey(Subject, null=True, blank=True, on_delete=models.SET_NULL, related_name="notes")
    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class Task(models.Model):
    PRIORITIES = [("low", "Low"), ("medium", "Medium"), ("high", "High")]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="tasks")
    subject = models.ForeignKey(Subject, null=True, blank=True, on_delete=models.SET_NULL, related_name="tasks")
    title = models.CharField(max_length=200)
    due_date = models.DateField(null=True, blank=True)
    priority = models.CharField(max_length=6, choices=PRIORITIES, default="medium")
    is_done = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
EOF

cat > academics/serializers.py <<'EOF'
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
EOF

cat > academics/views.py <<'EOF'
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
EOF

cat > academics/urls.py <<'EOF'
from rest_framework.routers import DefaultRouter

from .views import NoteViewSet, SubjectViewSet, TaskViewSet

router = DefaultRouter()
router.register("subjects", SubjectViewSet, basename="subject")
router.register("notes", NoteViewSet, basename="note")
router.register("tasks", TaskViewSet, basename="task")

urlpatterns = router.urls
EOF

cat > academics/tests.py <<'EOF'
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()


class IsolationTests(APITestCase):
    def setUp(self):
        self.a = User.objects.create_user("a@x.com", "a@x.com", "pw12345678")
        self.b = User.objects.create_user("b@x.com", "b@x.com", "pw12345678")

    def test_user_b_cannot_touch_user_a_data(self):
        self.client.force_authenticate(self.a)
        r = self.client.post("/api/subjects/", {"name": "Python"})
        self.assertEqual(r.status_code, 201)
        sid = r.data["id"]

        self.client.force_authenticate(self.b)
        self.assertEqual(self.client.get("/api/subjects/").data, [])
        self.assertEqual(self.client.get(f"/api/subjects/{sid}/").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/subjects/{sid}/").status_code, 404)
        r = self.client.post("/api/tasks/", {"title": "x", "subject": sid})
        self.assertEqual(r.status_code, 400)

    def test_login_required(self):
        self.assertEqual(self.client.get("/api/subjects/").status_code, 401)
EOF

cat > config/urls.py <<'EOF'
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
]
EOF

python manage.py makemigrations academics
python manage.py migrate
python manage.py test academics
deactivate

# ---------- FRONTEND ----------
cd /workspaces/ai-student-assistant/frontend/src

cat > pages/Academic.jsx <<'EOF'
import { useEffect, useState } from "react";
import { Trash2 } from "lucide-react";
import api from "../api.js";
import { errorText } from "../utils.js";

const input = "rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600";
const btn = "rounded-lg bg-purple-800 px-4 py-2 font-semibold text-white hover:bg-purple-900 transition";

export default function Academic() {
  const [subjects, setSubjects] = useState([]);
  const [notes, setNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [subjectForm, setSubjectForm] = useState({ name: "", code: "" });
  const [noteForm, setNoteForm] = useState({ title: "", content: "", subject: "" });

  const load = async () => {
    try {
      const [s, n] = await Promise.all([api.get("/subjects/"), api.get("/notes/")]);
      setSubjects(s.data);
      setNotes(n.data);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const run = async (fn) => {
    setError("");
    try { await fn(); await load(); } catch (err) { setError(errorText(err)); }
  };

  const addSubject = (e) => {
    e.preventDefault();
    run(async () => {
      await api.post("/subjects/", subjectForm);
      setSubjectForm({ name: "", code: "" });
    });
  };

  const addNote = (e) => {
    e.preventDefault();
    run(async () => {
      await api.post("/notes/", { ...noteForm, subject: noteForm.subject || null });
      setNoteForm({ title: "", content: "", subject: "" });
    });
  };

  const subjectName = (id) => subjects.find((s) => s.id === id)?.name;

  if (loading) return <p className="text-slate-500">Loading...</p>;

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-bold text-purple-900">Academic Center</h1>
      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <section className="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 className="font-semibold text-slate-700">Subjects</h2>
        <form onSubmit={addSubject} className="mt-3 flex flex-wrap gap-2">
          <input required placeholder="Subject (jaise Python)" value={subjectForm.name}
            onChange={(e) => setSubjectForm({ ...subjectForm, name: e.target.value })} className={input} />
          <input placeholder="Code (optional)" value={subjectForm.code}
            onChange={(e) => setSubjectForm({ ...subjectForm, code: e.target.value })} className={input} />
          <button className={btn}>Add</button>
        </form>
        <ul className="mt-4 divide-y">
          {subjects.length === 0 && <li className="py-2 text-slate-500">Abhi koi subject nahi.</li>}
          {subjects.map((s) => (
            <li key={s.id} className="flex items-center justify-between py-2">
              <span>{s.name} {s.code && <span className="text-slate-400">({s.code})</span>}</span>
              <button onClick={() => run(() => api.delete(`/subjects/${s.id}/`))} aria-label="Delete subject"
                className="text-slate-400 hover:text-red-600"><Trash2 size={18} /></button>
            </li>
          ))}
        </ul>
      </section>

      <section className="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 className="font-semibold text-slate-700">Notes</h2>
        <form onSubmit={addNote} className="mt-3 space-y-2">
          <div className="flex flex-wrap gap-2">
            <input required placeholder="Title" value={noteForm.title}
              onChange={(e) => setNoteForm({ ...noteForm, title: e.target.value })} className={input} />
            <select value={noteForm.subject}
              onChange={(e) => setNoteForm({ ...noteForm, subject: e.target.value })} className={input}>
              <option value="">Koi subject nahi</option>
              {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
          <textarea rows={4} placeholder="Note likhein..." value={noteForm.content}
            onChange={(e) => setNoteForm({ ...noteForm, content: e.target.value })} className={`${input} w-full`} />
          <button className={btn}>Save note</button>
        </form>
        <div className="mt-4 space-y-3">
          {notes.length === 0 && <p className="text-slate-500">Abhi koi note nahi.</p>}
          {notes.map((n) => (
            <article key={n.id} className="rounded-xl border border-slate-200 p-4">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-semibold text-slate-800">{n.title}</h3>
                  {n.subject && <p className="text-xs text-purple-700">{subjectName(n.subject)}</p>}
                </div>
                <button onClick={() => run(() => api.delete(`/notes/${n.id}/`))} aria-label="Delete note"
                  className="text-slate-400 hover:text-red-600"><Trash2 size={18} /></button>
              </div>
              <p className="mt-2 whitespace-pre-wrap text-slate-600">{n.content}</p>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
EOF

cat > pages/Productivity.jsx <<'EOF'
import { useEffect, useState } from "react";
import { Trash2 } from "lucide-react";
import api from "../api.js";
import { errorText } from "../utils.js";

const input = "rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600";
const btn = "rounded-lg bg-purple-800 px-4 py-2 font-semibold text-white hover:bg-purple-900 transition";
const empty = { title: "", due_date: "", priority: "medium", subject: "" };

export default function Productivity() {
  const [tasks, setTasks] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [form, setForm] = useState(empty);

  const load = async () => {
    try {
      const [t, s] = await Promise.all([api.get("/tasks/"), api.get("/subjects/")]);
      setTasks(t.data);
      setSubjects(s.data);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const run = async (fn) => {
    setError("");
    try { await fn(); await load(); } catch (err) { setError(errorText(err)); }
  };

  const addTask = (e) => {
    e.preventDefault();
    run(async () => {
      await api.post("/tasks/", {
        ...form,
        due_date: form.due_date || null,
        subject: form.subject || null,
      });
      setForm(empty);
    });
  };

  const subjectName = (id) => subjects.find((s) => s.id === id)?.name;

  if (loading) return <p className="text-slate-500">Loading...</p>;

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-bold text-purple-900">Productivity: Tasks</h1>
      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <form onSubmit={addTask} className="mt-6 flex flex-wrap gap-2 rounded-2xl bg-white p-6 shadow-sm">
        <input required placeholder="Naya task" value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })} className={`${input} flex-1 min-w-48`} />
        <input type="date" value={form.due_date}
          onChange={(e) => setForm({ ...form, due_date: e.target.value })} className={input} />
        <select value={form.priority} onChange={(e) => setForm({ ...form, priority: e.target.value })} className={input}>
          <option value="low">Low</option>
          <option value="medium">Medium</option>
          <option value="high">High</option>
        </select>
        <select value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} className={input}>
          <option value="">Koi subject nahi</option>
          {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <button className={btn}>Add task</button>
      </form>

      <ul className="mt-6 divide-y rounded-2xl bg-white p-2 shadow-sm">
        {tasks.length === 0 && <li className="p-4 text-slate-500">Abhi koi task nahi.</li>}
        {tasks.map((t) => (
          <li key={t.id} className="flex items-center gap-3 p-3">
            <input type="checkbox" checked={t.is_done} className="h-5 w-5 accent-purple-800"
              onChange={() => run(() => api.patch(`/tasks/${t.id}/`, { is_done: !t.is_done }))} />
            <div className="flex-1">
              <p className={t.is_done ? "text-slate-400 line-through" : "text-slate-800"}>{t.title}</p>
              <p className="text-xs text-slate-500">
                {t.priority}
                {t.due_date && ` · due ${t.due_date}`}
                {t.subject && ` · ${subjectName(t.subject)}`}
              </p>
            </div>
            <button onClick={() => run(() => api.delete(`/tasks/${t.id}/`))} aria-label="Delete task"
              className="text-slate-400 hover:text-red-600"><Trash2 size={18} /></button>
          </li>
        ))}
      </ul>
    </div>
  );
}
EOF

cat > App.jsx <<'EOF'
import { Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing.jsx";
import Login from "./pages/Login.jsx";
import Register from "./pages/Register.jsx";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import DashboardLayout from "./components/DashboardLayout.jsx";
import Dashboard from "./pages/Dashboard.jsx";
import Academic from "./pages/Academic.jsx";
import Productivity from "./pages/Productivity.jsx";
import ComingSoon from "./pages/ComingSoon.jsx";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<DashboardLayout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/assistant" element={<ComingSoon title="AI Study Assistant" phase={6} />} />
          <Route path="/academic" element={<Academic />} />
          <Route path="/productivity" element={<Productivity />} />
          <Route path="/documents" element={<ComingSoon title="Documents" phase={9} />} />
          <Route path="/studio" element={<ComingSoon title="AI Creation Studio" phase={10} />} />
          <Route path="/explore" element={<ComingSoon title="Explore" phase={11} />} />
          <Route path="/settings" element={<ComingSoon title="Settings" phase={12} />} />
        </Route>
      </Route>
    </Routes>
  );
}
EOF

cd /workspaces/ai-student-assistant
echo "PHASE 5 SETUP COMPLETE"