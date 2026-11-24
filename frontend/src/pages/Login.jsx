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
