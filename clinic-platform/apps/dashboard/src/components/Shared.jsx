import { useEffect, useRef } from "react";
import {
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  Inbox,
  LoaderCircle,
} from "lucide-react";
import { useLocale } from "../contexts/LocaleContext";
export function Skeleton() {
  return (
    <div className="skeletons" aria-busy="true">
      {[1, 2, 3, 4].map((i) => (
        <div className="skeleton" key={i} />
      ))}
    </div>
  );
}
export function Empty({ label }) {
  const { t } = useLocale();
  return (
    <div className="empty">
      <Inbox size={34} />
      <h3>{label || t("empty")}</h3>
      <p>{t("emptyBody")}</p>
    </div>
  );
}
export function Failure({ error, retry }) {
  const { t } = useLocale();
  return (
    <div className="failure" role="alert">
      <AlertCircle />
      <div>
        <h3>{t(error?.code || "unexpected")}</h3>
        {error?.details?.appointmentIds?.length > 0 && (
          <p>
            {t("conflictingAppointments")}:{" "}
            {error.details.appointmentIds.join(", ")}
          </p>
        )}
        {error?.details?.fields?.length > 0 && (
          <ul>
            {error.details.fields.map((f, i) => (
              <li key={i}>
                {t(
                  f.path.filter((p) => typeof p === "string").at(-1) ||
                    "fieldInvalid",
                )}
                : {t("fieldInvalid")}
              </li>
            ))}
          </ul>
        )}
        {retry && (
          <button className="button secondary" onClick={() => retry()}>
            {t("retry")}
          </button>
        )}
      </div>
    </div>
  );
}
export function QueryState({ query, children }) {
  if (query.isPending) return <Skeleton />;
  if (
    query.error &&
    (query.data === undefined || [401, 403].includes(query.error.status))
  )
    return <Failure error={query.error} retry={query.refetch} />;
  return (
    <>
      {query.error && <Failure error={query.error} retry={query.refetch} />}
      <div
        aria-busy={query.isFetching || undefined}
        className={query.isPlaceholderData ? "query-updating" : undefined}
      >
        {children(query.data)}
      </div>
    </>
  );
}
export function Status({ value }) {
  const { t } = useLocale();
  return <span className={`status ${value}`}>{t(value)}</span>;
}
export function Pagination({ value, onPage }) {
  value = value?.pagination || value;
  const { t } = useLocale();
  return (
    <div className="pagination">
      <span>
        {t("total")}: {value?.total || 0}
      </span>
      <button
        aria-label={t("previous")}
        disabled={!value || value.page === 1}
        onClick={() => onPage(value.page - 1)}
      >
        <ChevronLeft size={18} />
      </button>
      <span>{value?.page || 1}</span>
      <button
        aria-label={t("next")}
        disabled={!value?.hasMore}
        onClick={() => onPage(value.page + 1)}
      >
        <ChevronRight size={18} />
      </button>
    </div>
  );
}
export function DataTable({ columns, rows, rowKey = "id", onRow }) {
  const { t } = useLocale();
  if (!rows.length) return <Empty />;
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key}>{t(c.label || c.key)}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row[rowKey]}>
              {columns.map((c) => (
                <td key={c.key}>
                  {c.render ? c.render(row) : (row[c.key] ?? "—")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
export function Dialog({ title, children, onClose }) {
  const ref = useRef();
  const { t } = useLocale();
  useEffect(() => {
    const dialog = ref.current;
    dialog.showModal();
    return () => dialog.close();
  }, []);
  return (
    <dialog ref={ref} className="dialog" onCancel={onClose}>
      <div className="dialog-head">
        <h2>{title}</h2>
        <button onClick={onClose} aria-label={t("close")}>
          ×
        </button>
      </div>
      {children}
    </dialog>
  );
}
export function Submit({ busy, disabled = false, children }) {
  const { t } = useLocale();
  return (
    <button className="button" type="submit" disabled={busy || disabled}>
      {busy ? (
        <LoaderCircle className="spin" size={18} />
      ) : (
        children || t("save")
      )}
    </button>
  );
}
export function PageHeader({ title, subtitle, actions }) {
  const { t } = useLocale();
  return (
    <div className="page-heading">
      <div>
        <div className="eyebrow">{t("operations")}</div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {actions}
    </div>
  );
}
