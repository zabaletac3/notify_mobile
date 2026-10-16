import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión y build de la app, leídos del paquete (equivalente a `version.ts` de la web). Si el
/// plugin no responde (p. ej. en pruebas), se cae a los valores del `pubspec`.
class AppInfo {
  const AppInfo({required this.version, required this.build});

  final String version;
  final String build;
}

final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, build: info.buildNumber);
  } catch (_) {
    return const AppInfo(version: '1.0.0', build: '1');
  }
});
