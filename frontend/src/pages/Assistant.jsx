import { useEffect, useRef, useState } from "react";
import { MessageSquarePlus, Send, Trash2 } from "lucide-react";
import api from "../api.js";
import { errorText } from "../utils.js";

export default function Assistant() {
  const [chats, setChats] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef(null);

  const loadChats = async () => {
    try {
      const { data } = await api.get("/conversations/");
      setChats(data);
    } catch (err) {
      setError(errorText(err));
    }
  };

  useEffect(() => { loadChats(); }, []);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, sending]);

  const openChat = async (id) => {
    setError("");
    setActiveId(id);
    try {
      const { data } = await api.get(`/conversations/${id}/`);
      setMessages(data.messages);
    } catch (err) {
      setError(errorText(err));
    }
  };

  const newChat = () => {
    setActiveId(null);
    setMessages([]);
    setError("");
  };

  const removeChat = async (id) => {
    try {
      await api.delete(`/conversations/${id}/`);
      if (id === activeId) newChat();
      loadChats();
    } catch (err) {
      setError(errorText(err));
    }
  };

  const send = async (e) => {
    e.preventDefault();
    const content = text.trim();
    if (!content || sending) return;
    setError("");
    setSending(true);
    try {
      let id = activeId;
      if (!id) {
        const { data } = await api.post("/conversations/", {});
        id = data.id;
        setActiveId(id);
      }
      const { data } = await api.post(`/conversations/${id}/send/`, { content });
      setMessages((m) => [...m, ...data.messages]);
      setText("");
      loadChats();
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="flex h-[calc(100vh-3rem)] gap-4">
      <aside className="hidden w-64 flex-col rounded-2xl bg-white p-3 shadow-sm sm:flex">
        <button onClick={newChat}
          className="flex items-center justify-center gap-2 rounded-lg bg-purple-800 py-2 font-semibold text-white hover:bg-purple-900 transition">
          <MessageSquarePlus size={18} /> New chat
        </button>
        <ul className="mt-3 flex-1 space-y-1 overflow-y-auto">
          {chats.map((c) => (
            <li key={c.id}
              className={`group flex items-center justify-between rounded-lg px-3 py-2 text-sm cursor-pointer ${
                c.id === activeId ? "bg-purple-100 text-purple-900" : "hover:bg-slate-100"}`}>
              <span onClick={() => openChat(c.id)} className="flex-1 truncate">{c.title}</span>
              <button onClick={() => removeChat(c.id)} aria-label="Delete chat"
                className="text-slate-400 hover:text-red-600"><Trash2 size={16} /></button>
            </li>
          ))}
        </ul>
      </aside>

      <section className="flex flex-1 flex-col rounded-2xl bg-white p-4 shadow-sm">
        <h1 className="text-xl font-bold text-purple-900">AI Study Assistant</h1>
        <div className="mt-3 flex-1 space-y-3 overflow-y-auto">
          {messages.length === 0 && !sending && (
            <p className="text-slate-500">Koi bhi sawal poochein, Urdu ya English mein.</p>
          )}
          {messages.map((m) => (
            <div key={m.id} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
              <div className={`max-w-[80%] whitespace-pre-wrap rounded-2xl px-4 py-2 ${
                m.role === "user" ? "bg-purple-800 text-white" : "bg-slate-100 text-slate-800"}`}>
                {m.content}
              </div>
            </div>
          ))}
          {sending && <p className="text-sm text-slate-500">Jawab likha ja raha hai...</p>}
          <div ref={bottomRef} />
        </div>
        {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
        <form onSubmit={send} className="mt-3 flex gap-2">
          <input value={text} onChange={(e) => setText(e.target.value)} maxLength={4000}
            placeholder="Apna sawal likhein..."
            className="flex-1 rounded-lg border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-600" />
          <button disabled={sending || !text.trim()} aria-label="Send"
            className="rounded-lg bg-purple-800 px-4 text-white hover:bg-purple-900 disabled:opacity-60 transition">
            <Send size={18} />
          </button>
        </form>
      </section>
    </div>
  );
}
