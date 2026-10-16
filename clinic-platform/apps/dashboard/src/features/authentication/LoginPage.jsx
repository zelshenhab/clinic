import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Navigate } from "react-router-dom";
import { HeartPulse, ArrowRight, ShieldCheck } from "lucide-react";
import { useAuth } from "../../contexts/AuthContext";
import { useLocale } from "../../contexts/LocaleContext";
import { Submit, Failure, Skeleton } from "../../components/Shared";
const schema = z.object({ email: z.email(), password: z.string().min(8) });
export default function LoginPage() {
  const auth = useAuth(),
    { t, locale, change } = useLocale();
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm({ resolver: zodResolver(schema) });
  if (auth.loggingOut) return <Skeleton />;
  if (auth.session && auth.staff) return <Navigate to="/" replace />;
  return (
    <main className="login">
      <aside className="login-story">
        <div className="brand">
          <HeartPulse /> {t("brand")}
        </div>
        <div className="login-message">
          <span className="eyebrow">{t("staffWorkspace")}</span>
          <h1>{t("loginHeadline")}</h1>
          <p>{t("loginDescription")}</p>
          <div className="orbit">
            <HeartPulse size={110} />
          </div>
        </div>
        <p className="trust">
          <ShieldCheck size={18} />
          {t("staffOnly")}
        </p>
      </aside>
      <section className="login-form-panel">
        <button
          className="language"
          onClick={() => change(locale === "ru" ? "en" : "ru")}
        >
          {locale === "ru" ? "EN" : "RU"}
        </button>
        <div className="login-form">
          <div className="brand mobile">
            <HeartPulse />
            {t("brand")}
          </div>
          <h2>{t("welcomeBack")}</h2>
          <p>{t("loginHelp")}</p>
          {!auth.configured ? (
            <Failure error={{ code: "CONFIGURATION" }} />
          ) : (
            <form
              className="stack-form"
              onSubmit={handleSubmit(async (input) => {
                try {
                  await auth.login(input.email, input.password);
                } catch {
                  setError("root", { message: t("LOGIN_FAILED") });
                }
              })}
            >
              <label>
                {t("email")}
                <input
                  type="email"
                  autoComplete="username"
                  {...register("email")}
                />
                {errors.email && (
                  <small className="field-error">{t("invalidEmail")}</small>
                )}
              </label>
              <label>
                {t("password")}
                <input
                  type="password"
                  autoComplete="current-password"
                  {...register("password")}
                />
                {errors.password && (
                  <small className="field-error">{t("invalidPassword")}</small>
                )}
              </label>
              {errors.root && (
                <p role="alert" className="field-error">
                  {errors.root.message}
                </p>
              )}
              <Submit busy={isSubmitting}>
                {t("login")}
                <ArrowRight size={18} />
              </Submit>
            </form>
          )}
          {auth.error && <Failure error={auth.error} retry={auth.retry} />}
          <p className="fine-print">{t("inviteOnly")}</p>
        </div>
      </section>
    </main>
  );
}
