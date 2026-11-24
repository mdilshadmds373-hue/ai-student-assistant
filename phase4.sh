set -e
cd /workspaces/ai-student-assistant

# ---------- BACKEND ----------
cd backend

cat > accounts/models.py <<'EOF'
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
EOF

cat > accounts/serializers.py <<'EOF'
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
EOF

cat > accounts/views.py <<'EOF'
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
EOF

cat > config/urls.py <<'EOF'
from django.contrib import admin
from django.urls import path

from accounts import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", views.health),
    path("api/auth/register/", views.register),
    path("api/auth/login/", views.login),
    path("api/auth/logout/", views.logout),
    path("api/auth/me/", views.me),
]
EOF

source venv/bin/activate
python manage.py makemigrations accounts
python manage.py migrate
deactivate
cd ..

# ---------- FRONTEND ----------
cd frontend/src
mkdir -p context components pages

cat > api.js <<'EOF'
import axios from "axios";

const api = axios.create({ baseURL: "/api" });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) config.headers.Authorization = `Token ${token}`;
  return config;
});

export default api;
EOF

cat > utils.js <<'EOF'
// Server ke error response ko saaf text mein badalta hai
export function errorText(err) {
  const data = err.response?.data;
  if (!data) return "Server se connect nahi ho saka. Backend chal raha hai?";
  if (data.detail) return data.detail;
  return Object.values(data).flat().join(" ");
}
EOF

cat > context/AuthContext.jsx <<'EOF'
import { createContext, useContext, useEffect, useState } from "react";
import api from "../api.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(!!localStorage.getItem("token"));

  useEffect(() => {
    if (!localStorage.getItem("token")) return;
    api
      .get("/auth/me/")
      .then((res) => setUser(res.data))
      .catch(() => localStorage.removeItem("token"))
      .finally(() => setLoading(false));
  }, []);

  const saveSession = (data) => {
    localStorage.setItem("token", data.token);
    setUser(data.user);
  };

  const login = async (email, password) => {
    const { data } = await api.post("/auth/login/", { email, password });
    saveSession(data);
  };

  const register = async (payload) => {
    const { data } = await api.post("/auth/register/", payload);
    saveSession(data);
  };

  const logout = async () => {
    try {
      await api.post("/auth/logout/");
    } catch {
      // token pehle se invalid ho to bhi local logout kar do
    }
    localStorage.removeItem("token");
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
EOF

cat > components/ProtectedRoute.jsx <<'EOF'
import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../context/AuthContext.jsx";

export default function ProtectedRoute() {
  const { user, loading } = useAuth();
  if (loading) return <p className="p-6 text-slate-500">Loading...</p>;
  if (!user) return <Navigate to="/login" replace />;
  return <Outlet />;
}
EOF

cat > pages/Login.jsx <<'EOF'
import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { GraduationCap } from "lucide-react";
import { useAuth } from "../context/AuthContext.jsx";
import { errorText } from "../utils.js";

export default function Login() {
  const { user, login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: "", password: "" });
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (user) return <Navigate to="/dashboard" replace />;

  const onSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await login(form.email, form.password);
      navigate("/dashboard");
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 px-4">
      <form onSubmit={onSubmit} className="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm">
        <div className="flex items-center gap-2 text-purple-900 font-bold text-xl mb-6">
          <GraduationCap /> AI Student Assistant
        </div>
        <h1 className="text-2xl font-bold text-slate-800">Login</h1>

        <label className="block mt-6 text-sm font-medium text-slate-700">Email</label>
        <input
          type="email" required value={form.email}
          onChange={(e) => setForm({ ...form, email: e.target.value })}
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600"
        />

        <label className="block mt-4 text-sm font-medium text-slate-700">Password</label>
        <input
          type="password" required value={form.password}
          onChange={(e) => setForm({ ...form, password: e.target.value })}
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600"
        />

        {error && <p className="mt-4 text-sm text-red-600">{error}</p>}

        <button
          type="submit" disabled={submitting}
          className="mt-6 w-full rounded-lg bg-purple-800 py-2.5 font-semibold text-white hover:bg-purple-900 disabled:opacity-60 transition"
        >
          {submitting ? "Please wait..." : "Login"}
        </button>

        <p className="mt-4 text-sm text-slate-600">
          Account nahi hai?{" "}
          <Link to="/register" className="font-semibold text-purple-800 hover:underline">Register karein</Link>
        </p>
      </form>
    </div>
  );
}
EOF

cat > pages/Register.jsx <<'EOF'
import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { GraduationCap } from "lucide-react";
import { useAuth } from "../context/AuthContext.jsx";
import { errorText } from "../utils.js";

export default function Register() {
  const { user, register } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ full_name: "", email: "", password: "", confirm: "" });
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (user) return <Navigate to="/dashboard" replace />;

  const onSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (form.password !== form.confirm) {
      setError("Dono passwords match nahi karte.");
      return;
    }
    setSubmitting(true);
    try {
      await register({ full_name: form.full_name, email: form.email, password: form.password });
      navigate("/dashboard");
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSubmitting(false);
    }
  };

  const field = (label, name, type = "text") => (
    <>
      <label className="block mt-4 text-sm font-medium text-slate-700">{label}</label>
      <input
        type={type} required value={form[name]}
        onChange={(e) => setForm({ ...form, [name]: e.target.value })}
        className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600"
      />
    </>
  );

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 px-4">
      <form onSubmit={onSubmit} className="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm">
        <div className="flex items-center gap-2 text-purple-900 font-bold text-xl mb-6">
          <GraduationCap /> AI Student Assistant
        </div>
        <h1 className="text-2xl font-bold text-slate-800">Account banayein</h1>

        {field("Poora naam", "full_name")}
        {field("Email", "email", "email")}
        {field("Password (kam az kam 8 characters)", "password", "password")}
        {field("Password dobara likhein", "confirm", "password")}

        {error && <p className="mt-4 text-sm text-red-600">{error}</p>}

        <button
          type="submit" disabled={submitting}
          className="mt-6 w-full rounded-lg bg-purple-800 py-2.5 font-semibold text-white hover:bg-purple-900 disabled:opacity-60 transition"
        >
          {submitting ? "Please wait..." : "Register"}
        </button>

        <p className="mt-4 text-sm text-slate-600">
          Pehle se account hai?{" "}
          <Link to="/login" className="font-semibold text-purple-800 hover:underline">Login karein</Link>
        </p>
      </form>
    </div>
  );
}
EOF

cat > pages/Dashboard.jsx <<'EOF'
import { useEffect, useState } from "react";
import api from "../api.js";
import { useAuth } from "../context/AuthContext.jsx";

export default function Dashboard() {
  const { user } = useAuth();
  const [status, setStatus] = useState({ loading: true, error: null, data: null });

  useEffect(() => {
    api
      .get("/health/")
      .then((res) => setStatus({ loading: false, error: null, data: res.data }))
      .catch(() => setStatus({ loading: false, error: "Backend se connect nahi ho saka", data: null }));
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-purple-900">Welcome, {user.full_name}</h1>
      <p className="mt-1 text-slate-500">{user.email}</p>
      <div className="mt-6 max-w-md rounded-2xl bg-white p-6 shadow-sm">
        <h2 className="font-semibold text-slate-700">Backend Connection</h2>
        {status.loading && <p className="mt-2 text-slate-500">Check ho raha hai...</p>}
        {status.error && <p className="mt-2 text-red-600">{status.error}</p>}
        {status.data && <p className="mt-2 text-green-600">{status.data.message}</p>}
      </div>
    </div>
  );
}
EOF

cat > components/DashboardLayout.jsx <<'EOF'
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import {
  LayoutDashboard, Bot, BookOpen, CalendarCheck,
  FolderOpen, Wand2, Compass, Settings, GraduationCap, LogOut,
} from "lucide-react";
import { useAuth } from "../context/AuthContext.jsx";

const links = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { to: "/assistant", label: "AI Assistant", icon: Bot },
  { to: "/academic", label: "Academic Center", icon: BookOpen },
  { to: "/productivity", label: "Productivity", icon: CalendarCheck },
  { to: "/documents", label: "Documents", icon: FolderOpen },
  { to: "/studio", label: "Creation Studio", icon: Wand2 },
  { to: "/explore", label: "Explore", icon: Compass },
  { to: "/settings", label: "Settings", icon: Settings },
];

export default function DashboardLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const onLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <div className="flex min-h-screen bg-slate-50">
      <aside className="hidden md:flex w-64 flex-col bg-purple-900 text-white p-4">
        <div className="flex items-center gap-2 text-lg font-bold mb-8 px-2">
          <GraduationCap /> Student AI
        </div>
        <nav className="space-y-1 flex-1">
          {links.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2 transition ${
                  isActive ? "bg-white text-purple-900" : "hover:bg-purple-800"
                }`
              }
            >
              <Icon size={18} /> {label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-purple-700 pt-4">
          <p className="px-2 text-sm font-medium truncate">{user.full_name}</p>
          <button
            onClick={onLogout}
            className="mt-2 flex w-full items-center gap-3 rounded-lg px-3 py-2 hover:bg-purple-800 transition"
          >
            <LogOut size={18} /> Logout
          </button>
        </div>
      </aside>
      <main className="flex-1 p-6">
        <Outlet />
      </main>
    </div>
  );
}
EOF

cat > main.jsx <<'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App.jsx";
import { AuthProvider } from "./context/AuthContext.jsx";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
EOF

cat > App.jsx <<'EOF'
import { Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing.jsx";
import Login from "./pages/Login.jsx";
import Register from "./pages/Register.jsx";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import DashboardLayout from "./components/DashboardLayout.jsx";
import Dashboard from "./pages/Dashboard.jsx";
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
          <Route path="/academic" element={<ComingSoon title="Academic Center" phase={7} />} />
          <Route path="/productivity" element={<ComingSoon title="Productivity Center" phase={8} />} />
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
echo "PHASE 4 SETUP COMPLETE"