import { createContext, useContext, useEffect, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../services/api";
import { supabase } from "../services/supabase";
const AuthContext = createContext();
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null),
    [restored, setRestored] = useState(!supabase),
    client = useQueryClient();
  useEffect(() => {
    if (!supabase) return;
    let active = true;
    supabase.auth
      .getSession()
      .then(({ data, error }) => {
        if (active) {
          setSession(error ? null : data.session);
          setRestored(true);
        }
      })
      .catch(() => {
        if (active) {
          setSession(null);
          setRestored(true);
        }
      });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, next) => {
      if (!active) return;
      setSession(next);
      setRestored(true);
      if (!next) {
        client.cancelQueries();
        client.clear();
      }
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [client]);
  const staff = useQuery({
    queryKey: ["staff", session?.user.id],
    queryFn: ({ signal }) => api.get("/admin/me", { signal }),
    enabled: restored && Boolean(session),
    retry: false,
    refetchInterval: 30000,
  });
  const login = async (email, password) => {
    if (!supabase) throw new Error("CONFIGURATION");
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw new Error("LOGIN_FAILED");
  };
  const logout = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw new Error("LOGOUT_FAILED");
    client.clear();
  };
  return (
    <AuthContext.Provider
      value={{
        session,
        restored,
        configured: Boolean(supabase),
        staff: staff.data,
        error: staff.error,
        loading: staff.isPending && Boolean(session),
        retry: staff.refetch,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
export const useAuth = () => useContext(AuthContext);
