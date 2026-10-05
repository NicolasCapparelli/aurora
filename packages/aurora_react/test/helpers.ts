import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  AuroraColor,
  AuroraColorToken,
  AuroraContract,
  AuroraFoundation,
  AuroraGenerationRequest,
  AuroraGenerator,
  AuroraAliasRule,
  type AuroraTexture,
  AuroraTextureRecipe,
  type AuroraTheme,
} from '@aurora/core';

export const ticket = new AuroraColorToken('theater.ticket', { description: 'Ticket background.' });
export const contract = new AuroraContract({ id: 'theater', extensions: [ticket] });

export function generated(id: string, primary: string, appearances: ('light' | 'dark')[] = ['light', 'dark']): AuroraTheme {
  return AuroraGenerator.generate(
    new AuroraGenerationRequest({
      contract,
      id,
      name: id,
      primary: AuroraColor.hex(primary),
      appearances,
      preferredAppearance: appearances[0]!,
      rules: [[ticket, new AuroraAliasRule(AuroraFoundation.primaryContainer)]],
    }),
  ).theme;
}

export const wicked = generated('wicked', '#246b35');
export const hadestown = generated('hadestown', '#b3261e');
export const lightOnly = generated('lightOnly', '#0061a4', ['light']);

/** The portable texture recipe fixture: every texture value type, aliases and colour references. */
export function fixtureTexture(): AuroraTexture {
  // jsdom gives modules http URLs, so resolve from the package directory vitest runs in.
  const path = resolve(process.cwd(), '../../spec/fixtures/texture-recipe.json');
  return AuroraTextureRecipe.decode(JSON.parse(readFileSync(path, 'utf8')));
}

/** A controllable `matchMedia('(prefers-color-scheme: dark)')`. */
export function installMatchMedia(initialDark = false): { setDark(dark: boolean): void } {
  let dark = initialDark;
  const listeners = new Set<() => void>();
  const query = {
    get matches() {
      return dark;
    },
    media: '(prefers-color-scheme: dark)',
    addEventListener: (_: string, listener: () => void) => listeners.add(listener),
    removeEventListener: (_: string, listener: () => void) => listeners.delete(listener),
  };
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: () => query });
  return {
    setDark(next: boolean) {
      dark = next;
      for (const listener of [...listeners]) listener();
    },
  };
}
