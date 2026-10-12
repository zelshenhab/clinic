import { useQuery } from "@tanstack/react-query";
import { api } from "../../services/api";
import { useLocale } from "../../contexts/LocaleContext";
import { QueryState, DataTable } from "../../components/Shared";
export default function ClinicAnalytics({ params }) {
  const { t, text } = useLocale(),
    query = useQuery({
      queryKey: ["cross-clinic-analytics", params],
      queryFn: ({ signal }) => api.get("/admin/analytics", { params, signal }),
    });
  return (
    <section className="panel">
      <h2>{t("crossClinicAnalytics")}</h2>
      <QueryState query={query}>
        {(items) => (
          <DataTable
            rows={items}
            columns={[
              { key: "name", label: "clinic", render: (c) => text(c.name) },
              { key: "timezone" },
              { key: "appointments" },
              { key: "completed" },
              { key: "completed_value_rub" },
            ]}
          />
        )}
      </QueryState>
    </section>
  );
}
