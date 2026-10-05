import {
  type AuroraColor,
  type AuroraColorToken,
  type AuroraRef,
  type AuroraState,
  type AuroraTexture,
  type AuroraThemeVariant,
  type AuroraToken,
  type AuroraTokens,
  resolveTextureColor,
} from '@aurora/core';
import {
  createContext,
  type ElementType,
  type ReactNode,
  type Ref,
  useContext,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
} from 'react';
import { AuroraController, type AuroraControllerInit, DARK_QUERY } from './controller.js';
import { applyAuroraCssVariables, type AuroraCssDeclarations, auroraCssVariables } from './css.js';

/** The values a scope exposes: the active variant and texture. */
export interface AuroraScopeSnapshot {
  readonly variant: AuroraThemeVariant;
  readonly texture: AuroraTexture | undefined;
}

/** A stable object in context; consumers subscribe to it instead of re-rendering through context. */
interface ScopeStore {
  subscribe(listener: () => void): () => void;
  getSnapshot(): AuroraScopeSnapshot;
  readonly controller: AuroraController | undefined;
}

const ScopeContext = createContext<ScopeStore | undefined>(undefined);

function controllerStore(controller: AuroraController): ScopeStore {
  let state: AuroraState | undefined;
  let snapshot: AuroraScopeSnapshot | undefined;
  return {
    controller,
    subscribe: controller.subscribe,
    getSnapshot() {
      const next = controller.state;
      if (next !== state || snapshot === undefined) {
        state = next;
        snapshot = { variant: next.variant, texture: next.texture };
      }
      return snapshot;
    },
  };
}

class FixedStore implements ScopeStore {
  readonly controller = undefined;
  private snapshot: AuroraScopeSnapshot;
  private readonly listeners = new Set<() => void>();

  constructor(variant: AuroraThemeVariant, texture: AuroraTexture | undefined) {
    texture?.validateColors(variant.contract);
    this.snapshot = { variant, texture };
  }

  readonly subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  readonly getSnapshot = (): AuroraScopeSnapshot => this.snapshot;

  set(variant: AuroraThemeVariant, texture: AuroraTexture | undefined): void {
    if (variant === this.snapshot.variant && texture === this.snapshot.texture) return;
    texture?.validateColors(variant.contract);
    this.snapshot = { variant, texture };
    for (const listener of [...this.listeners]) listener();
  }
}

/** Where a scope writes its CSS custom properties. */
export type AuroraCssTarget = 'element' | 'root' | 'none';

interface CssOptions {
  /** Defaults to `element`: the scope's own wrapper element. */
  cssVariables?: AuroraCssTarget;
  /** Custom property prefix; defaults to `aurora`. */
  cssPrefix?: string;
}

/**
 * Writes the store's declarations to the target imperatively, diffing against
 * what it last wrote, so changes never re-render the subtree.
 */
function useCssVariables(store: ScopeStore, target: AuroraCssTarget, prefix: string | undefined, element: () => HTMLElement | null): void {
  useLayoutEffect(() => {
    if (target === 'none') return;
    const node = target === 'root' ? document.documentElement : element();
    if (node === null) return;
    let previous: AuroraCssDeclarations = {};
    const apply = (): void => {
      const { variant, texture } = store.getSnapshot();
      const next = auroraCssVariables(variant, texture, prefix === undefined ? {} : { prefix });
      applyAuroraCssVariables(node, next, previous);
      previous = next;
    };
    apply();
    const stop = store.subscribe(apply);
    return () => {
      stop();
      applyAuroraCssVariables(node, {}, previous);
    };
  }, [store, target, prefix, element]);
}

interface WrapperProps {
  as?: ElementType;
  className?: string;
}

const CONTENTS = { display: 'contents' } as const;

export type AuroraProviderProps = (
  | { controller: AuroraController }
  | AuroraControllerInit
) &
  CssOptions &
  WrapperProps & {
    children?: ReactNode;
    /** Follow `prefers-color-scheme` changes. Defaults to true. */
    followSystemAppearance?: boolean;
    /**
     * Called when the system appearance changes to one the selection cannot
     * show under the `reject` fallback. The state stays unchanged.
     */
    onSystemAppearanceError?: (error: unknown) => void;
  };

function managedKey(props: AuroraControllerInit): unknown[] {
  return [props.contract, props.fallback, ...props.themes, '|', ...(props.textures ?? [])];
}

/**
 * Provides a controller to its subtree. Pass `controller` to borrow one you own
 * (never disposed here), or pass the runtime configuration to let the provider
 * create and dispose its own. Managed configuration is fixed while mounted;
 * give the provider a new `key` to replace it.
 *
 * Only components that read Aurora through hooks re-render on accepted
 * changes; CSS custom properties are written imperatively.
 */
export function AuroraProvider(props: AuroraProviderProps): ReactNode {
  const borrowed = 'controller' in props ? props.controller : undefined;
  const managedInit = borrowed === undefined ? (props as AuroraControllerInit) : undefined;
  const [managed] = useState(() => (managedInit === undefined ? undefined : new AuroraController(managedInit)));
  const [initialKey] = useState(() => (managedInit === undefined ? undefined : managedKey(managedInit)));
  if (managedInit !== undefined && initialKey !== undefined) {
    const key = managedKey(managedInit);
    if (key.length !== initialKey.length || key.some((value, i) => value !== initialKey[i])) {
      throw new Error('AuroraProvider managed configuration is fixed while mounted; give the provider a new key.');
    }
  }
  const controller = borrowed ?? managed!;

  // Dispose an owned controller only after a real unmount. StrictMode runs the
  // cleanup and the effect again synchronously, which this check survives.
  const alive = useRef(false);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      if (managed !== undefined) {
        queueMicrotask(() => {
          if (!alive.current) managed.dispose();
        });
      }
    };
  }, [managed]);

  const follow = props.followSystemAppearance ?? true;
  const onError = props.onSystemAppearanceError;
  useEffect(() => {
    if (!follow || typeof window === 'undefined' || typeof window.matchMedia !== 'function') return;
    const query = window.matchMedia(DARK_QUERY);
    const sync = (): void => {
      try {
        controller.setSystemAppearance(query.matches ? 'dark' : 'light');
      } catch (error) {
        if (onError !== undefined) onError(error);
        else if (typeof reportError === 'function') reportError(error);
      }
    };
    sync();
    query.addEventListener('change', sync);
    return () => query.removeEventListener('change', sync);
  }, [controller, follow, onError]);

  const current = useMemo(() => controllerStore(controller), [controller]);
  const element = useRef<HTMLElement>(null);
  const getElement = useStableGetter(element);
  useCssVariables(current, props.cssVariables ?? 'element', props.cssPrefix, getElement);
  const Tag = props.as ?? 'div';
  return (
    <ScopeContext.Provider value={current}>
      {(props.cssVariables ?? 'element') === 'element' ? (
        <Tag ref={element} data-aurora-scope="" className={props.className} style={CONTENTS}>
          {props.children}
        </Tag>
      ) : (
        props.children
      )}
    </ScopeContext.Provider>
  );
}

function useStableGetter(ref: { current: HTMLElement | null }): () => HTMLElement | null {
  const [getter] = useState(() => () => ref.current);
  return getter;
}

/** Imperative control of a fixed scope, for per-frame updates without rendering. */
export interface AuroraScopeHandle {
  /** Shows [variant] and [texture] now: rewrites changed CSS variables and notifies hook readers. */
  update(variant: AuroraThemeVariant, texture?: AuroraTexture): void;
  /** The wrapper element, when the scope renders one. */
  readonly element: HTMLElement | null;
}

export type AuroraFixedScopeProps = CssOptions &
  WrapperProps & {
    variant: AuroraThemeVariant;
    texture?: AuroraTexture | undefined;
    children?: ReactNode;
    ref?: Ref<AuroraScopeHandle>;
  };

/**
 * Themes a subtree with an immutable variant (and optional texture) without a
 * controller or system-appearance subscription, for previews and gallery
 * thumbnails. Cheap to nest. Changing `variant` or `texture`, or calling
 * `update` on its handle, rewrites only the CSS variables whose values changed
 * and re-renders only components that read Aurora through hooks.
 */
export function AuroraFixedScope(props: AuroraFixedScopeProps): ReactNode {
  const { variant, texture } = props;
  const [store] = useState(() => new FixedStore(variant, texture));
  useLayoutEffect(() => {
    store.set(variant, texture);
  }, [store, variant, texture]);
  const element = useRef<HTMLElement>(null);
  const getElement = useStableGetter(element);
  useImperativeHandle(
    props.ref,
    () => ({
      update: (next: AuroraThemeVariant, nextTexture?: AuroraTexture) => store.set(next, nextTexture),
      get element() {
        return element.current;
      },
    }),
    [store],
  );
  const target = props.cssVariables === 'root' ? 'none' : (props.cssVariables ?? 'element');
  useCssVariables(store, target, props.cssPrefix, getElement);
  const Tag = props.as ?? 'div';
  return (
    <ScopeContext.Provider value={store}>
      {target === 'element' ? (
        <Tag ref={element} data-aurora-scope="" className={props.className} style={CONTENTS}>
          {props.children}
        </Tag>
      ) : (
        props.children
      )}
    </ScopeContext.Provider>
  );
}

// ---------------------------------------------------------------- hooks

function useStore(): ScopeStore {
  const store = useContext(ScopeContext);
  if (store === undefined) {
    throw new Error('Aurora access requires an AuroraProvider or AuroraFixedScope ancestor.');
  }
  return store;
}

/** The nearest scope's variant and texture; re-renders when either changes. */
export function useAuroraScope(): AuroraScopeSnapshot {
  const store = useStore();
  return useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);
}

/** The active theme variant. */
export function useAuroraVariant(): AuroraThemeVariant {
  return useAuroraScope().variant;
}

/** Typed foundation reads for the active variant (`tokens.primary`). */
export function useAuroraTokens(): AuroraTokens {
  return useAuroraScope().variant.tokens;
}

/** A texture bound to the variant it is shown with. */
export interface AuroraTextureView {
  readonly texture: AuroraTexture;
  readonly variant: AuroraThemeVariant;
  /** The resolved value of a texture token. */
  read<T>(token: AuroraToken<T>): T;
  /** A texture colour (literal or theme colour alias) resolved against the variant. */
  color(ref: AuroraRef<AuroraColor>): AuroraColor;
}

const views = new WeakMap<AuroraThemeVariant, WeakMap<AuroraTexture, AuroraTextureView>>();

function textureView(texture: AuroraTexture, variant: AuroraThemeVariant): AuroraTextureView {
  let byTexture = views.get(variant);
  if (byTexture === undefined) {
    byTexture = new WeakMap();
    views.set(variant, byTexture);
  }
  let view = byTexture.get(texture);
  if (view === undefined) {
    view = Object.freeze({
      texture,
      variant,
      read: <T,>(token: AuroraToken<T>): T => texture.read(token),
      color: (ref: AuroraRef<AuroraColor>) => resolveTextureColor(variant, ref),
    });
    byTexture.set(texture, view);
  }
  return view;
}

/** The active texture, or undefined when the scope has none. */
export function useMaybeAuroraTexture(): AuroraTextureView | undefined {
  const { variant, texture } = useAuroraScope();
  return texture === undefined ? undefined : textureView(texture, variant);
}

/** The active texture. Throws when no texture is active. */
export function useAuroraTexture(): AuroraTextureView {
  const view = useMaybeAuroraTexture();
  if (view === undefined) {
    throw new Error(
      'No Aurora texture is active. Register textures on the provider or controller, or pass a texture to AuroraFixedScope.',
    );
  }
  return view;
}

/**
 * A typed read of any token, including app extensions: a colour token reads the
 * active variant; any other token reads the active texture.
 */
export function useAuroraToken(token: AuroraColorToken): AuroraColor;
export function useAuroraToken<T>(token: AuroraToken<T>): T;
export function useAuroraToken<T>(token: AuroraToken<T>): T | AuroraColor {
  const { variant, texture } = useAuroraScope();
  if (token.type === 'color') return variant.read(token as AuroraColorToken);
  if (texture === undefined) throw new Error(`No Aurora texture is active to read ${token.path}.`);
  return texture.read(token);
}

/** The nearest provider's controller. Throws inside a fixed scope. */
export function useAuroraController(): AuroraController {
  const store = useStore();
  if (store.controller === undefined) throw new Error('AuroraFixedScope has no selection controller.');
  return store.controller;
}

/** The nearest provider's full runtime state (selection, theme, variant, texture). */
export function useAuroraState(): AuroraState {
  const controller = useAuroraController();
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
