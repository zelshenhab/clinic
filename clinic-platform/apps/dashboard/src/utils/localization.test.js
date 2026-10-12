import { it, expect } from "vitest";
import { messages } from "./localization";
it("provides the same interface in Russian and English", () =>
  expect(Object.keys(messages.ru).sort()).toEqual(
    Object.keys(messages.en).sort(),
  ));
