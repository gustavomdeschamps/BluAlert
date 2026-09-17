import 'queue_store.dart';

/// No navegador a fila fica em memória.
///
/// O Android é o destino real do piloto e usa SQLite. Manter uma fila
/// persistente no navegador exigiria empacotar `sqlite3.wasm` e o worker do
/// drift, além de guardar os bytes das evidências em IndexedDB — trabalho que
/// não se justifica enquanto a web serve só para demonstração.
///
/// A consequência é declarada em `QueueStore.isDurable`, e a interface avisa a
/// pessoa de que fechar a aba perde o que ainda não foi confirmado. Preferimos
/// dizer isso do que fingir uma persistência que não existe.
Future<QueueStore> openQueueStore() async => MemoryQueueStore();
