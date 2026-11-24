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
