import { Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing.jsx";
import Login from "./pages/Login.jsx";
import Register from "./pages/Register.jsx";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import DashboardLayout from "./components/DashboardLayout.jsx";
import Dashboard from "./pages/Dashboard.jsx";
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
          <Route path="/assistant" element={<ComingSoon title="AI Study Assistant" phase={6} />} />
          <Route path="/academic" element={<ComingSoon title="Academic Center" phase={7} />} />
          <Route path="/productivity" element={<ComingSoon title="Productivity Center" phase={8} />} />
          <Route path="/documents" element={<ComingSoon title="Documents" phase={9} />} />
          <Route path="/studio" element={<ComingSoon title="AI Creation Studio" phase={10} />} />
          <Route path="/explore" element={<ComingSoon title="Explore" phase={11} />} />
          <Route path="/settings" element={<ComingSoon title="Settings" phase={12} />} />
        </Route>
      </Route>
    </Routes>
  );
}
