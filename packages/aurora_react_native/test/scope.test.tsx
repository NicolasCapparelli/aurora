import {
  AuroraAlias,
  AuroraBorder,
  AuroraBorderToken,
  AuroraColor,
  AuroraContract,
  AuroraDimension,
  AuroraFoundation,
  AuroraGenerationRequest,
  AuroraGenerator,
  AuroraRuntime,
  AuroraSelection,
  AuroraStateError,
  AuroraStrokeStyle,
  AuroraTextureContract,
  AuroraTextureFoundation,
  AuroraTextureStarter,
  AuroraValidationError,
} from '@aurora/core';
import { act, cleanup, render, screen } from '@testing-library/react';
import { createRef, memo, StrictMode, useEffect, type ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  AuroraController,
  AuroraFixedScope,
  AuroraProvider,
  type AuroraScopeHandle,
  systemAppearance,
  useAuroraController,
  useAuroraState,
  useAuroraTexture,
  useAuroraToken,
  useAuroraTokens,
  useMaybeAuroraTexture,
} from '../src/index.js';
import { contract, fixtureTexture, hadestown, lightOnly, ticket, wicked } from './helpers.js';
import { appearanceMock } from './react-native-mock.js';

beforeEach(() => appearanceMock.reset());
afterEach(cleanup);

const hex = (theme: typeof wicked, appearance: 'light' | 'dark') =>
  theme.variants.get(appearance)!.read(AuroraFoundation.primary).hex;

const selection = (themeId: string, appearance?: 'light' | 'dark' | 'system') =>
  new AuroraSelection(appearance === undefined ? { themeId } : { themeId, appearance });

function Primary(): ReactNode {
  const tokens = useAuroraTokens();
  const state = useAuroraState();
  return (
    <span data-testid="primary">
      {state.theme.id}:{state.variant.appearance}:{tokens.primary.hex}
    </span>
  );
}

/** Counts mounts and unmounts of itself, to prove theme changes never remount a subtree. */
function lifecycle() {
  const counts = { mounts: 0, unmounts: 0, renders: 0 };
  const Child = memo(function Child(): ReactNode {
    useEffect(() => {
      counts.mounts++;
      return () => {
        counts.unmounts++;
      };
    }, []);
    counts.renders++;
    return null;
  });
  return { counts, Child };
}

function managedProps(themes = [wicked], fallback: 'reject' | 'preferred' = 'reject') {
  return { contract, themes, initialSelection: selection(themes[0]!.id, 'system'), fallback } as const;
}

describe('systemAppearance', () => {
  it('maps the device scheme, treating anything but dark as light', () => {
    for (const [scheme, expected] of [
      ['dark', 'dark'],
      ['light', 'light'],
      ['unspecified', 'light'],
      [null, 'light'],
      [undefined, 'light'],
    ] as const) {
      appearanceMock.preset(scheme);
      expect(systemAppearance()).toBe(expected);
    }
  });

  it('seeds a controller from the device appearance, and null is light', () => {
    appearanceMock.preset('dark');
    expect(new AuroraController(managedProps()).state.variant.appearance).toBe('dark');
    appearanceMock.preset(null);
    expect(new AuroraController(managedProps()).state.variant.appearance).toBe('light');
  });
});

describe('AuroraController', () => {
  it('notifies synchronously after accepted changes and never after rejected ones', () => {
    const controller = new AuroraController({ ...managedProps([wicked, lightOnly]), systemAppearance: 'light' });
    const listener = vi.fn();
    controller.subscribe(listener);
    controller.select(selection('wicked', 'dark'));
    expect(listener).toHaveBeenCalledTimes(1);
    const before = controller.state;
    expect(() => controller.select(selection('missing'))).toThrow();
    expect(listener).toHaveBeenCalledTimes(1);
    expect(controller.state).toBe(before);
  });

  it('notifies for external changes on a borrowed runtime and leaves the runtime open on dispose', async () => {
    const runtime = new AuroraRuntime({ ...managedProps([wicked]), systemAppearance: 'light' });
    const controller = AuroraController.borrow(runtime);
    const listener = vi.fn();
    controller.subscribe(listener);
    runtime.select(selection('wicked', 'dark'));
    await Promise.resolve();
    await Promise.resolve();
    expect(listener).toHaveBeenCalledTimes(1);
    controller.dispose();
    expect(controller.ownsRuntime).toBe(false);
    expect(runtime.isDisposed).toBe(false);
  });
});

describe('AuroraProvider', () => {
  it('re-renders readers on selection changes without remounting children', () => {
    const controller = new AuroraController({ ...managedProps([wicked, hadestown]), systemAppearance: 'light' });
    const { counts, Child } = lifecycle();
    render(
      <AuroraProvider controller={controller} followSystemAppearance={false}>
        <Primary />
        <Child />
      </AuroraProvider>,
    );
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:light:${hex(wicked, 'light')}`);
    act(() => controller.select(selection('hadestown', 'dark')));
    expect(screen.getByTestId('primary').textContent).toBe(`hadestown:dark:${hex(hadestown, 'dark')}`);
    expect(counts).toMatchObject({ mounts: 1, unmounts: 0, renders: 1 });
  });

  it('renders no host element', () => {
    const { container } = render(
      <AuroraProvider {...managedProps()}>
        <span id="only" />
      </AuroraProvider>,
    );
    expect(container.children).toHaveLength(1);
    expect(container.firstElementChild?.id).toBe('only');
  });

  it('follows live device appearance changes without remounting', () => {
    appearanceMock.preset('dark');
    const { counts, Child } = lifecycle();
    render(
      <AuroraProvider {...managedProps()}>
        <Primary />
        <Child />
      </AuroraProvider>,
    );
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:dark:${hex(wicked, 'dark')}`);
    act(() => appearanceMock.emit('light'));
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:light:${hex(wicked, 'light')}`);
    act(() => appearanceMock.emit(null));
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:light:${hex(wicked, 'light')}`);
    act(() => appearanceMock.emit('dark'));
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:dark:${hex(wicked, 'dark')}`);
    expect(counts).toMatchObject({ mounts: 1, unmounts: 0, renders: 1 });
  });

  it('does not subscribe when followSystemAppearance is false, and removes the listener on unmount', () => {
    const off = render(
      <AuroraProvider {...managedProps()} followSystemAppearance={false}>
        <Primary />
      </AuroraProvider>,
    );
    expect(appearanceMock.listenerCount()).toBe(0);
    off.unmount();

    const on = render(
      <AuroraProvider {...managedProps()}>
        <Primary />
      </AuroraProvider>,
    );
    expect(appearanceMock.listenerCount()).toBe(1);
    on.unmount();
    expect(appearanceMock.listenerCount()).toBe(0);
  });

  it('rejected system appearance changes preserve state and reach onSystemAppearanceError', () => {
    const controller = new AuroraController({
      ...managedProps([lightOnly]),
      initialSelection: selection('lightOnly'),
      systemAppearance: 'light',
    });
    const errors: unknown[] = [];
    const { counts, Child } = lifecycle();
    render(
      <AuroraProvider controller={controller} onSystemAppearanceError={(error) => errors.push(error)}>
        <Primary />
        <Child />
      </AuroraProvider>,
    );
    const before = screen.getByTestId('primary').textContent;
    const state = controller.state;
    expect(() => controller.select(selection('missing'))).toThrow();
    expect(() => controller.select(selection('lightOnly', 'dark'))).toThrow(AuroraStateError);
    act(() => appearanceMock.emit('dark'));
    expect(errors).toHaveLength(1);
    expect(errors[0]).toBeInstanceOf(AuroraStateError);
    expect(controller.state).toBe(state);
    expect(screen.getByTestId('primary').textContent).toBe(before);
    expect(counts).toMatchObject({ mounts: 1, unmounts: 0, renders: 1 });
  });

  it('falls back to console.error without onSystemAppearanceError', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const controller = new AuroraController({
      ...managedProps([lightOnly]),
      initialSelection: selection('lightOnly'),
      systemAppearance: 'light',
    });
    render(
      <AuroraProvider controller={controller}>
        <Primary />
      </AuroraProvider>,
    );
    act(() => appearanceMock.emit('dark'));
    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy.mock.calls[0]![0]).toBeInstanceOf(AuroraStateError);
    spy.mockRestore();
  });

  it('keeps a managed controller across StrictMode and disposes it on real unmount', async () => {
    let captured: AuroraController | undefined;
    function Capture(): ReactNode {
      captured = useAuroraController();
      return null;
    }
    const { unmount } = render(
      <StrictMode>
        <AuroraProvider {...managedProps()}>
          <Capture />
        </AuroraProvider>
      </StrictMode>,
    );
    await act(async () => {});
    expect(captured!.isDisposed).toBe(false);
    act(() => captured!.select(selection('wicked', 'dark')));
    expect(captured!.state.variant.appearance).toBe('dark');
    unmount();
    await act(async () => {});
    expect(captured!.isDisposed).toBe(true);
    expect(captured!.runtime.isDisposed).toBe(true);
  });

  it('never disposes a borrowed controller or its runtime', async () => {
    const runtime = new AuroraRuntime({ ...managedProps(), systemAppearance: 'light' });
    const borrowed = AuroraController.borrow(runtime);
    const { unmount } = render(
      <StrictMode>
        <AuroraProvider controller={borrowed}>
          <Primary />
        </AuroraProvider>
      </StrictMode>,
    );
    unmount();
    await act(async () => {});
    expect(borrowed.isDisposed).toBe(false);
    expect(runtime.isDisposed).toBe(false);
  });

  it('rejects changed managed configuration while mounted', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const { rerender } = render(
      <AuroraProvider {...managedProps([wicked])}>
        <Primary />
      </AuroraProvider>,
    );
    expect(() =>
      rerender(
        <AuroraProvider {...managedProps([wicked, hadestown])}>
          <Primary />
        </AuroraProvider>,
      ),
    ).toThrow(/fixed while mounted/);
    vi.restoreAllMocks();
  });

  it('throws outside a scope', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(() => render(<Primary />)).toThrow(/AuroraProvider or AuroraFixedScope ancestor/);
    vi.restoreAllMocks();
  });
});

describe('AuroraFixedScope', () => {
  it('nests independent scopes and reads typed app tokens and textures', () => {
    const texture = fixtureTexture();
    const cardBorder = texture.contract.tokens.get('demo.lines.cardBorder') as AuroraBorderToken;
    function Probe({ id }: { id: string }): ReactNode {
      const ticketColor = useAuroraToken(ticket);
      const radius = useAuroraToken(AuroraTextureFoundation.mediumShape);
      const view = useAuroraTexture();
      return (
        <span data-testid={id}>
          {ticketColor.hex}|{radius.toString()}|{view.color(view.read(cardBorder).color).hex}
        </span>
      );
    }
    const light = wicked.variants.get('light')!;
    const dark = hadestown.variants.get('dark')!;
    const { container } = render(
      <AuroraFixedScope variant={light} texture={texture}>
        <Probe id="outer" />
        <AuroraFixedScope variant={dark} texture={texture}>
          <Probe id="inner" />
        </AuroraFixedScope>
      </AuroraFixedScope>,
    );
    expect(screen.getByTestId('outer').textContent).toBe(
      `${light.read(ticket).hex}|6dp|${light.read(AuroraFoundation.outlineVariant).hex}`,
    );
    expect(screen.getByTestId('inner').textContent).toBe(
      `${dark.read(ticket).hex}|6dp|${dark.read(AuroraFoundation.outlineVariant).hex}`,
    );
    expect(container.children).toHaveLength(2);
  });

  it('resolves texture colour aliases against the active variant', () => {
    const texture = fixtureTexture();
    let view: ReturnType<typeof useAuroraTexture> | undefined;
    function Probe(): ReactNode {
      view = useAuroraTexture();
      return null;
    }
    const handle = createRef<AuroraScopeHandle>();
    const light = wicked.variants.get('light')!;
    const dark = wicked.variants.get('dark')!;
    render(
      <AuroraFixedScope ref={handle} variant={light} texture={texture}>
        <Probe />
      </AuroraFixedScope>,
    );
    const border = texture.contract.tokens.get('demo.lines.cardBorder') as AuroraBorderToken;
    const lightColor = view!.native.border(border).borderColor;
    expect(lightColor).toBe(light.read(AuroraFoundation.outlineVariant).hex.substring(0, 7));
    act(() => handle.current!.update(dark, texture));
    const darkColor = view!.native.border(border).borderColor;
    expect(darkColor).toBe(dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7));
    expect(darkColor).not.toBe(lightColor);
  });

  it('validates texture colours against the variant contract', () => {
    const textureContract = new AuroraTextureContract({
      id: 'ticketed',
      extensions: [new AuroraBorderToken('demo.ticketBorder', { description: 'Border in the ticket colour.' })],
    });
    const token = textureContract.tokens.get('demo.ticketBorder') as AuroraBorderToken;
    const texture = AuroraTextureStarter.texture({
      contract: textureContract,
      id: 'ticketed',
      name: 'Ticketed',
      values: [
        [
          token,
          new AuroraBorder({
            color: new AuroraAlias(ticket),
            width: AuroraDimension.dp(1),
            style: AuroraStrokeStyle.solid,
          }),
        ],
      ],
    });
    const plain = AuroraGenerator.generate(
      new AuroraGenerationRequest({
        contract: new AuroraContract({ id: 'plain' }),
        id: 'plain',
        name: 'plain',
        primary: AuroraColor.hex('#246b35'),
      }),
    ).theme.variants.get('light')!;
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(() =>
      render(
        <AuroraFixedScope variant={plain} texture={texture}>
          <span />
        </AuroraFixedScope>,
      ),
    ).toThrow(AuroraValidationError);
    vi.restoreAllMocks();
  });

  it('has no controller, and a missing texture is reported', () => {
    function NoController(): ReactNode {
      useAuroraController();
      return null;
    }
    function NoTexture(): ReactNode {
      useAuroraTexture();
      return null;
    }
    function MaybeTexture(): ReactNode {
      return <span data-testid="maybe">{String(useMaybeAuroraTexture())}</span>;
    }
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const variant = wicked.variants.get('light')!;
    expect(() =>
      render(
        <AuroraFixedScope variant={variant}>
          <NoController />
        </AuroraFixedScope>,
      ),
    ).toThrow(/no selection controller/);
    expect(() =>
      render(
        <AuroraFixedScope variant={variant}>
          <NoTexture />
        </AuroraFixedScope>,
      ),
    ).toThrow(/No Aurora texture is active/);
    vi.restoreAllMocks();
    render(
      <AuroraFixedScope variant={variant}>
        <MaybeTexture />
      </AuroraFixedScope>,
    );
    expect(screen.getByTestId('maybe').textContent).toBe('undefined');
  });

  it('live updates notify readers without remounting the subtree', () => {
    const { counts, Child } = lifecycle();
    const handle = createRef<AuroraScopeHandle>();
    const base = wicked.variants.get('light')!;
    const next = hadestown.variants.get('light')!;
    function Reader(): ReactNode {
      return <span data-testid="fixed">{useAuroraTokens().primary.hex}</span>;
    }
    const { rerender } = render(
      <AuroraFixedScope ref={handle} variant={base}>
        <Reader />
        <Child />
      </AuroraFixedScope>,
    );
    expect(screen.getByTestId('fixed').textContent).toBe(hex(wicked, 'light'));
    act(() => handle.current!.update(next));
    expect(screen.getByTestId('fixed').textContent).toBe(hex(hadestown, 'light'));
    act(() => handle.current!.update(base));
    expect(screen.getByTestId('fixed').textContent).toBe(hex(wicked, 'light'));
    // A prop change behaves the same way.
    rerender(
      <AuroraFixedScope ref={handle} variant={next}>
        <Reader />
        <Child />
      </AuroraFixedScope>,
    );
    expect(screen.getByTestId('fixed').textContent).toBe(hex(hadestown, 'light'));
    expect(counts).toMatchObject({ mounts: 1, unmounts: 0 });
  });
});
