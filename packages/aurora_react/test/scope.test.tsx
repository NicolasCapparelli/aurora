import {
  type AuroraBorderToken,
  AuroraFoundation,
  AuroraRuntime,
  AuroraSelection,
  AuroraStateError,
  AuroraTextureFoundation,
} from '@aurora/core';
import { act, cleanup, render, screen } from '@testing-library/react';
import { createRef, memo, StrictMode, type ReactNode } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  AuroraController,
  AuroraFixedScope,
  AuroraProvider,
  type AuroraScopeHandle,
  auroraCssVariables,
  useAuroraController,
  useAuroraState,
  useAuroraTexture,
  useAuroraToken,
  useAuroraTokens,
} from '../src/index.js';
import { contract, fixtureTexture, hadestown, installMatchMedia, lightOnly, ticket, wicked } from './helpers.js';

afterEach(cleanup);

const hex = (theme: typeof wicked, appearance: 'light' | 'dark') =>
  theme.variants.get(appearance)!.read(AuroraFoundation.primary).hex;

function Primary(): ReactNode {
  const tokens = useAuroraTokens();
  const state = useAuroraState();
  return (
    <span data-testid="primary">
      {state.theme.id}:{state.variant.appearance}:{tokens.primary.hex}
    </span>
  );
}

function scopeElement(container: HTMLElement): HTMLElement {
  return container.querySelector('[data-aurora-scope]')!;
}

describe('AuroraProvider', () => {
  it('re-renders readers on selection changes and writes CSS variables', () => {
    installMatchMedia(false);
    const controller = new AuroraController({
      contract,
      themes: [wicked, hadestown],
      initialSelection: new AuroraSelection({ themeId: 'wicked' }),
      fallback: 'reject',
    });
    const { container } = render(
      <AuroraProvider controller={controller}>
        <Primary />
      </AuroraProvider>,
    );
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:light:${hex(wicked, 'light')}`);
    act(() => controller.select(new AuroraSelection({ themeId: 'hadestown', appearance: 'dark' })));
    expect(screen.getByTestId('primary').textContent).toBe(`hadestown:dark:${hex(hadestown, 'dark')}`);
    expect(scopeElement(container).style.getPropertyValue('--aurora-colors-primary')).toBe(
      hex(hadestown, 'dark').substring(0, 7),
    );
  });

  it('follows live system appearance changes', () => {
    const media = installMatchMedia(true);
    render(
      <AuroraProvider
        contract={contract}
        themes={[wicked]}
        initialSelection={new AuroraSelection({ themeId: 'wicked' })}
        fallback="reject"
      >
        <Primary />
      </AuroraProvider>,
    );
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:dark:${hex(wicked, 'dark')}`);
    act(() => media.setDark(false));
    expect(screen.getByTestId('primary').textContent).toBe(`wicked:light:${hex(wicked, 'light')}`);
  });

  it('rejected selections and system changes leave the UI unchanged', () => {
    const media = installMatchMedia(false);
    const controller = new AuroraController({
      contract,
      themes: [wicked, lightOnly],
      initialSelection: new AuroraSelection({ themeId: 'lightOnly' }),
      fallback: 'reject',
    });
    const errors: unknown[] = [];
    let renders = 0;
    function Counter(): ReactNode {
      renders++;
      return <Primary />;
    }
    render(
      <AuroraProvider controller={controller} onSystemAppearanceError={(error) => errors.push(error)}>
        <Counter />
      </AuroraProvider>,
    );
    const before = screen.getByTestId('primary').textContent;
    const rendered = renders;
    expect(() => controller.select(new AuroraSelection({ themeId: 'missing' }))).toThrow();
    expect(() => controller.select(new AuroraSelection({ themeId: 'lightOnly', appearance: 'dark' }))).toThrow(
      AuroraStateError,
    );
    act(() => media.setDark(true));
    expect(errors).toHaveLength(1);
    expect(errors[0]).toBeInstanceOf(AuroraStateError);
    expect(screen.getByTestId('primary').textContent).toBe(before);
    expect(renders).toBe(rendered);
  });

  it('owns a managed controller across StrictMode and disposes it on unmount; never disposes a borrowed one', async () => {
    installMatchMedia(false);
    let captured: AuroraController | undefined;
    function Capture(): ReactNode {
      captured = useAuroraController();
      return null;
    }
    const { unmount } = render(
      <StrictMode>
        <AuroraProvider contract={contract} themes={[wicked]} initialSelection={new AuroraSelection({ themeId: 'wicked' })} fallback="reject">
          <Capture />
        </AuroraProvider>
      </StrictMode>,
    );
    await act(async () => {});
    expect(captured!.isDisposed).toBe(false);
    act(() => captured!.select(new AuroraSelection({ themeId: 'wicked', appearance: 'dark' })));
    unmount();
    await act(async () => {});
    expect(captured!.isDisposed).toBe(true);

    const runtime = new AuroraRuntime({
      contract,
      themes: [wicked],
      initialSelection: new AuroraSelection({ themeId: 'wicked' }),
      fallback: 'reject',
    });
    const borrowed = AuroraController.borrow(runtime);
    const second = render(
      <AuroraProvider controller={borrowed}>
        <Primary />
      </AuroraProvider>,
    );
    second.unmount();
    await act(async () => {});
    expect(borrowed.isDisposed).toBe(false);
    expect(runtime.isDisposed).toBe(false);
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
    expect(screen.getByTestId('outer').textContent?.startsWith(light.read(ticket).hex)).toBe(true);
    expect(screen.getByTestId('inner').textContent?.startsWith(dark.read(ticket).hex)).toBe(true);
    expect(screen.getByTestId('inner').textContent).toBe(
      `${dark.read(ticket).hex}|6dp|${dark.read(AuroraFoundation.outlineVariant).hex}`,
    );
    const scopes = container.querySelectorAll<HTMLElement>('[data-aurora-scope]');
    expect(scopes).toHaveLength(2);
    expect(scopes[1]!.style.getPropertyValue('--aurora-colors-primary')).toBe(
      dark.read(AuroraFoundation.primary).hex.substring(0, 7),
    );
    expect(scopes[1]!.style.getPropertyValue('--aurora-demo-lines-cardBorder-color')).toBe(
      dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
    );
  });

  it('has no controller', () => {
    function Bad(): ReactNode {
      useAuroraController();
      return null;
    }
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(() =>
      render(
        <AuroraFixedScope variant={wicked.variants.get('light')!}>
          <Bad />
        </AuroraFixedScope>,
      ),
    ).toThrow(/no selection controller/);
  });

  it('live updates rewrite only changed variables and never re-render the subtree', () => {
    let childRenders = 0;
    const Child = memo(function Child(): ReactNode {
      childRenders++;
      return <span>static</span>;
    });
    const handle = createRef<AuroraScopeHandle>();
    const base = wicked.variants.get('light')!;
    const { container, rerender } = render(
      <AuroraFixedScope ref={handle} variant={base}>
        <Child />
      </AuroraFixedScope>,
    );
    const element = scopeElement(container);
    const setProperty = vi.spyOn(element.style, 'setProperty');
    const removeProperty = vi.spyOn(element.style, 'removeProperty');

    // A slider frame: a variant that differs from the last one in a few tokens.
    const frames = [hadestown.variants.get('light')!, hadestown.variants.get('light')!, base];
    act(() => handle.current!.update(frames[0]!));
    const changed = Object.entries(auroraCssVariables(frames[0]!)).filter(
      ([name, value]) => auroraCssVariables(base)[name] !== value,
    ).length;
    expect(setProperty).toHaveBeenCalledTimes(changed);
    act(() => handle.current!.update(frames[1]!));
    expect(setProperty).toHaveBeenCalledTimes(changed);
    act(() => handle.current!.update(frames[2]!));
    expect(setProperty).toHaveBeenCalledTimes(changed * 2);
    expect(removeProperty).not.toHaveBeenCalled();
    expect(element.style.getPropertyValue('--aurora-colors-primary')).toBe(
      base.read(AuroraFoundation.primary).hex.substring(0, 7),
    );

    // Prop changes from a parent with stable children behave the same way.
    const stableChild = <Child />;
    setProperty.mockClear();
    rerender(
      <AuroraFixedScope ref={handle} variant={frames[0]!}>
        {stableChild}
      </AuroraFixedScope>,
    );
    rerender(
      <AuroraFixedScope ref={handle} variant={frames[0]!}>
        {stableChild}
      </AuroraFixedScope>,
    );
    expect(setProperty).toHaveBeenCalledTimes(changed);
    expect(childRenders).toBe(1);
  });
});
