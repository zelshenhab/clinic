import { createContext, useContext, useState, useEffect } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../services/api";
import { clinicAccess } from "../utils/permissions";
import { useAuth } from "./AuthContext";
const ClinicContext = createContext();
export function ClinicProvider({ children }) {
  const { staff } = useAuth(),
    client = useQueryClient();
  const [id, setId] = useState(() =>
    localStorage.getItem(`staff-clinic:${staff.id}`),
  );
  const clinics = useQuery({
    queryKey: [
      "authorized-clinics",
      staff.id,
      staff.memberships
        .map((m) => m.id + ":" + m.role + ":" + m.doctor_id)
        .join(","),
    ],
    queryFn: ({ signal }) => api.get("/admin/clinics", { signal }),
    retry: false,
  });
  const clinic = clinics.data?.find((c) => c.id === id);
  const access = clinicAccess(staff.memberships, clinic?.id);
  useEffect(() => {
    if (clinics.data?.length && !clinics.data.some((c) => c.id === id))
      setId(clinics.data.find((c) => c.active)?.id || clinics.data[0].id);
  }, [clinics.data, id]);
  function select(next) {
    if (!clinics.data?.some((c) => c.id === next)) return;
    client.cancelQueries({ predicate: (q) => q.queryKey[0] === "clinic" });
    client.removeQueries({ predicate: (q) => q.queryKey[0] === "clinic" });
    setId(next);
    localStorage.setItem(`staff-clinic:${staff.id}`, next);
  }
  return (
    <ClinicContext.Provider
      value={{
        clinic,
        clinics: clinics.data || [],
        access,
        select,
        error: clinics.error,
        loading: clinics.isPending,
        retry: clinics.refetch,
      }}
    >
      {children}
    </ClinicContext.Provider>
  );
}
export const useClinic = () => useContext(ClinicContext);
