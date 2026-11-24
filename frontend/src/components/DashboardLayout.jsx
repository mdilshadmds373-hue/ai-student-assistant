import { NavLink, Outlet, useNavigate } from "react-router-dom";
import {
  LayoutDashboard, Bot, BookOpen, CalendarCheck,
  FolderOpen, Wand2, Compass, Settings, GraduationCap, LogOut,
} from "lucide-react";
import { useAuth } from "../context/AuthContext.jsx";

const links = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { to: "/assistant", label: "AI Assistant", icon: Bot },
  { to: "/academic", label: "Academic Center", icon: BookOpen },
  { to: "/productivity", label: "Productivity", icon: CalendarCheck },
  { to: "/documents", label: "Documents", icon: FolderOpen },
  { to: "/studio", label: "Creation Studio", icon: Wand2 },
  { to: "/explore", label: "Explore", icon: Compass },
  { to: "/settings", label: "Settings", icon: Settings },
];

export default function DashboardLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const onLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <div className="flex min-h-screen bg-slate-50">
      <aside className="hidden md:flex w-64 flex-col bg-purple-900 text-white p-4">
        <div className="flex items-center gap-2 text-lg font-bold mb-8 px-2">
          <GraduationCap /> Student AI
        </div>
        <nav className="space-y-1 flex-1">
          {links.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2 transition ${
                  isActive ? "bg-white text-purple-900" : "hover:bg-purple-800"
                }`
              }
            >
              <Icon size={18} /> {label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-purple-700 pt-4">
          <p className="px-2 text-sm font-medium truncate">{user.full_name}</p>
          <button
            onClick={onLogout}
            className="mt-2 flex w-full items-center gap-3 rounded-lg px-3 py-2 hover:bg-purple-800 transition"
          >
            <LogOut size={18} /> Logout
          </button>
        </div>
      </aside>
      <main className="flex-1 p-6">
        <Outlet />
      </main>
    </div>
  );
}
