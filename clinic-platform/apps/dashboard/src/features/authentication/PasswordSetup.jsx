import { useState } from "react";
import { Navigate } from "react-router-dom";
import { supabase } from "../../services/supabase";
import { useAuth } from "../../contexts/AuthContext";
import { useLocale } from "../../contexts/LocaleContext";
import { Submit, Failure } from "../../components/Shared";
export default function PasswordSetup() {
  const { session, restored } = useAuth(),
    { t } = useLocale(),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(null),
    [done, setDone] = useState(false);
  if (done) return <Navigate to="/" replace />;
  return (
    <main className="login-form-panel">
      <h1>{t("setPassword")}</h1>
      {restored && !session ? (
        <Failure error={{ code: "UNAUTHORIZED" }} />
      ) : (
        <form
          className="stack-form"
          onSubmit={async (e) => {
            e.preventDefault();
            const data = new FormData(e.currentTarget),
              password = data.get("password");
            if (password !== data.get("confirm")) {
              setError({ code: "VALIDATION_ERROR" });
              return;
            }
            setBusy(true);
            try {
              const { error } = await supabase.auth.updateUser({ password });
              if (error) throw error;
              setDone(true);
            } catch {
              setError({ code: "AUTH_UNAVAILABLE" });
            } finally {
              setBusy(false);
            }
          }}
        >
          <label>
            {t("password")}
            <input
              name="password"
              type="password"
              minLength={12}
              maxLength={72}
              autoComplete="new-password"
              required
            />
          </label>
          <label>
            {t("confirmPassword")}
            <input
              name="confirm"
              type="password"
              minLength={12}
              maxLength={72}
              autoComplete="new-password"
              required
            />
          </label>
          {error && <Failure error={error} />}
          <Submit busy={busy || !session} />
        </form>
      )}
    </main>
  );
}
