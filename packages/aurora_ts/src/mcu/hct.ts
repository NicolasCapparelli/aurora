// Ported from material_color_utilities 0.11.1 (Dart), hct/viewing_conditions.dart,
// hct/cam16.dart and hct/hct.dart. Copyright 2021 Google LLC. Apache-2.0; see
// LICENSE-material-color-utilities and NOTICE.md in this package.
import * as utils from './utils.js';
import { solveToInt } from './hct_solver.js';

export class ViewingConditions {
  constructor(
    readonly whitePoint: number[],
    readonly adaptingLuminance: number,
    readonly backgroundLstar: number,
    readonly surround: number,
    readonly discountingIlluminant: boolean,
    readonly backgroundYTowhitePointY: number,
    readonly aw: number,
    readonly nbb: number,
    readonly ncb: number,
    readonly c: number,
    readonly nC: number,
    readonly drgbInverse: number[],
    readonly rgbD: number[],
    readonly fl: number,
    readonly fLRoot: number,
    readonly z: number,
  ) {}

  static make(
    whitePoint: number[] = utils.whitePointD65(),
    adaptingLuminance = -1.0,
    backgroundLstar = 50.0,
    surround = 2.0,
    discountingIlluminant = false,
  ): ViewingConditions {
    adaptingLuminance =
      adaptingLuminance > 0.0 ? adaptingLuminance : ((200.0 / Math.PI) * utils.yFromLstar(50.0)) / 100.0;
    backgroundLstar = Math.max(0.1, backgroundLstar);
    const xyz = whitePoint;
    const rW = xyz[0]! * 0.401288 + xyz[1]! * 0.650173 + xyz[2]! * -0.051461;
    const gW = xyz[0]! * -0.250268 + xyz[1]! * 1.204414 + xyz[2]! * 0.045854;
    const bW = xyz[0]! * -0.002079 + xyz[1]! * 0.048952 + xyz[2]! * 0.953127;
    const f = 0.8 + surround / 10.0;
    const c = f >= 0.9 ? utils.lerp(0.59, 0.69, (f - 0.9) * 10.0) : utils.lerp(0.525, 0.59, (f - 0.8) * 10.0);
    let d = discountingIlluminant ? 1.0 : f * (1.0 - (1.0 / 3.6) * Math.exp((-adaptingLuminance - 42.0) / 92.0));
    d = d > 1.0 ? 1.0 : d < 0.0 ? 0.0 : d;
    const nc = f;
    const rgbD = [d * (100.0 / rW) + 1.0 - d, d * (100.0 / gW) + 1.0 - d, d * (100.0 / bW) + 1.0 - d];
    const k = 1.0 / (5.0 * adaptingLuminance + 1.0);
    const k4 = k * k * k * k;
    const k4F = 1.0 - k4;
    const fl = k4 * adaptingLuminance + 0.1 * k4F * k4F * Math.pow(5.0 * adaptingLuminance, 1.0 / 3.0);
    const n = utils.yFromLstar(backgroundLstar) / whitePoint[1]!;
    const z = 1.48 + Math.sqrt(n);
    const nbb = 0.725 / Math.pow(n, 0.2);
    const ncb = nbb;
    const rgbAFactors = [
      Math.pow((fl * rgbD[0]! * rW) / 100.0, 0.42),
      Math.pow((fl * rgbD[1]! * gW) / 100.0, 0.42),
      Math.pow((fl * rgbD[2]! * bW) / 100.0, 0.42),
    ];
    const rgbA = rgbAFactors.map((factor) => (400.0 * factor) / (factor + 27.13));
    const aw = ((40.0 * rgbA[0]! + 20.0 * rgbA[1]! + rgbA[2]!) / 20.0) * nbb;
    return new ViewingConditions(
      whitePoint,
      adaptingLuminance,
      backgroundLstar,
      surround,
      discountingIlluminant,
      n,
      aw,
      nbb,
      ncb,
      c,
      nc,
      [0.0, 0.0, 0.0],
      rgbD,
      fl,
      Math.pow(fl, 0.25),
      z,
    );
  }

  static readonly sRgb = ViewingConditions.make();
  static readonly standard = ViewingConditions.sRgb;
}

export class Cam16 {
  constructor(
    readonly hue: number,
    readonly chroma: number,
    readonly j: number,
    readonly q: number,
    readonly m: number,
    readonly s: number,
    readonly jstar: number,
    readonly astar: number,
    readonly bstar: number,
  ) {}

  distance(other: Cam16): number {
    const dJ = this.jstar - other.jstar;
    const dA = this.astar - other.astar;
    const dB = this.bstar - other.bstar;
    const dEPrime = Math.sqrt(dJ * dJ + dA * dA + dB * dB);
    return 1.41 * Math.pow(dEPrime, 0.63);
  }

  static fromInt(argb: number): Cam16 {
    return Cam16.fromIntInViewingConditions(argb, ViewingConditions.sRgb);
  }

  static fromIntInViewingConditions(argb: number, viewingConditions: ViewingConditions): Cam16 {
    const xyz = utils.xyzFromArgb(argb);
    return Cam16.fromXyzInViewingConditions(xyz[0]!, xyz[1]!, xyz[2]!, viewingConditions);
  }

  static fromXyzInViewingConditions(x: number, y: number, z: number, vc: ViewingConditions): Cam16 {
    const rC = 0.401288 * x + 0.650173 * y - 0.051461 * z;
    const gC = -0.250268 * x + 1.204414 * y + 0.045854 * z;
    const bC = -0.002079 * x + 0.048952 * y + 0.953127 * z;
    const rD = vc.rgbD[0]! * rC;
    const gD = vc.rgbD[1]! * gC;
    const bD = vc.rgbD[2]! * bC;
    const rAF = Math.pow((vc.fl * Math.abs(rD)) / 100.0, 0.42);
    const gAF = Math.pow((vc.fl * Math.abs(gD)) / 100.0, 0.42);
    const bAF = Math.pow((vc.fl * Math.abs(bD)) / 100.0, 0.42);
    const rA = (utils.signum(rD) * 400.0 * rAF) / (rAF + 27.13);
    const gA = (utils.signum(gD) * 400.0 * gAF) / (gAF + 27.13);
    const bA = (utils.signum(bD) * 400.0 * bAF) / (bAF + 27.13);
    const a = (11.0 * rA + -12.0 * gA + bA) / 11.0;
    const b = (rA + gA - 2.0 * bA) / 9.0;
    const u = (20.0 * rA + 20.0 * gA + 21.0 * bA) / 20.0;
    const p2 = (40.0 * rA + 20.0 * gA + bA) / 20.0;
    const atan2 = Math.atan2(b, a);
    const atanDegrees = (atan2 * 180.0) / Math.PI;
    const hue = atanDegrees < 0 ? atanDegrees + 360.0 : atanDegrees >= 360 ? atanDegrees - 360 : atanDegrees;
    const hueRadians = (hue * Math.PI) / 180.0;
    const ac = p2 * vc.nbb;
    const J = 100.0 * Math.pow(ac / vc.aw, vc.c * vc.z);
    const Q = (4.0 / vc.c) * Math.sqrt(J / 100.0) * (vc.aw + 4.0) * vc.fLRoot;
    const huePrime = hue < 20.14 ? hue + 360 : hue;
    const eHue = (1.0 / 4.0) * (Math.cos((huePrime * Math.PI) / 180.0 + 2.0) + 3.8);
    const p1 = (50000.0 / 13.0) * eHue * vc.nC * vc.ncb;
    const t = (p1 * Math.sqrt(a * a + b * b)) / (u + 0.305);
    const alpha = Math.pow(t, 0.9) * Math.pow(1.64 - Math.pow(0.29, vc.backgroundYTowhitePointY), 0.73);
    const C = alpha * Math.sqrt(J / 100.0);
    const M = C * vc.fLRoot;
    const s = 50.0 * Math.sqrt((alpha * vc.c) / (vc.aw + 4.0));
    const jstar = ((1.0 + 100.0 * 0.007) * J) / (1.0 + 0.007 * J);
    const mstar = Math.log(1.0 + 0.0228 * M) / 0.0228;
    const astar = mstar * Math.cos(hueRadians);
    const bstar = mstar * Math.sin(hueRadians);
    return new Cam16(hue, C, J, Q, M, s, jstar, astar, bstar);
  }

  static fromJch(j: number, c: number, h: number): Cam16 {
    return Cam16.fromJchInViewingConditions(j, c, h, ViewingConditions.sRgb);
  }

  static fromJchInViewingConditions(J: number, C: number, h: number, vc: ViewingConditions): Cam16 {
    const Q = (4.0 / vc.c) * Math.sqrt(J / 100.0) * (vc.aw + 4.0) * vc.fLRoot;
    const M = C * vc.fLRoot;
    const alpha = C / Math.sqrt(J / 100.0);
    const s = 50.0 * Math.sqrt((alpha * vc.c) / (vc.aw + 4.0));
    const hueRadians = (h * Math.PI) / 180.0;
    const jstar = ((1.0 + 100.0 * 0.007) * J) / (1.0 + 0.007 * J);
    const mstar = (1.0 / 0.0228) * Math.log(1.0 + 0.0228 * M);
    const astar = mstar * Math.cos(hueRadians);
    const bstar = mstar * Math.sin(hueRadians);
    return new Cam16(h, C, J, Q, M, s, jstar, astar, bstar);
  }

  static fromUcs(jstar: number, astar: number, bstar: number): Cam16 {
    return Cam16.fromUcsInViewingConditions(jstar, astar, bstar, ViewingConditions.standard);
  }

  static fromUcsInViewingConditions(jstar: number, astar: number, bstar: number, vc: ViewingConditions): Cam16 {
    const a = astar;
    const b = bstar;
    const m = Math.sqrt(a * a + b * b);
    const M = (Math.exp(m * 0.0228) - 1.0) / 0.0228;
    const c = M / vc.fLRoot;
    let h = Math.atan2(b, a) * (180.0 / Math.PI);
    if (h < 0.0) h += 360.0;
    const j = jstar / (1 - (jstar - 100) * 0.007);
    return Cam16.fromJchInViewingConditions(j, c, h, vc);
  }

  toInt(): number {
    return this.viewed(ViewingConditions.sRgb);
  }

  viewed(vc: ViewingConditions): number {
    const xyz = this.xyzInViewingConditions(vc);
    return utils.argbFromXyz(xyz[0]!, xyz[1]!, xyz[2]!);
  }

  xyzInViewingConditions(vc: ViewingConditions): number[] {
    const alpha = this.chroma === 0.0 || this.j === 0.0 ? 0.0 : this.chroma / Math.sqrt(this.j / 100.0);
    const t = Math.pow(alpha / Math.pow(1.64 - Math.pow(0.29, vc.backgroundYTowhitePointY), 0.73), 1.0 / 0.9);
    const hRad = (this.hue * Math.PI) / 180.0;
    const eHue = 0.25 * (Math.cos(hRad + 2.0) + 3.8);
    const ac = vc.aw * Math.pow(this.j / 100.0, 1.0 / vc.c / vc.z);
    const p1 = eHue * (50000.0 / 13.0) * vc.nC * vc.ncb;
    const p2 = ac / vc.nbb;
    const hSin = Math.sin(hRad);
    const hCos = Math.cos(hRad);
    const gamma = (23.0 * (p2 + 0.305) * t) / (23.0 * p1 + 11 * t * hCos + 108.0 * t * hSin);
    const a = gamma * hCos;
    const b = gamma * hSin;
    const rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
    const gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
    const bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
    const rCBase = Math.max(0, (27.13 * Math.abs(rA)) / (400.0 - Math.abs(rA)));
    const rC = utils.signum(rA) * (100.0 / vc.fl) * Math.pow(rCBase, 1.0 / 0.42);
    const gCBase = Math.max(0, (27.13 * Math.abs(gA)) / (400.0 - Math.abs(gA)));
    const gC = utils.signum(gA) * (100.0 / vc.fl) * Math.pow(gCBase, 1.0 / 0.42);
    const bCBase = Math.max(0, (27.13 * Math.abs(bA)) / (400.0 - Math.abs(bA)));
    const bC = utils.signum(bA) * (100.0 / vc.fl) * Math.pow(bCBase, 1.0 / 0.42);
    const rF = rC / vc.rgbD[0]!;
    const gF = gC / vc.rgbD[1]!;
    const bF = bC / vc.rgbD[2]!;
    const x = 1.86206786 * rF - 1.01125463 * gF + 0.14918677 * bF;
    const y = 0.38752654 * rF + 0.62144744 * gF - 0.00897398 * bF;
    const z = -0.0158415 * rF - 0.03412294 * gF + 1.04996444 * bF;
    return [x, y, z];
  }
}

export class Hct {
  private _hue = 0;
  private _chroma = 0;
  private _tone = 0;
  private _argb = 0;

  private constructor(argb: number) {
    this.setInternalState(argb);
  }

  static from(hue: number, chroma: number, tone: number): Hct {
    return new Hct(solveToInt(hue, chroma, tone));
  }

  static fromInt(argb: number): Hct {
    return new Hct(argb >>> 0);
  }

  toInt(): number {
    return this._argb;
  }

  get hue(): number {
    return this._hue;
  }

  set hue(newHue: number) {
    this.setInternalState(solveToInt(newHue, this._chroma, this._tone));
  }

  get chroma(): number {
    return this._chroma;
  }

  set chroma(newChroma: number) {
    this.setInternalState(solveToInt(this._hue, newChroma, this._tone));
  }

  get tone(): number {
    return this._tone;
  }

  set tone(newTone: number) {
    this.setInternalState(solveToInt(this._hue, this._chroma, newTone));
  }

  equals(other: Hct): boolean {
    return other._argb === this._argb;
  }

  private setInternalState(argb: number): void {
    this._argb = argb;
    const cam16 = Cam16.fromInt(argb);
    this._hue = cam16.hue;
    this._chroma = cam16.chroma;
    this._tone = utils.lstarFromArgb(argb);
  }

  inViewingConditions(vc: ViewingConditions): Hct {
    const cam16 = Cam16.fromInt(this.toInt());
    const viewedInVc = cam16.xyzInViewingConditions(vc);
    const recastInVc = Cam16.fromXyzInViewingConditions(
      viewedInVc[0]!,
      viewedInVc[1]!,
      viewedInVc[2]!,
      ViewingConditions.make(),
    );
    return Hct.from(recastInVc.hue, recastInVc.chroma, utils.lstarFromY(viewedInVc[1]!));
  }
}
