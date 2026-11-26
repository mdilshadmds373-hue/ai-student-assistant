set -e
cd /workspaces/ai-student-assistant/frontend/src
mkdir -p components pages

cat > components/Calculator.jsx <<'EOF'
import { useState } from "react";

// Safe expression parser (eval istemal nahi hota)
function evaluate(input, deg) {
  const src = input.replace(/π/g, "pi").replace(/×/g, "*").replace(/÷/g, "/").replace(/√/g, "sqrt");
  const tokens = src.match(/\d+\.?\d*|\.\d+|[a-z]+|[-+*/^()]/gi) || [];
  if (tokens.join("") !== src.replace(/\s+/g, "")) throw new Error("Ghalat expression");

  let i = 0;
  const peek = () => tokens[i];
  const next = () => tokens[i++];
  const toRad = (x) => (deg ? (x * Math.PI) / 180 : x);
  const funcs = {
    sin: (x) => Math.sin(toRad(x)),
    cos: (x) => Math.cos(toRad(x)),
    tan: (x) => Math.tan(toRad(x)),
    sqrt: Math.sqrt,
    log: Math.log10,
    ln: Math.log,
    abs: Math.abs,
  };
  const consts = { pi: Math.PI, e: Math.E };

  function expr() {
    let v = term();
    while (peek() === "+" || peek() === "-") v = next() === "+" ? v + term() : v - term();
    return v;
  }
  function term() {
    let v = unary();
    while (peek() === "*" || peek() === "/") v = next() === "*" ? v * unary() : v / unary();
    return v;
  }
  function unary() {
    if (peek() === "-") { next(); return -unary(); }
    if (peek() === "+") { next(); return unary(); }
    return power();
  }
  function power() {
    const base = primary();
    if (peek() === "^") { next(); return Math.pow(base, unary()); }
    return base;
  }
  function primary() {
    const t = next();
    if (t === undefined) throw new Error("Expression adhoori hai");
    if (/^[\d.]/.test(t)) return parseFloat(t);
    if (t === "(") {
      const v = expr();
      if (next() !== ")") throw new Error("Bracket band nahi hua");
      return v;
    }
    const name = t.toLowerCase();
    if (name in consts) return consts[name];
    if (name in funcs) {
      if (next() !== "(") throw new Error(`${t} ke baad ( chahiye`);
      const v = expr();
      if (next() !== ")") throw new Error("Bracket band nahi hua");
      return funcs[name](v);
    }
    throw new Error(`Ghalat: ${t}`);
  }

  const result = expr();
  if (i < tokens.length) throw new Error("Ghalat expression");
  if (!Number.isFinite(result)) throw new Error("Natija mumkin nahi");
  return Math.round(result * 1e10) / 1e10;
}

const keys = [
  ["sin(", "cos(", "tan(", "sqrt("],
  ["log(", "ln(", "π", "e"],
  ["(", ")", "^", "÷"],
  ["7", "8", "9", "×"],
  ["4", "5", "6", "-"],
  ["1", "2", "3", "+"],
  ["0", ".", "⌫", "="],
];

export default function Calculator() {
  const [text, setText] = useState("");
  const [result, setResult] = useState("");
  const [deg, setDeg] = useState(true);

  const calculate = () => {
    if (!text.trim()) return;
    try {
      const v = evaluate(text, deg);
      setResult(String(v));
    } catch (err) {
      setResult(err.message);
    }
  };

  const press = (k) => {
    if (k === "=") return calculate();
    if (k === "⌫") return setText((t) => t.slice(0, -1));
    setText((t) => t + k);
  };

  return (
    <div className="max-w-sm rounded-2xl bg-white p-5 shadow-sm">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-slate-700">Scientific Calculator</h2>
        <button onClick={() => setDeg(!deg)}
          className="rounded-md bg-purple-100 px-2 py-1 text-xs font-semibold text-purple-900">
          {deg ? "DEG" : "RAD"}
        </button>
      </div>
      <input value={text} onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && calculate()}
        placeholder="0"
        className="mt-3 w-full rounded-lg border border-slate-300 px-3 py-2 text-right text-lg focus:outline-none focus:ring-2 focus:ring-purple-600" />
      <p className="mt-2 min-h-7 text-right text-xl font-semibold text-purple-900">{result}</p>
      <div className="mt-3 grid grid-cols-4 gap-2">
        {keys.flat().map((k) => (
          <button key={k} onClick={() => press(k)}
            className={`rounded-lg py-2 font-medium transition ${
              k === "=" ? "bg-purple-800 text-white hover:bg-purple-900"
              : "bg-slate-100 text-slate-800 hover:bg-slate-200"}`}>
            {k}
          </button>
        ))}
        <button onClick={() => { setText(""); setResult(""); }}
          className="col-span-4 rounded-lg bg-slate-200 py-2 font-medium hover:bg-slate-300">Clear</button>
      </div>
    </div>
  );
}
EOF

cat > components/FocusTimer.jsx <<'EOF'
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
EOF

cat > pages/Tools.jsx <<'EOF'
import Calculator from "../components/Calculator.jsx";
import FocusTimer from "../components/FocusTimer.jsx";

export default function Tools() {
  return (
    <div>
      <h1 className="text-2xl font-bold text-purple-900">Tools</h1>
      <div className="mt-6 flex flex-wrap items-start gap-6">
        <Calculator />
        <FocusTimer />
      </div>
    </div>
  );
}
EOF

python3 - <<'PYEOF'
p = "App.jsx"
s = open(p).read()
if "pages/Tools.jsx" not in s:
    s = s.replace('import ComingSoon', 'import Tools from "./pages/Tools.jsx";\nimport ComingSoon', 1)
    s = s.replace('<Route path="/productivity"', '<Route path="/tools" element={<Tools />} />\n          <Route path="/productivity"', 1)
open(p, "w").write(s)

p = "components/DashboardLayout.jsx"
s = open(p).read()
if '"/tools"' not in s:
    s = s.replace("FolderOpen, Wand2, Compass,", "FolderOpen, Wand2, Calculator, Compass,", 1)
    s = s.replace('{ to: "/productivity", label: "Productivity", icon: CalendarCheck },',
                  '{ to: "/productivity", label: "Productivity", icon: CalendarCheck },\n  { to: "/tools", label: "Tools", icon: Calculator },', 1)
open(p, "w").write(s)
print("patch ok")
PYEOF

cd /workspaces/ai-student-assistant
echo "PHASE 7 SETUP COMPLETE"