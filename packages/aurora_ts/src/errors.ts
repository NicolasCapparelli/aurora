/**
 * Error categories shared with the Dart core. Messages may differ between
 * languages; categories may not.
 *
 * - `validation`: contract completeness or value rules, listing every issue
 *   (Dart `AuroraValidationException`).
 * - `format`: malformed or unsupported input (Dart `FormatException`).
 * - `argument`: an invalid call, such as an unknown theme id (Dart `ArgumentError`).
 * - `state`: an operation the current state does not allow, such as a missing
 *   variant under the reject policy or a disposed runtime (Dart `StateError`).
 */
export type AuroraErrorCategory = 'validation' | 'format' | 'argument' | 'state';

export abstract class AuroraError extends Error {
  abstract readonly category: AuroraErrorCategory;
}

/** Reports every completeness and type problem instead of stopping at the first. */
export class AuroraValidationError extends AuroraError {
  readonly category = 'validation' as const;
  readonly issues: readonly string[];

  constructor(issues: Iterable<string>) {
    const list = Object.freeze([...issues]);
    super(`Aurora validation failed:\n${list.map((issue) => `- ${issue}`).join('\n')}`);
    this.name = 'AuroraValidationError';
    this.issues = list;
  }
}

/** Malformed or unsupported input. */
export class AuroraFormatError extends AuroraError {
  readonly category = 'format' as const;

  constructor(message: string) {
    super(message);
    this.name = 'AuroraFormatError';
  }
}

/** An invalid argument, such as an unknown id or an inconsistent declaration. */
export class AuroraArgumentError extends AuroraError {
  readonly category = 'argument' as const;

  constructor(message: string) {
    super(message);
    this.name = 'AuroraArgumentError';
  }
}

/** The requested operation is not possible in the current state. */
export class AuroraStateError extends AuroraError {
  readonly category = 'state' as const;

  constructor(message: string) {
    super(message);
    this.name = 'AuroraStateError';
  }
}
