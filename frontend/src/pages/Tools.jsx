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
