package com.axonote.app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * `FlutterFragmentActivity`, no `FlutterActivity`: `axonote_platform` usa `BiometricPrompt`
 * (plan §5.2), que exige una `FragmentActivity` (ver `docs/decisions.md`, Fase 5).
 */
class MainActivity : FlutterFragmentActivity()
