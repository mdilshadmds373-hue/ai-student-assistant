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
