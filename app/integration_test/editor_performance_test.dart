// Prueba de apertura y escritura de una nota grande (plan §10, «Hecho cuando» de la Fase 10:
// «una nota de 100 KB abre en menos de 300 ms y se escribe sin retraso perceptible»).
//
// Mide dos cosas con el códec y el adaptador reales sobre el ZTE en modo profile:
//   · apertura = analizar el Markdown + montar el árbol del editor;
//   · escritura = recoger los bloques del editor y volver a serializar.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/editor_performance_test.dart -d LZ0V50COPBC002769 --profile
//
import 'package:axonote_app/features/editor/state/editor_adapter.dart';
import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Genera una nota de al menos [targetBytes] bytes combinando todos los bloques soportados.
String bigNote(int targetBytes) {
  const chunk = '''
# Título de sección

Un párrafo con **negrita**, *cursiva*, ~~tachado~~, ++subrayado++, `código` y un [enlace](https://apunte.app "título") que se repite para llenar la nota.

## Subtítulo

- viñeta uno
- viñeta dos
  - anidada
- viñeta tres

1. numerada uno
2. numerada dos
3. numerada tres

- [ ] tarea pendiente
- [x] tarea hecha
  - [ ] subtarea

> Una cita con **negrita** y una idea que ocupa unas cuantas palabras.

```js
const saludo = 'hola';
console.log(saludo);
```

---

Línea con salto duro  
siguiente línea del mismo párrafo.
''';
  final buffer = StringBuffer();
  while (buffer.length < targetBytes) {
    buffer.write(chunk);
  }
  return buffer.toString();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nota de 100 KB: abre y se escribe sin retraso', (tester) async {
    final content = bigNote(100 * 1024);
    final sizeKb = (content.length / 1024).toStringAsFixed(1);

    // Apertura: analizar el Markdown y montar el árbol del editor.
    final open = Stopwatch()..start();
    final blocks = MarkdownParser.parse(content).content;
    final document = EditorAdapter.toDocument(blocks);
    open.stop();

    // Escritura: recoger los bloques y serializar de nuevo.
    final write = Stopwatch()..start();
    final back = EditorAdapter.toBlocks(document);
    final markdown = MarkdownSerializer.serialize(MdNode.doc(back));
    write.stop();

    debugPrint(
      'Fase 10 · nota ${sizeKb}KB (${blocks.length} bloques): '
      'apertura=${open.elapsedMilliseconds}ms escritura=${write.elapsedMilliseconds}ms',
    );

    expect(markdown, isNotEmpty);
    expect(
      open.elapsedMilliseconds,
      lessThan(300),
      reason: '§10 (d): una nota de 100 KB abre en menos de 300 ms',
    );
    // La escritura va tras una espera de 400 ms (A10): el trabajo real debe ser pequeño y no
    // añadir retraso perceptible.
    expect(
      write.elapsedMilliseconds,
      lessThan(300),
      reason: '§10 (d): la escritura no añade retraso perceptible',
    );
  });
}
