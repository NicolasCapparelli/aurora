// A minimal stand-in for `react-native` in tests: only `Appearance`.
type Scheme = 'light' | 'dark' | 'unspecified' | null | undefined;
type Listener = (preferences: { colorScheme: Scheme }) => void;

let scheme: Scheme = 'light';
const listeners = new Set<Listener>();

export const Appearance = {
  getColorScheme(): Scheme {
    return scheme;
  },
  addChangeListener(listener: Listener): { remove(): void } {
    listeners.add(listener);
    return {
      remove() {
        listeners.delete(listener);
      },
    };
  },
};

/** Test control over the mocked device appearance. */
export const appearanceMock = {
  /** Sets the scheme without notifying anyone (the device state before mount). */
  preset(next: Scheme): void {
    scheme = next;
  },
  /** Changes the scheme and notifies every listener, like a device settings change. */
  emit(next: Scheme): void {
    scheme = next;
    for (const listener of [...listeners]) listener({ colorScheme: next });
  },
  listenerCount(): number {
    return listeners.size;
  },
  reset(): void {
    scheme = 'light';
    listeners.clear();
  },
};
