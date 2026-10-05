import { AuroraStateError } from './errors.js';
import type { AuroraToken } from './token.js';

/**
 * A literal primitive value, such as a line height of `1.4`. Aurora's value
 * classes (such as `AuroraDimension`) are their own literals and need no wrapper.
 */
export class AuroraLiteral<T> {
  readonly kind = 'literal' as const;
  constructor(readonly value: T) {
    Object.freeze(this);
  }

  toString(): string {
    return String(this.value);
  }
}

/**
 * A reference to another token. Aliases between texture tokens resolve when a
 * texture is constructed. An alias to a colour token inside a texture refers to
 * the active theme and resolves against the active theme variant.
 */
export class AuroraAlias<T> {
  readonly kind = 'alias' as const;
  constructor(readonly target: AuroraToken<T>) {
    Object.freeze(this);
  }

  toString(): string {
    return `{${this.target.path}}`;
  }
}

/** Aurora value classes, which are their own literal references. */
type SelfLiteral<T> = T extends { readonly kind: string } ? T : never;

/** A value or a reference to another token of the same value type. */
export type AuroraRef<T> = SelfLiteral<T> | AuroraLiteral<T> | AuroraAlias<T>;

export function isAlias(value: unknown): value is AuroraAlias<unknown> {
  return typeof value === 'object' && value !== null && (value as { kind?: unknown }).kind === 'alias';
}

export function isLiteral(value: unknown): value is AuroraLiteral<unknown> {
  return typeof value === 'object' && value !== null && (value as { kind?: unknown }).kind === 'literal';
}

/**
 * The literal value of [ref]. Values read from a texture are always resolved;
 * authored values may still hold aliases, which throw here.
 */
export function resolvedRef<T>(ref: AuroraRef<T>, field: string): T {
  if (isAlias(ref)) {
    throw new AuroraStateError(
      `${field} is an unresolved alias to ${ref.target.path}; read resolved values from a texture`,
    );
  }
  if (isLiteral(ref)) return ref.value as T;
  return ref as T;
}

/** Structural equality for references: same literal value or same alias target. */
export function refEquals(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (isAlias(a) && isAlias(b)) return a.target.path === b.target.path && a.target.type === b.target.type;
  if (isLiteral(a) && isLiteral(b)) return valueEquals(a.value, b.value);
  return valueEquals(a, b);
}

/** Equality for Aurora values: value classes compare by content. */
export function valueEquals(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a === 'object' && a !== null && typeof (a as { equals?: unknown }).equals === 'function') {
    return (a as { equals(other: unknown): boolean }).equals(b);
  }
  return false;
}
