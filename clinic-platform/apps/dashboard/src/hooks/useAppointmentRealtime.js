import { useEffect, useState, useRef } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { supabase } from "../services/supabase";
import { useAuth } from "../contexts/AuthContext";
import { useClinic } from "../contexts/ClinicContext";
export function useAppointmentRealtime() {
  const { session } = useAuth(),
    { clinic, access } = useClinic(),
    client = useQueryClient(),
    [status, setStatus] = useState("connecting"),
    [events, setEvents] = useState([]);
  const seen = useRef(new Set());
  useEffect(() => {
    setEvents([]);
    seen.current.clear();
    if (!supabase || !clinic || !access) return;
    let active = true,
      timer;
    const id = clinic.id;
    const invalidate = () => {
      if (active) client.invalidateQueries({ queryKey: ["clinic", id] });
    };
    const receive = ({ payload }) => {
      if (
        !active ||
        payload?.clinic_id !== id ||
        !payload?.event_id ||
        seen.current.has(payload.event_id)
      )
        return;
      seen.current.add(payload.event_id);
      if (seen.current.size > 500)
        seen.current.delete(seen.current.values().next().value);
      setEvents((v) =>
        [
          {
            id: payload.event_id,
            at: new Date().toISOString(),
            kind: payload.request_id ? "request" : "appointment",
          },
          ...v,
        ].slice(0, 8),
      );
      clearTimeout(timer);
      timer = setTimeout(invalidate, 150);
    };
    let channel;
    (async () => {
      await supabase.realtime.setAuth(session.access_token);
      if (!active) return;
      channel = supabase
        .channel(`staff:${id}:${session.user.id}`, {
          config: { private: true },
        })
        .on("broadcast", { event: "appointment_changed" }, receive)
        .on("broadcast", { event: "doctor_request_changed" }, receive)
        .subscribe((state) => {
          if (!active) return;
          setStatus(
            state === "SUBSCRIBED"
              ? "live"
              : state === "CHANNEL_ERROR" ||
                  state === "TIMED_OUT" ||
                  state === "CLOSED"
                ? "disconnected"
                : "connecting",
          );
          if (state === "SUBSCRIBED") invalidate();
        });
    })().catch(() => {
      if (active) setStatus("disconnected");
    });
    return () => {
      active = false;
      clearTimeout(timer);
      if (channel) supabase.removeChannel(channel);
    };
  }, [
    clinic?.id,
    access?.role,
    access?.doctor_id,
    session?.access_token,
    client,
  ]);
  return { status, events };
}
