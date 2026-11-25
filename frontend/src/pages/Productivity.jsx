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
