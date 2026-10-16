import { it, expect } from "vitest";
import { toggleHour, hourEnabled, dayIntervals } from "./hourlySchedule";
import { scheduleFormSchema } from "./formSchemas";
it("opens midnight and late-night hours and merges adjacent periods", () => {
  let weekly = toggleHour([], 1, 23);
  expect(weekly).toEqual([
    { weekday: 1, start: "23:00", end: "24:00", breaks: [] },
  ]);
  weekly = toggleHour(weekly, 1, 22);
  weekly = toggleHour(weekly, 2, 0);
  expect(hourEnabled(weekly, 1, 23)).toBe(true);
  expect(hourEnabled(weekly, 2, 0)).toBe(true);
  expect(hourEnabled(weekly, 1, 0)).toBe(false);
  expect(scheduleFormSchema.safeParse({ weekly, exceptions: [] }).success).toBe(
    true,
  );
});
it("closing an hour splits a shift without reopening a break or changing another day", () => {
  const weekly = [
    {
      weekday: 1,
      start: "00:00",
      end: "24:00",
      breaks: [{ start: "13:00", end: "14:00" }],
    },
    { weekday: 2, start: "02:00", end: "03:00", breaks: [] },
  ];
  const changed = toggleHour(weekly, 1, 8);
  expect(dayIntervals(changed, 1)).toEqual([
    [0, 480],
    [540, 780],
    [840, 1440],
  ]);
  expect(hourEnabled(changed, 1, 13)).toBe(false);
  expect(changed.find((s) => s.weekday === 2)).toEqual(weekly[1]);
});
it("all seven days may have alternating available hours", () => {
  let weekly = [];
  for (let day = 0; day < 7; day++)
    for (let hour = 0; hour < 24; hour += 2)
      weekly = toggleHour(weekly, day, hour);
  expect(weekly).toHaveLength(84);
  expect(scheduleFormSchema.safeParse({ weekly, exceptions: [] }).success).toBe(
    true,
  );
});
