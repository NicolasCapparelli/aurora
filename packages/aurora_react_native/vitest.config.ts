import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      'react-native': fileURLToPath(new URL('./test/react-native-mock.ts', import.meta.url)),
    },
  },
  test: {
    // jsdom is only a test renderer host: the provider renders no host element.
    environment: 'jsdom',
    include: ['test/**/*.test.tsx', 'test/**/*.test.ts'],
  },
});
