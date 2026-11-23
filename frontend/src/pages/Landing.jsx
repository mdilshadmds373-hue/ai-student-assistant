import { Link } from "react-router-dom";
import { GraduationCap, Sparkles } from "lucide-react";

export default function Landing() {
  return (
    <div className="min-h-screen bg-white">
      <header className="flex items-center justify-between px-6 py-4 max-w-6xl mx-auto">
        <div className="flex items-center gap-2 text-purple-900 font-bold text-xl">
          <GraduationCap /> AI Student Assistant
        </div>
        <Link to="/dashboard" className="rounded-lg bg-purple-800 px-4 py-2 text-white hover:bg-purple-900 transition">
          Open Dashboard
        </Link>
      </header>

      <section className="bg-purple-900 text-white">
        <div className="max-w-6xl mx-auto px-6 py-24 text-center">
          <Sparkles className="mx-auto mb-4" size={40} />
          <h1 className="text-4xl md:text-5xl font-bold">Your all-in-one study companion</h1>
          <p className="mt-4 text-purple-200 max-w-2xl mx-auto">
            Academics, productivity, documents aur AI assistance, sab ek jagah.
          </p>
          <Link to="/dashboard" className="inline-block mt-8 rounded-xl bg-white px-6 py-3 font-semibold text-purple-900 shadow hover:bg-purple-100 transition">
            Get Started
          </Link>
        </div>
      </section>
    </div>
  );
}
