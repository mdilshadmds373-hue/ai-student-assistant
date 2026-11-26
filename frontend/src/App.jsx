import { Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing.jsx";
import Login from "./pages/Login.jsx";
import Register from "./pages/Register.jsx";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import DashboardLayout from "./components/DashboardLayout.jsx";
import Dashboard from "./pages/Dashboard.jsx";
import Academic from "./pages/Academic.jsx";
import Productivity from "./pages/Productivity.jsx";
import Assistant from "./pages/Assistant.jsx";
import Tools from "./pages/Tools.jsx";
import ComingSoon from "./pages/ComingSoon.jsx";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<DashboardLayout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/assistant" element={<Assistant />} />
          <Route path="/academic" element={<Academic />} />
          <Route path="/tools" element={<Tools />} />
          <Route path="/productivity" element={<Productivity />} />
          <Route path="/documents" element={<ComingSoon title="Documents" phase={9} />} />
          <Route path="/studio" element={<ComingSoon title="AI Creation Studio" phase={10} />} />
          <Route path="/explore" element={<ComingSoon title="Explore" phase={11} />} />
          <Route path="/settings" element={<ComingSoon title="Settings" phase={12} />} />
        </Route>
      </Route>
    </Routes>
  );
}
