import { createContext, useContext, useEffect, useState } from "react";
import api from "../api.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(!!localStorage.getItem("token"));

  useEffect(() => {
    if (!localStorage.getItem("token")) return;
    api
      .get("/auth/me/")
      .then((res) => setUser(res.data))
      .catch(() => localStorage.removeItem("token"))
      .finally(() => setLoading(false));
  }, []);

  const saveSession = (data) => {
    localStorage.setItem("token", data.token);
    setUser(data.user);
  };

  const login = async (email, password) => {
    const { data } = await api.post("/auth/login/", { email, password });
    saveSession(data);
  };

  const register = async (payload) => {
    const { data } = await api.post("/auth/register/", payload);
    saveSession(data);
  };

  const logout = async () => {
    try {
      await api.post("/auth/logout/");
    } catch {
      // token pehle se invalid ho to bhi local logout kar do
    }
    localStorage.removeItem("token");
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
