import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/** Absolute path of a file under the repository's `spec/` folder. */
export function specPath(path: string): string {
  return fileURLToPath(new URL(`../../../spec/${path}`, import.meta.url));
}

/** Reads a spec file as text. Fixtures are consumed unchanged. */
export function readSpecText(path: string): string {
  return readFileSync(specPath(path), 'utf8');
}

/** A fresh parse of a spec JSON file, so each case can mutate its own copy. */
export function readSpec<T = unknown>(path: string): T {
  return JSON.parse(readSpecText(path)) as T;
}

export interface Mutation {
  path: string[];
  operation: 'remove' | 'set';
  value?: unknown;
}

export interface Scenario {
  name: string;
  mutations: Mutation[];
  expected: 'valid' | 'validation' | 'format';
  values?: Record<string, unknown>;
  colorReferences?: string[];
}

/** Applies `variant-cases.json`-style mutations to [document] in place. */
export function mutate(document: Record<string, unknown>, mutations: readonly Mutation[]): void {
  for (const mutation of mutations) {
    let group = document;
    for (const part of mutation.path.slice(0, -1)) group = group[part] as Record<string, unknown>;
    const last = mutation.path[mutation.path.length - 1]!;
    if (mutation.operation === 'remove') {
      delete group[last];
    } else {
      group[last] = mutation.value;
    }
  }
}
