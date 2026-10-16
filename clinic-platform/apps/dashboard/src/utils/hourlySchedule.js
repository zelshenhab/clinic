const minute = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
const clock = (n) =>
  String(Math.floor(n / 60)).padStart(2, "0") +
  ":" +
  String(n % 60).padStart(2, "0");
function merge(intervals) {
  const out = [];
  for (const pair of intervals.sort((a, b) => a[0] - b[0])) {
    const last = out.at(-1);
    if (last && pair[0] <= last[1]) last[1] = Math.max(last[1], pair[1]);
    else out.push([...pair]);
  }
  return out;
}
function subtract(intervals, start, end) {
  return intervals.flatMap(([a, b]) =>
    b <= start || a >= end
      ? [[a, b]]
      : [
          [a, Math.min(b, start)],
          [Math.max(a, end), b],
        ].filter(([x, y]) => y > x),
  );
}
export function dayIntervals(weekly, day) {
  return merge(
    weekly
      .filter((s) => s.weekday === day)
      .flatMap((s) => {
        let pieces = [[minute(s.start), minute(s.end)]];
        for (const pause of s.breaks || [])
          pieces = subtract(pieces, minute(pause.start), minute(pause.end));
        return pieces;
      }),
  );
}
export function hourEnabled(weekly, day, hour) {
  return dayIntervals(weekly, day).some(
    ([a, b]) => a <= hour * 60 && b >= (hour + 1) * 60,
  );
}
export function toggleHour(weekly, day, hour) {
  const start = hour * 60,
    end = start + 60,
    current = dayIntervals(weekly, day),
    next = hourEnabled(weekly, day, hour)
      ? subtract(current, start, end)
      : merge([...current, [start, end]]);
  return [
    ...weekly.filter((s) => s.weekday !== day),
    ...next.map(([a, b]) => ({
      weekday: day,
      start: clock(a),
      end: clock(b),
      breaks: [],
    })),
  ].sort((a, b) => a.weekday - b.weekday || a.start.localeCompare(b.start));
}
