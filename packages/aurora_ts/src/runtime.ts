import type { AuroraContract } from './contract.js';
import { AuroraArgumentError, AuroraFormatError, AuroraStateError } from './errors.js';
import { hasOwn, isJsonObject } from './json.js';
import type { AuroraTexture, AuroraTextureContract } from './texture.js';
import {
  type AuroraAppearance,
  type AuroraAppearancePreference,
  type AuroraTheme,
  type AuroraThemeVariant,
  parseAppearancePreference,
} from './theme.js';

/** A missing variant either fails or uses the theme's explicitly preferred one. */
export type AuroraVariantFallback = 'reject' | 'preferred';

/** Stored selection JSON. `textureId` is present only for an explicit texture choice. */
export interface AuroraSelectionJson {
  themeId: string;
  appearance: AuroraAppearancePreference;
  textureId?: string;
}

export interface AuroraSelectionInit {
  themeId: string;
  appearance?: AuroraAppearancePreference;
  /**
   * The texture the user chose explicitly. Undefined uses the theme's paired
   * texture, or no texture when the theme has no pairing.
   */
  textureId?: string | undefined;
}

export interface AuroraSelectionRestoreInit {
  themeId?: string | undefined;
  preference?: string | undefined;
  themes: Iterable<AuroraTheme>;
  fallbackId: string;
  textureId?: string | undefined;
  textures?: Iterable<AuroraTexture>;
}

/** A theme identity, appearance preference and optional explicit texture. */
export class AuroraSelection {
  readonly themeId: string;
  readonly appearance: AuroraAppearancePreference;
  readonly textureId: string | undefined;

  constructor(init: AuroraSelectionInit) {
    this.themeId = init.themeId;
    this.appearance = init.appearance ?? 'system';
    this.textureId = init.textureId;
    Object.freeze(this);
  }

  /**
   * Restore settings without performing IO or resolving missing variants. The
   * fallback identity must exist; variant policy remains the runtime's job. A
   * texture id that is not among the registered textures restores to
   * undefined, which uses the theme's paired texture.
   */
  static restore(init: AuroraSelectionRestoreInit): AuroraSelection {
    const ids = new Set([...init.themes].map((theme) => theme.id));
    if (!ids.has(init.fallbackId)) throw new AuroraArgumentError(`Unknown fallback theme ${init.fallbackId}`);
    const textureIds = new Set([...(init.textures ?? [])].map((texture) => texture.id));
    return new AuroraSelection({
      themeId: init.themeId !== undefined && ids.has(init.themeId) ? init.themeId : init.fallbackId,
      appearance: parseAppearancePreference(init.preference) ?? 'system',
      textureId: init.textureId !== undefined && textureIds.has(init.textureId) ? init.textureId : undefined,
    });
  }

  /** Forgiving stored-data boundary; malformed fields use restore defaults. */
  static restoreJson(
    json: unknown,
    options: { themes: Iterable<AuroraTheme>; fallbackId: string; textures?: Iterable<AuroraTexture> },
  ): AuroraSelection {
    const map = isJsonObject(json) ? json : {};
    const text = (value: unknown): string | undefined => (typeof value === 'string' ? value : undefined);
    return AuroraSelection.restore({
      themeId: text(map['themeId']),
      preference: text(map['appearance']),
      themes: options.themes,
      fallbackId: options.fallbackId,
      textureId: text(map['textureId']),
      ...(options.textures === undefined ? {} : { textures: options.textures }),
    });
  }

  /** Strict decoding: rejects malformed or unknown fields. */
  static fromJson(json: unknown): AuroraSelection {
    const map = isJsonObject(json) ? json : undefined;
    const id = map?.['themeId'];
    const appearance = parseAppearancePreference(map?.['appearance']);
    const textureId = map?.['textureId'];
    if (
      map === undefined ||
      typeof id !== 'string' ||
      id.trim() === '' ||
      appearance === undefined ||
      (hasOwn(map, 'textureId') && (typeof textureId !== 'string' || textureId.trim() === '')) ||
      Object.keys(map).some((key) => key !== 'themeId' && key !== 'appearance' && key !== 'textureId')
    ) {
      throw new AuroraFormatError('Expected themeId, appearance and optional textureId selection fields');
    }
    return new AuroraSelection({ themeId: id, appearance, textureId: textureId as string | undefined });
  }

  toJson(): AuroraSelectionJson {
    return {
      themeId: this.themeId,
      appearance: this.appearance,
      ...(this.textureId === undefined ? {} : { textureId: this.textureId }),
    };
  }

  equals(other: AuroraSelection): boolean {
    return other.themeId === this.themeId && other.appearance === this.appearance && other.textureId === this.textureId;
  }
}

/** Immutable snapshot of the requested selection and its resolved values. */
export class AuroraState {
  constructor(
    readonly selection: AuroraSelection,
    readonly theme: AuroraTheme,
    readonly variant: AuroraThemeVariant,
    /** The active texture: the selected one, else the theme's paired one, else undefined. */
    readonly texture: AuroraTexture | undefined = undefined,
  ) {
    Object.freeze(this);
  }
}

export interface AuroraRuntimeInit {
  contract: AuroraContract;
  themes: Iterable<AuroraTheme>;
  initialSelection: AuroraSelection;
  fallback: AuroraVariantFallback;
  /** The host's current system appearance; defaults to light. */
  systemAppearance?: AuroraAppearance;
  textures?: Iterable<AuroraTexture>;
  /** Theme id to the texture id it uses when the selection names none. */
  texturePairings?: Readonly<Record<string, string>> | ReadonlyMap<string, string>;
}

export type AuroraStateListener = (state: AuroraState) => void;

/**
 * Framework-free selection runtime. Rejected changes leave selection and
 * active values intact. Accepted changes are delivered asynchronously, in
 * order, to listeners registered with {@link AuroraRuntime.listen}, matching the
 * Dart runtime's broadcast stream; read {@link AuroraRuntime.state} for the
 * current snapshot.
 */
export class AuroraRuntime {
  readonly contract: AuroraContract;
  readonly fallback: AuroraVariantFallback;
  readonly themes: ReadonlyMap<string, AuroraTheme>;
  /** Registered textures by id; empty when the app does not use textures. */
  readonly textures: ReadonlyMap<string, AuroraTexture>;
  private readonly pairings = new Map<string, string>();
  private systemAppearance: AuroraAppearance;
  private current: AuroraState;
  private readonly listeners = new Set<AuroraStateListener>();
  private disposed = false;

  constructor(init: AuroraRuntimeInit) {
    this.contract = init.contract;
    this.fallback = init.fallback;
    this.systemAppearance = init.systemAppearance ?? 'light';
    const textures = [...(init.textures ?? [])];
    const textureRegistry = new Map<string, AuroraTexture>();
    for (const texture of textures) {
      if (texture.contract !== textures[0]!.contract) {
        throw new AuroraArgumentError('Textures must use the same texture contract instance');
      }
      if (textureRegistry.has(texture.id)) throw new AuroraArgumentError(`Duplicate texture id ${texture.id}`);
      texture.validateColors(init.contract);
      textureRegistry.set(texture.id, texture);
    }
    this.textures = textureRegistry;
    const registry = new Map<string, AuroraTheme>();
    for (const theme of init.themes) {
      if (theme.contract !== init.contract) throw new AuroraArgumentError(`Theme ${theme.id} uses a different contract`);
      if (registry.has(theme.id)) throw new AuroraArgumentError(`Duplicate theme id ${theme.id}`);
      registry.set(theme.id, theme);
    }
    this.themes = registry;
    const pairings = init.texturePairings instanceof Map ? init.texturePairings : new Map(Object.entries(init.texturePairings ?? {}));
    for (const [themeId, textureId] of pairings) {
      this.checkPairing(themeId, textureId);
      this.pairings.set(themeId, textureId);
    }
    this.current = this.resolve(init.initialSelection, this.systemAppearance);
  }

  /** The shared texture contract, or undefined when no textures are registered. */
  get textureContract(): AuroraTextureContract | undefined {
    return this.textures.values().next().value?.contract;
  }

  /** Theme id to paired texture id. */
  get texturePairings(): ReadonlyMap<string, string> {
    return new Map(this.pairings);
  }

  get state(): AuroraState {
    return this.current;
  }

  /** The system appearance used for `system` preferences. */
  get system(): AuroraAppearance {
    return this.systemAppearance;
  }

  /**
   * Delivers each later accepted change asynchronously (on a microtask) and in
   * order. Returns a function that stops delivery. A disposed runtime delivers
   * nothing.
   */
  listen(listener: AuroraStateListener): () => void {
    if (this.disposed) return () => {};
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Changes as an async iterable, ending after the runtime is disposed. */
  changes(): AsyncIterable<AuroraState> {
    const runtime = this;
    return {
      [Symbol.asyncIterator](): AsyncIterator<AuroraState, undefined> {
        const queue: AuroraState[] = [];
        let wake: (() => void) | undefined;
        let closed = runtime.disposed;
        const stop = runtime.listen((state) => {
          queue.push(state);
          wake?.();
        });
        const onClose = (): void => {
          closed = true;
          wake?.();
        };
        runtime.closeHandlers.add(onClose);
        const finish = (): IteratorReturnResult<undefined> => {
          stop();
          runtime.closeHandlers.delete(onClose);
          return { value: undefined, done: true };
        };
        return {
          async next() {
            while (true) {
              if (queue.length > 0) return { value: queue.shift()!, done: false };
              if (closed) return finish();
              await new Promise<void>((resolve) => {
                wake = resolve;
              });
              wake = undefined;
            }
          },
          async return() {
            return finish();
          },
        };
      },
    };
  }

  private readonly closeHandlers = new Set<() => void>();

  private resolve(selection: AuroraSelection, system: AuroraAppearance): AuroraState {
    const theme = this.themes.get(selection.themeId);
    if (theme === undefined) throw new AuroraArgumentError(`Unknown theme ${selection.themeId}`);
    const appearance: AuroraAppearance = selection.appearance === 'system' ? system : selection.appearance;
    const variant =
      theme.variants.get(appearance) ??
      (this.fallback === 'preferred' ? theme.variants.get(theme.preferredAppearance) : undefined);
    if (variant === undefined) throw new AuroraStateError(`Theme ${theme.id} has no ${appearance} variant`);
    const textureId = selection.textureId ?? this.pairings.get(theme.id);
    let texture: AuroraTexture | undefined;
    if (textureId !== undefined) {
      texture = this.textures.get(textureId);
      if (texture === undefined) {
        throw new AuroraArgumentError(
          this.textures.size === 0
            ? `Texture ${textureId} selected, but no textures are registered`
            : `Unknown texture ${textureId}`,
        );
      }
    }
    return new AuroraState(selection, theme, variant, texture);
  }

  private checkPairing(themeId: string, textureId: string | undefined): void {
    if (!this.themes.has(themeId)) throw new AuroraArgumentError(`Unknown theme ${themeId}`);
    if (textureId !== undefined && !this.textures.has(textureId)) {
      throw new AuroraArgumentError(`Unknown texture ${textureId}`);
    }
  }

  private emit(state: AuroraState): void {
    this.current = state;
    const listeners = [...this.listeners];
    void Promise.resolve().then(() => {
      for (const listener of listeners) {
        if (this.listeners.has(listener)) listener(state);
      }
    });
  }

  /**
   * Pairs [themeId] with [textureId], or removes its pairing when undefined.
   * Selections without an explicit texture use the active theme's pairing.
   */
  pairTexture(themeId: string, textureId: string | undefined): void {
    this.ensureOpen();
    this.checkPairing(themeId, textureId);
    if (this.pairings.get(themeId) === textureId) return;
    if (textureId === undefined) {
      this.pairings.delete(themeId);
    } else {
      this.pairings.set(themeId, textureId);
    }
    const next = this.resolve(this.current.selection, this.systemAppearance);
    if (next.texture === this.current.texture) return;
    this.emit(next);
  }

  select(selection: AuroraSelection): void {
    this.ensureOpen();
    const next = this.resolve(selection, this.systemAppearance);
    if (this.current.selection.equals(selection)) return;
    this.emit(next);
  }

  setSystemAppearance(appearance: AuroraAppearance): void {
    this.ensureOpen();
    if (this.systemAppearance === appearance) return;
    const next = this.resolve(this.current.selection, appearance);
    this.systemAppearance = appearance;
    if (next.variant === this.current.variant) return;
    this.emit(next);
  }

  private ensureOpen(): void {
    if (this.disposed) throw new AuroraStateError('AuroraRuntime has been disposed');
  }

  get isDisposed(): boolean {
    return this.disposed;
  }

  /** Stops accepting changes. Already scheduled deliveries still run. */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    void Promise.resolve().then(() => {
      this.listeners.clear();
      for (const close of [...this.closeHandlers]) close();
    });
  }
}
