import { describe, expect, it } from 'vitest';
import { Hct } from '../src/mcu/hct.js';
import { Contrast } from '../src/mcu/palette.js';
import { dartMod, dartRound } from '../src/mcu/utils.js';

// The pinned generator is checked end to end by the spec fixtures. These cover
// the Dart semantics the port depends on.
describe('MCU 0.11.1 port', () => {
  it('rounds and wraps like Dart', () => {
    expect(dartRound(-2.5)).toBe(-3);
    expect(dartRound(2.5)).toBe(3);
    expect(dartMod(-10, 360)).toBe(350);
    expect(dartMod(370, 360)).toBe(10);
  });

  it('round-trips sRGB through HCT', () => {
    for (const argb of [0xff000000, 0xffffffff, 0xff246b35, 0xffe60023, 0xff0061a4]) {
      const hct = Hct.fromInt(argb);
      expect(Hct.from(hct.hue, hct.chroma, hct.tone).toInt()).toBe(argb >>> 0);
    }
  });

  it('measures tone contrast', () => {
    expect(Contrast.ratioOfTones(0, 100)).toBeCloseTo(21, 5);
  });
});
