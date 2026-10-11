import 'package:connectivity_plus/connectivity_plus.dart';

/// Envuelve `connectivity_plus` (§9) en una interfaz mínima: así `SyncTriggers` no depende del
/// canal de plataforma del plugin y se puede probar con una versión falsa (sin el binario de
/// pruebas de plugins de Flutter).
abstract interface class ConnectivityProbe {
  /// Avisa de cada cambio de conectividad.
  Stream<List<ConnectivityResult>> get onChanged;

  /// Conectividad actual.
  Future<List<ConnectivityResult>> check();
}

/// Implementación real sobre `package:connectivity_plus`.
class PluginConnectivityProbe implements ConnectivityProbe {
  PluginConnectivityProbe([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<List<ConnectivityResult>> get onChanged =>
      _connectivity.onConnectivityChanged;

  @override
  Future<List<ConnectivityResult>> check() =>
      _connectivity.checkConnectivity();
}

/// Hay alguna conexión (lo que sea, para los disparadores que no exigen Wi-Fi).
bool hasAnyConnection(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Conexión de Wi-Fi (o Ethernet, que tampoco gasta datos móviles), para `wifiOnly`.
bool isWifiOrEthernet(List<ConnectivityResult> results) =>
    results.contains(ConnectivityResult.wifi) ||
    results.contains(ConnectivityResult.ethernet);
