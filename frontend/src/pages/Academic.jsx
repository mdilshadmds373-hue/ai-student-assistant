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
