import { useState } from "react";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import {
  QueryState,
  DataTable,
  Pagination,
  Status,
  Dialog,
  Failure,
} from "../../components/Shared";
import { clinicDate } from "../../utils/time";
import WorkingHours from "./WorkingHours";
export default function RequestReview() {
  const { t, text, locale } = useLocale(),
    { clinic } = useClinic(),
    [page, setPage] = useState(1),
    [status, setStatus] = useState("pending"),
    [request, setRequest] = useState(null),
    q = useAdminQuery("doctor-requests", {
      page,
      limit: 20,
      ...(status ? { status } : {}),
    });
  return (
    <section className="panel">
      <h2>{t("doctorRequests")}</h2>
      <select
        aria-label={t("requestStatus")}
        value={status}
        onChange={(e) => {
          setStatus(e.target.value);
          setPage(1);
        }}
      >
        <option value="">{t("all")}</option>
        {["pending", "approved", "rejected"].map((s) => (
          <option key={s} value={s}>
            {t(s)}
          </option>
        ))}
      </select>
      <QueryState query={q}>
        {(d) => (
          <>
            <DataTable
              rows={d.items}
              columns={[
                { key: "doctor_name", render: (r) => text(r.doctor_name) },
                { key: "kind", render: (r) => t("request_" + r.kind) },
                { key: "reason" },
                { key: "status", render: (r) => <Status value={r.status} /> },
                {
                  key: "created_at",
                  render: (r) =>
                    clinicDate(r.created_at, clinic.timezone, locale),
                },
                {
                  key: "actions",
                  render: (r) => (
                    <button
                      className="text-button"
                      onClick={() => setRequest(r)}
                    >
                      {t("view")}
                    </button>
                  ),
                },
              ]}
            />
            <Pagination value={d.pagination} onPage={setPage} />
          </>
        )}
      </QueryState>
      {request && (
        <ReviewDialog record={request} onClose={() => setRequest(null)} />
      )}
    </section>
  );
}
function ReviewDialog({ record, onClose }) {
  const { t, text, locale } = useLocale(),
    { clinic } = useClinic(),
    [note, setNote] = useState(""),
    [decision, setDecision] = useState(null),
    m = useAdminMutation("doctor-requests/" + record.id, "patch");
  return (
    <Dialog title={t("doctorRequests")} onClose={onClose}>
      <h2>{text(record.doctor_name)}</h2>
      <Status value={record.status} />
      <p>{t("request_" + record.kind)}</p>
      <p>{record.reason}</p>
      {record.kind === "schedule" ? (
        <WorkingHours data={record.payload} />
      ) : (
        <div className="detail-grid">
          {["appointment_id", "starts_at", "ends_at"]
            .filter((k) => record.payload[k])
            .map((k) => (
              <div key={k}>
                <small>{t(k)}</small>
                <strong>
                  {k === "appointment_id"
                    ? record.payload[k]
                    : clinicDate(record.payload[k], clinic.timezone, locale)}
                </strong>
              </div>
            ))}
        </div>
      )}
      {record.status === "pending" ? (
        <>
          <p className="notice">{t("approvalConflictHelp")}</p>
          <label>
            {t("review_note")}
            <textarea
              aria-label={t("review_note")}
              maxLength={2000}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </label>
          <div className="action-row">
            <button className="button" onClick={() => setDecision(true)}>
              {t("approve")}
            </button>
            <button
              className="button danger"
              onClick={() => setDecision(false)}
            >
              {t("reject")}
            </button>
          </div>
          {decision !== null && (
            <div className="confirmation">
              <p>
                {t("confirmAction")}: {t(decision ? "approve" : "reject")}
              </p>
              <button
                className="button"
                disabled={m.isPending}
                onClick={() =>
                  m.mutate({ approve: decision, note }, { onSuccess: onClose })
                }
              >
                {t("confirm")}
              </button>
            </div>
          )}
        </>
      ) : (
        <p>{record.review_note}</p>
      )}
      {m.error && <Failure error={m.error} />}
    </Dialog>
  );
}
