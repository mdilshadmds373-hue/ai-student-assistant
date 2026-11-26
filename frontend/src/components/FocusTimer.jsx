import { useEffect, useRef, useState } from "react";

const todayKey = () => `focus-${new Date().toISOString().slice(0, 10)}`;

function readCount() {
  try { return Number(localStorage.getItem(todayKey())) || 0; } catch { return 0; }
}

const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;

export default function FocusTimer() {
  const [minutes, setMinutes] = useState(25);
  const [left, setLeft] = useState(25 * 60);
  const [running, setRunning] = useState(false);
  const [done, setDone] = useState(readCount());
  const endRef = useRef(0);

  useEffect(() => {
    if (!running) return;
    const id = setInterval(() => {
      const s = Math.max(0, Math.round((endRef.current - Date.now()) / 1000));
      setLeft(s);
      if (s === 0) {
        setRunning(false);
        const n = readCount() + 1;
        try { localStorage.setItem(todayKey(), String(n)); } catch { /* ignore */ }
        setDone(n);
      }
    }, 250);
    return () => clearInterval(id);
  }, [running]);

  useEffect(() => {
    document.title = running ? `${fmt(left)} - Focus` : "AI Student Assistant";
    return () => { document.title = "AI Student Assistant"; };
  }, [running, left]);

  const start = () => {
    if (left === 0) setLeft(minutes * 60);
    endRef.current = Date.now() + (left === 0 ? minutes * 60 : left) * 1000;
    setRunning(true);
  };
  const pause = () => setRunning(false);
  const reset = () => { setRunning(false); setLeft(minutes * 60); };
  const changeMinutes = (v) => {
    const m = Math.min(180, Math.max(1, Number(v) || 1));
    setMinutes(m);
    if (!running) setLeft(m * 60);
  };

  return (
    <div className="max-w-sm rounded-2xl bg-white p-5 shadow-sm">
      <h2 className="font-semibold text-slate-700">Focus Timer</h2>
      <p className="mt-4 text-center text-6xl font-bold tabular-nums text-purple-900">{fmt(left)}</p>
      <div className="mt-4 flex items-center justify-center gap-2">
        <label className="text-sm text-slate-600">Minutes</label>
        <input type="number" min={1} max={180} value={minutes} disabled={running}
          onChange={(e) => changeMinutes(e.target.value)}
          className="w-20 rounded-lg border border-slate-300 px-2 py-1 text-center disabled:opacity-60" />
      </div>
      <div className="mt-4 flex justify-center gap-2">
        {running ? (
          <button onClick={pause} className="rounded-lg bg-purple-800 px-5 py-2 font-semibold text-white hover:bg-purple-900">Pause</button>
        ) : (
          <button onClick={start} className="rounded-lg bg-purple-800 px-5 py-2 font-semibold text-white hover:bg-purple-900">Start</button>
        )}
        <button onClick={reset} className="rounded-lg bg-slate-200 px-5 py-2 font-medium hover:bg-slate-300">Reset</button>
      </div>
      <p className="mt-4 text-center text-sm text-slate-500">Aaj ke complete sessions: <b>{done}</b></p>
    </div>
  );
}
