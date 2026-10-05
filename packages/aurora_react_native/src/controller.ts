import {
  type AuroraAppearance,
  AuroraRuntime,
  type AuroraRuntimeInit,
  type AuroraSelection,
  type AuroraState,
} from '@aurora/core';
import { Appearance } from 'react-native';

/**
 * Maps a React Native color scheme to an Aurora appearance. Only `dark` is dark;
 * `light`, `unspecified`, `null` and `undefined` are light.
 */
export function appearanceFromColorScheme(scheme: string | null | undefined): AuroraAppearance {
  return scheme === 'dark' ? 'dark' : 'light';
}

/** The device's current appearance from `Appearance.getColorScheme()`, light when unknown. */
export function systemAppearance(): AuroraAppearance {
  return appearanceFromColorScheme(Appearance.getColorScheme());
}

export type AuroraControllerInit = Omit<AuroraRuntimeInit, 'systemAppearance'> & {
  /** Defaults to the device appearance from `Appearance.getColorScheme()`. */
  systemAppearance?: AuroraAppearance;
};

/**
 * Wraps an `AuroraRuntime` and notifies listeners synchronously after each
 * accepted change, which is what `useSyncExternalStore` needs. Rejected changes
 * throw and notify nobody.
 *
 * Ownership follows the Flutter adapter: `new AuroraController(init)` creates
 * and owns its runtime and disposes it in {@link dispose};
 * {@link AuroraController.borrow} wraps a runtime the caller owns and never
 * disposes it.
 */
export class AuroraController {
  readonly runtime: AuroraRuntime;
  readonly ownsRuntime: boolean;
  private readonly listeners = new Set<() => void>();
  private disposed = false;
  private notified: AuroraState;
  private readonly stopListening: () => void;

  constructor(init: AuroraControllerInit | { runtime: AuroraRuntime }) {
    if ('runtime' in init) {
      this.runtime = init.runtime;
      this.ownsRuntime = false;
    } else {
      this.runtime = new AuroraRuntime({ ...init, systemAppearance: init.systemAppearance ?? systemAppearance() });
      this.ownsRuntime = true;
    }
    this.notified = this.runtime.state;
    // Changes made on the runtime directly (for example by other code holding a
    // borrowed runtime) arrive asynchronously; notify for those as well.
    this.stopListening = this.runtime.listen(() => this.notifyIfChanged());
  }

  /** A controller over a caller-owned runtime; disposing it leaves the runtime open. */
  static borrow(runtime: AuroraRuntime): AuroraController {
    return new AuroraController({ runtime });
  }

  get state(): AuroraState {
    return this.runtime.state;
  }

  /** Stable snapshot accessor for `useSyncExternalStore`. */
  readonly getSnapshot = (): AuroraState => this.runtime.state;

  /** Synchronous subscription for `useSyncExternalStore`. */
  readonly subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  select(selection: AuroraSelection): void {
    this.mutate(() => this.runtime.select(selection));
  }

  setSystemAppearance(appearance: AuroraAppearance): void {
    this.mutate(() => this.runtime.setSystemAppearance(appearance));
  }

  /** Pairs a theme with a texture, or removes the pairing when undefined. */
  pairTexture(themeId: string, textureId: string | undefined): void {
    this.mutate(() => this.runtime.pairTexture(themeId, textureId));
  }

  private mutate(change: () => void): void {
    change();
    this.notifyIfChanged();
  }

  private notifyIfChanged(): void {
    if (this.disposed || this.runtime.state === this.notified) return;
    this.notified = this.runtime.state;
    for (const listener of [...this.listeners]) listener();
  }

  get isDisposed(): boolean {
    return this.disposed;
  }

  /** Stops notifications; disposes the runtime only when this controller owns it. */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.listeners.clear();
    this.stopListening();
    if (this.ownsRuntime) this.runtime.dispose();
  }
}
