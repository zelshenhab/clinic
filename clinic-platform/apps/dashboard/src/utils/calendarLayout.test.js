import { it, expect } from "vitest";
import { calendarLanes } from "./calendarLayout";
it("separates doctor columns and overlapping events without changing timestamps", () => {
  const items = [
    {
      id: "a",
      doctor_id: "d1",
      starts_at: "2026-10-12T09:00:00Z",
      ends_at: "2026-10-12T10:00:00Z",
    },
    {
      id: "b",
      doctor_id: "d2",
      starts_at: "2026-10-12T09:00:00Z",
      ends_at: "2026-10-12T10:00:00Z",
    },
    {
      id: "c",
      doctor_id: "d1",
      starts_at: "2026-10-12T09:30:00Z",
      ends_at: "2026-10-12T10:30:00Z",
    },
  ];
  const positions = calendarLanes(items);
  expect(positions.map((p) => [p.record.id, p.left, p.width])).toEqual([
    ["a", 0, 25],
    ["c", 25, 25],
    ["b", 50, 50],
  ]);
  expect(
    positions.map((p) => p.record).sort((a, b) => a.id.localeCompare(b.id)),
  ).toEqual(items);
});
