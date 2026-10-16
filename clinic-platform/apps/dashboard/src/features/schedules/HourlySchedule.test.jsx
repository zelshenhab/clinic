// @vitest-environment jsdom
import { it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useForm } from "react-hook-form";
import HourlySchedule from "./HourlySchedule";
vi.mock("../../contexts/LocaleContext", () => ({
  useLocale: () => ({ locale: "en", t: (key) => key }),
}));
it("renders all 168 hour controls and saves late-night and early-morning choices", async () => {
  const saved = vi.fn();
  function Editor() {
    const form = useForm({ defaultValues: { weekly: [] } });
    return (
      <form onSubmit={form.handleSubmit(saved)}>
        <HourlySchedule form={form} />
        <button type="submit">Save</button>
      </form>
    );
  }
  render(<Editor />);
  const user = userEvent.setup();
  expect(screen.getAllByRole("button", { pressed: false })).toHaveLength(168);
  await user.click(
    screen.getByRole("button", { name: "Mon 23:00", exact: true }),
  );
  await user.click(
    screen.getByRole("button", { name: "Tue 00:00", exact: true }),
  );
  expect(
    screen
      .getByRole("button", { name: "Mon 23:00" })
      .getAttribute("aria-pressed"),
  ).toBe("true");
  await user.click(screen.getByRole("button", { name: "Save", exact: true }));
  await waitFor(() => expect(saved).toHaveBeenCalled());
  expect(saved.mock.calls[0][0].weekly).toEqual([
    { weekday: 1, start: "23:00", end: "24:00", breaks: [] },
    { weekday: 2, start: "00:00", end: "01:00", breaks: [] },
  ]);
});
