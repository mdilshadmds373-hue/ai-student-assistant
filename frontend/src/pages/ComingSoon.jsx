export default function ComingSoon({ title, phase }) {
  return (
    <div>
      <h1 className="text-2xl font-bold text-purple-900">{title}</h1>
      <p className="mt-2 text-slate-500">Ye module Phase {phase} mein banega.</p>
    </div>
  );
}
