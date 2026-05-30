// Seed test proving the Vitest pipeline is wired up correctly.
import { describe, it, expect } from "vitest";
import { humanFileSize, getExtension } from "./utils";

describe("humanFileSize", () => {
  it("returns bytes below the threshold unchanged", () => {
    expect(humanFileSize(0)).toBe("0 B");
    expect(humanFileSize(1023)).toBe("1023 B");
  });

  it("scales to binary units (KiB/MiB) by default", () => {
    expect(humanFileSize(1024)).toBe("1.0 KiB");
    expect(humanFileSize(1048576)).toBe("1.0 MiB");
  });

  it("scales to SI units (kB) when si=true", () => {
    expect(humanFileSize(1000, true)).toBe("1.0 kB");
  });
});

describe("getExtension", () => {
  it("returns the file extension", () => {
    expect(getExtension("audio.mp3", "wav")).toBe("mp3");
  });

  it("returns the last extension for multi-dotted names", () => {
    expect(getExtension("a.b.mp4", "wav")).toBe("mp4");
  });

  it("falls back to the default extension when none is present", () => {
    expect(getExtension("noext", "wav")).toBe("wav");
  });
});
