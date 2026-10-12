import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { LocaleProvider, useLocale } from "../contexts/LocaleContext";
import { AuthProvider, useAuth } from "../contexts/AuthContext";
import { ClinicProvider } from "../contexts/ClinicContext";
import { ToastProvider, useToast } from "../contexts/ToastContext";
import PasswordSetup from "../features/authentication/PasswordSetup";
import LoginPage from "../features/authentication/LoginPage";
import Layout from "../layouts/Layout";
import { Skeleton, Failure } from "../components/Shared";

const client = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 20000, retry: false },
    mutations: { retry: false },
  },
});
function Protected() {
  const auth = useAuth(),
    { t } = useLocale(),
    toast = useToast();
  if (!auth.restored || auth.loading) return <Skeleton />;
  if (!auth.session) return <Navigate to="/login" replace />;
  if (auth.error)
    return (
      <main className="login-form-panel">
        <Failure error={auth.error} retry={auth.retry} />
        <button
          className="button secondary"
          onClick={async () => {
            try {
              await auth.logout();
            } catch {
              toast(t("LOGOUT_FAILED"), "error");
            }
          }}
        >
          {t("logout")}
        </button>
      </main>
    );
  if (!auth.staff) return <Failure error={{ code: "FORBIDDEN" }} />;
  return (
    <ClinicProvider key={auth.staff.id}>
      <Layout />
    </ClinicProvider>
  );
}
export default function App() {
  return (
    <QueryClientProvider client={client}>
      <LocaleProvider>
        <ToastProvider>
          <AuthProvider>
            <BrowserRouter>
              <Routes>
                <Route path="/auth/password" element={<PasswordSetup />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/*" element={<Protected />} />
              </Routes>
            </BrowserRouter>
          </AuthProvider>
        </ToastProvider>
      </LocaleProvider>
    </QueryClientProvider>
  );
}
