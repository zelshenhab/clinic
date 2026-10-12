// Presentation only: position authoritative appointment timestamps; never calculate slots.
export function calendarLanes(items) {
  const groups = new Map();
  for (const item of items) {
    if (!groups.has(item.doctor_id)) groups.set(item.doctor_id, []);
    groups.get(item.doctor_id).push(item);
  }
  const placed = [];
  let groupIndex = 0;
  for (const records of groups.values()) {
    const ends = [],
      positions = [];
    for (const record of [...records].sort(
      (a, b) =>
        Date.parse(a.starts_at) - Date.parse(b.starts_at) ||
        a.id.localeCompare(b.id),
    )) {
      const start = Date.parse(record.starts_at);
      let lane = ends.findIndex((end) => end <= start);
      if (lane < 0) lane = ends.length;
      ends[lane] = Date.parse(record.ends_at);
      positions.push({ record, lane });
    }
    for (const position of positions)
      placed.push({
        ...position,
        left: ((groupIndex + position.lane / ends.length) / groups.size) * 100,
        width: 100 / groups.size / ends.length,
      });
    groupIndex++;
  }
  return placed;
}
