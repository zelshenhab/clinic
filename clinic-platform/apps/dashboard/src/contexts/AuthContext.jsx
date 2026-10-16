import { createContext, useContext, useEffect, useState, useRef } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../services/api";
import { supabase, clearStoredSession } from "../services/supabase";
const AuthContext = createContext();
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null),
    [restored, setRestored] = useState(!supabase),
    client = useQueryClient(),
    [loggingOut, setLoggingOut] = useState(false),
    logoutTask = useRef(null),
    sessionVersion = useRef(0);
  useEffect(() => {
    if (!supabase) return;
    let active = true;
    const version = sessionVersion.current;
    supabase.auth
      .getSession()
      .then(({ data, error }) => {
        if (active && version === sessionVersion.current) {
          setSession(error ? null : data.session);
          setRestored(true);
        }
      })
      .catch(() => {
        if (active && version === sessionVersion.current) {
          setSession(null);
          setRestored(true);
        }
      });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, next) => {
      if (!active || (logoutTask.current && next)) return;
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
  const logout = () => {
    if (logoutTask.current) return logoutTask.current;
    sessionVersion.current++;
    setLoggingOut(true);
    logoutTask.current = (async () => {
      try {
        if (supabase) await supabase.auth.signOut({ scope: "local" });
      } catch {
        // Local logout still removes this browser's credentials if revocation fails.
      } finally {
        clearStoredSession();
        setSession(null);
        setRestored(true);
        await client.cancelQueries();
        client.clear();
        setLoggingOut(false);
        logoutTask.current = null;
      }
    })();
    return logoutTask.current;
  };
  return (
    <AuthContext.Provider
      value={{
        session,
        loggingOut,
        restored,
        configured: Boolean(supabase),
        staff: session && !loggingOut ? staff.data : undefined,
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
