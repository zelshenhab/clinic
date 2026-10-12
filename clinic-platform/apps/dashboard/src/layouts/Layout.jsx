import { useState } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  HeartPulse,
  LayoutDashboard,
  CalendarDays,
  Calendar,
  Stethoscope,
  Layers,
  Receipt,
  Users,
  Clock,
  Image,
  UserCog,
  Settings,
  Bell,
  ChevronDown,
  Menu,
  X,
  LogOut,
  ShieldCheck,
  ArrowUpRight,
} from "lucide-react";
import { useLocale } from "../contexts/LocaleContext";
import { useClinic } from "../contexts/ClinicContext";
import { useAuth } from "../contexts/AuthContext";
import { useToast } from "../contexts/ToastContext";
import { allowed } from "../utils/permissions";
import { ManagementRoutes } from "../routes/ManagementRoutes";
import { Skeleton, Failure, Empty } from "../components/Shared";
import { useAppointmentRealtime } from "../hooks/useAppointmentRealtime";
import { clinicDate } from "../utils/time";
const navigation = [
  ["overview", "", LayoutDashboard, "overview"],
  ["appointments", "appointments", CalendarDays, "appointments"],
  ["calendar", "calendar", Calendar, "calendar"],
  ["doctors", "doctors", Stethoscope, "catalog"],
  ["specialties", "specialties", Layers, "catalog"],
  ["services", "services", Receipt, "catalog"],
  ["patients", "patients", Users, "patients"],
  ["schedules", "schedules", Clock, "schedules"],
  ["promotions", "promotions", Image, "catalog"],
  ["staff", "staff", UserCog, "staff"],
  ["settings", "settings", Settings, "settings"],
];
export default function Layout() {
  const { t, text, locale, change } = useLocale(),
    { clinic, clinics, access, select, error, loading, retry } = useClinic(),
    auth = useAuth(),
    toast = useToast(),
    location = useLocation();
  const [open, setOpen] = useState(false),
    [notifications, setNotifications] = useState(false),
    [profile, setProfile] = useState(false);
  const realtime = useAppointmentRealtime();
  const page =
    navigation.find((n) => n[1] === location.pathname.slice(1))?.[0] ||
    "overview";
  if (loading) return <Skeleton />;
  if (error) return <Failure error={error} retry={retry} />;
  if (!clinic) return <Empty label={t("noClinics")} />;
  return (
    <div className="workspace">
      <button
        className={`sidebar-overlay ${open ? "show" : ""}`}
        aria-label={t("close")}
        onClick={() => setOpen(false)}
      />
      <aside className={`sidebar ${open ? "open" : ""}`}>
        <NavLink className="brand" to="/">
          <span>
            <HeartPulse size={23} />
          </span>
          {t("brand")}
        </NavLink>
        <div className="workspace-caption">{t("staffWorkspace")}</div>
        <nav>
          {navigation
            .filter((n) => allowed(access?.role, n[3]))
            .map(([label, path, Icon]) => (
              <NavLink
                key={label}
                end
                to={"/" + path}
                onClick={() => setOpen(false)}
              >
                <Icon size={19} />
                <span>{t(label)}</span>
                {label === "appointments" && <span className="nav-dot" />}
              </NavLink>
            ))}
        </nav>
        <div className="sidebar-note">
          <div className="icon-chip">
            <ShieldCheck size={22} />
          </div>
          <strong>{t("staffOnly")}</strong>
          <small>{t(access?.role)}</small>
        </div>
      </aside>
      <div className="workspace-main">
        <header className="topbar">
          <button
            className="mobile-toggle icon-button"
            onClick={() => setOpen(true)}
            aria-label={t("staffWorkspace")}
          >
            <Menu />
          </button>
          <div className="breadcrumbs">
            <span>{t("brand")}</span>
            <span>/</span>
            <strong>{t(page)}</strong>
          </div>
          <div className="topbar-actions">
            <div className="clinic-switch">
              <span className="clinic-dot" />
              <select
                aria-label={t("clinic")}
                value={clinic.id}
                onChange={(e) => select(e.target.value)}
              >
                {clinics.map((c) => (
                  <option key={c.id} value={c.id}>
                    {text(c.name)}
                  </option>
                ))}
              </select>
            </div>
            <button
              className="language"
              onClick={() => change(locale === "ru" ? "en" : "ru")}
            >
              {locale === "ru" ? "EN" : "RU"}
            </button>
            <div className="popover-wrap">
              <button
                className="icon-button"
                aria-label={t("notifications")}
                onClick={() => setNotifications(!notifications)}
              >
                <Bell size={20} />
                {realtime.events.length > 0 && (
                  <span className="notification-dot" />
                )}
              </button>
              {notifications && (
                <div className="popover">
                  <h3>{t("notifications")}</h3>
                  {!realtime.events.length ? (
                    <p>{t("empty")}</p>
                  ) : (
                    realtime.events.map((e) => (
                      <p key={e.id}>
                        {t("appointmentsUpdated")}
                        <small>
                          {clinicDate(e.at, clinic.timezone, locale)}
                        </small>
                      </p>
                    ))
                  )}
                </div>
              )}
            </div>
            <div className="popover-wrap">
              <button
                className="profile-button"
                onClick={() => setProfile(!profile)}
                aria-label={t("profile")}
              >
                <span className="avatar">
                  {auth.staff.email?.slice(0, 1).toUpperCase() || "•"}
                </span>
                <span className="profile-text">
                  <strong>{auth.staff.email}</strong>
                  <small>{t(access?.role)}</small>
                </span>
                <ChevronDown size={16} />
              </button>
              {profile && (
                <div className="popover">
                  <strong>{auth.staff.email}</strong>
                  <p>{t(access?.role)}</p>
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
                    <LogOut size={17} />
                    {t("logout")}
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>
        <main className="content">
          <div className="clinic-context">
            <span className={`connection ${realtime.status}`}>
              <i />
              {t(realtime.status)}
            </span>
            <span>
              {text(clinic.name)} · {clinic.timezone}
            </span>
          </div>
          {!clinic.active && (
            <div className="notice">{t("clinicInactive")}</div>
          )}
          <div key={clinic.id}>
            <ManagementRoutes />
          </div>
          <footer>
            {t("staffWorkspace")}
            <span>{text(clinic.name)}</span>
          </footer>
        </main>
      </div>
    </div>
  );
}
