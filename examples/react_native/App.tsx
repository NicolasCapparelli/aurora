import {
  AuroraFixedScope,
  AuroraProvider,
  nativeColor,
  nativeDuration,
  useAuroraController,
  useAuroraState,
  useAuroraToken,
  useAuroraTokens,
  useAuroraTexture,
} from '@aurora/react-native';
import { AuroraFoundation, AuroraSelection, AuroraTextureFoundation } from '@aurora/core';
import { useEffect, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { canvas, cardBorder, cardShadow, contract, initialSelection, texture, themes } from './src/theme';

let mounts = 0;

/** Counts how often it mounts; theme and appearance changes must never remount it. */
function MountProbe(): ReactNode {
  useEffect(() => {
    mounts += 1;
    console.log(`AURORA_SMOKE mounted mounts=${mounts}`);
  }, []);
  return null;
}

function SmokeLog(): ReactNode {
  const state = useAuroraState();
  useEffect(() => {
    console.log(
      `AURORA_SMOKE mounts=${mounts} appearance=${state.variant.appearance} variant=${state.theme.id}:${state.variant.appearance}`,
    );
  }, [state.variant, state.theme.id]);
  return null;
}

function Canvas(): ReactNode {
  const background = useAuroraToken(canvas);
  const tokens = useAuroraTokens();
  const view = useAuroraTexture();
  return (
    <View style={[styles.canvas, { backgroundColor: nativeColor(background) }]}>
      <Text style={[view.native.typography(AuroraTextureFoundation.titleMedium), { color: nativeColor(tokens.onSurface) }]}>
        Dark canvas
      </Text>
    </View>
  );
}

function Screen(): ReactNode {
  const controller = useAuroraController();
  const state = useAuroraState();
  const tokens = useAuroraTokens();
  const view = useAuroraTexture();
  const radius = view.native.borderRadius(AuroraTextureFoundation.mediumShape);
  const dark = state.theme.variants.get('dark');

  const switchTheme = (): void => {
    const next = themes.find((theme) => theme.id !== state.theme.id)!;
    controller.select(new AuroraSelection({ themeId: next.id, appearance: state.selection.appearance, textureId: 'soft' }));
  };
  const switchAppearance = (): void => {
    const appearance = state.variant.appearance === 'dark' ? 'light' : 'dark';
    controller.select(new AuroraSelection({ themeId: state.theme.id, appearance, textureId: 'soft' }));
  };

  return (
    <View style={[styles.screen, { backgroundColor: nativeColor(tokens.surface) }]}>
      <MountProbe />
      <SmokeLog />
      <Text style={[view.native.typography(AuroraTextureFoundation.headlineSmall), { color: nativeColor(tokens.onSurface) }]}>
        {state.theme.name} ({state.variant.appearance})
      </Text>
      <View
        style={[
          styles.card,
          radius,
          view.native.border(cardBorder),
          view.native.shadow(cardShadow),
          { backgroundColor: nativeColor(tokens.primaryContainer) },
        ]}
      >
        <Text style={[view.native.typography(AuroraTextureFoundation.bodyLarge), { color: nativeColor(tokens.onPrimaryContainer) }]}>
          Card with a native border, shadow and typography from the texture.
        </Text>
        <Text style={{ color: nativeColor(tokens.onPrimaryContainer) }}>
          Motion: {nativeDuration(texture.read(AuroraTextureFoundation.mediumDuration))} ms
        </Text>
      </View>
      {dark === undefined ? null : (
        <AuroraFixedScope variant={dark} texture={texture}>
          <Canvas />
        </AuroraFixedScope>
      )}
      <View style={styles.row}>
        <Pressable
          style={[styles.button, { backgroundColor: nativeColor(tokens.primary) }]}
          onPress={switchTheme}
          accessibilityLabel="Switch theme"
        >
          <Text style={{ color: nativeColor(tokens.onPrimary) }}>Switch theme</Text>
        </Pressable>
        <Pressable
          style={[styles.button, { backgroundColor: nativeColor(tokens.secondary) }]}
          onPress={switchAppearance}
          accessibilityLabel="Switch appearance"
        >
          <Text style={{ color: nativeColor(tokens.onSecondary) }}>Switch appearance</Text>
        </Pressable>
      </View>
    </View>
  );
}

export default function App(): ReactNode {
  return (
    <AuroraProvider
      contract={contract}
      themes={themes}
      textures={[texture]}
      initialSelection={initialSelection}
      fallback="preferred"
      onSystemAppearanceError={(error) => console.warn('AURORA_SMOKE appearance error', error)}
    >
      <Screen />
    </AuroraProvider>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, paddingTop: 64, gap: 16 },
  card: { padding: 16, gap: 8 },
  canvas: { padding: 24, borderRadius: 12 },
  row: { flexDirection: 'row', gap: 12 },
  button: { paddingVertical: 12, paddingHorizontal: 16, borderRadius: 20 },
});
