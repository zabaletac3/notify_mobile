/// Motor de sincronización de AxoNote: cola y ciclo sobre interfaces (plan §7, fase 7).
///
/// Dart puro, sin `flutter`, `drift` ni `dio`: solo conoce `axonote_domain` y las tres interfaces
/// que implementa `app/lib/data` (`SyncTransport` sobre `axonote_api`, `ItemCodec` sobre
/// `LocalCodec`) y el propio `SyncStore` del dominio (ya implementado por `LocalSyncStore` en la
/// fase 6).
library;

export 'src/item_codec.dart';
export 'src/sync_clock.dart';
export 'src/sync_engine.dart';
export 'src/sync_transport.dart';
