import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import 'code_block.dart';
import 'opaque_block.dart';
import 'todo_block.dart';

/// Tema del editor a partir de los tokens (`«Movil v2»` + `notify_web`): claro y oscuro, sin ningún
/// color ni medida fijos aquí. Los rellenos por bloque son los del tablero «Android — Editor».
abstract final class AxoEditorTheme {
  /// Estilo global: cursor, selección, tipografía del cuerpo y relleno del documento.
  static EditorStyle styleOf(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return EditorStyle(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
      cursorColor: c.accentDefault,
      cursorWidth: 2,
      dragHandleColor: c.accentDefault,
      selectionColor: c.bgSelected.withValues(alpha: 0.6),
      textSpanDecorator: mobileTextSpanDecoratorForAttribute,
      textStyleConfiguration: TextStyleConfiguration(
        text: AxoType.editorBody.copyWith(color: c.textPrimary),
        bold: const TextStyle(fontWeight: FontWeight.w700),
        italic: const TextStyle(fontStyle: FontStyle.italic),
        underline: const TextStyle(decoration: TextDecoration.underline),
        strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
        href: TextStyle(
          color: c.accentDefault,
          decoration: TextDecoration.underline,
          decorationColor: c.accentDefault,
        ),
        code: AxoType.editorBody.copyWith(
          color: c.textPrimary,
          backgroundColor: c.bgInput,
          fontFamily: 'monospace',
          fontSize: 14.4,
        ),
        lineHeight: 25 / 16,
      ),
    );
  }

  /// Componentes de bloque con el diseño de la app.
  static Map<String, BlockComponentBuilder> buildersOf(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;

    BlockComponentConfiguration cfg(EdgeInsets padding) =>
        BlockComponentConfiguration(
          padding: (_) => padding,
          textStyle: (node, {TextSpan? textSpan}) =>
              AxoType.editorBody.copyWith(color: c.textPrimary),
        );

    return <String, BlockComponentBuilder>{
      ...standardBlockComponentBuilderMap,
      ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
        // El editor deja un párrafo vacío al final: no debe aportar alto (si no, separa el pie).
        configuration: BlockComponentConfiguration(
          padding: (node) => (node.delta?.toPlainText().isEmpty ?? true)
              ? EdgeInsets.zero
              : const EdgeInsets.only(bottom: 11),
          textStyle: (node, {TextSpan? textSpan}) =>
              AxoType.editorBody.copyWith(color: c.textPrimary),
          placeholderText: (_) => 'Escribe algo…',
        ),
      ),
      HeadingBlockKeys.type: HeadingBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.only(top: 6, bottom: 9)),
        textStyleBuilder: (_) =>
            AxoType.editorHeading.copyWith(color: c.textPrimary),
      ),
      BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.only(bottom: 10)),
        iconBuilder: (context, node) => _Bullet(color: c.accentDefault),
      ),
      NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.only(bottom: 6)),
        iconBuilder: (context, node, direction) =>
            _NumberedIcon(node: node, color: c.textPrimary),
      ),
      TodoBlockKeys.type: AxoTodoListBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.only(bottom: 12)),
      ),
      QuoteBlockKeys.type: QuoteBlockComponentBuilder(
        configuration: BlockComponentConfiguration(
          padding: (_) => const EdgeInsets.only(bottom: 12),
          textStyle: (node, {TextSpan? textSpan}) => AxoType.editorBody
              .copyWith(color: c.textSecondary, fontStyle: FontStyle.italic),
        ),
        iconBuilder: (context, node) => Container(
          width: AxoSizes.editorQuoteBorder,
          margin: const EdgeInsets.only(right: 13),
          decoration: BoxDecoration(
            color: c.accentDefault,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      DividerBlockKeys.type: DividerBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.symmetric(vertical: 12)),
      ),
      CodeBlockKeys.type: CodeBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.symmetric(vertical: 6)),
      ),
      OpaqueBlockKeys.type: OpaqueBlockComponentBuilder(
        configuration: cfg(const EdgeInsets.symmetric(vertical: 6)),
      ),
    };
  }
}

/// Punto de viñeta del diseño: 6×6, acento, con el canal del texto a 18 de ancho.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, right: 12),
        child: Container(
          width: AxoSizes.editorBulletDot,
          height: AxoSizes.editorBulletDot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Número de la lista numerada, alineado como el diseño.
class _NumberedIcon extends StatelessWidget {
  const _NumberedIcon({required this.node, required this.color});

  final Node node;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final index =
        node.attributes[NumberedListBlockKeys.number] ??
        (node.previous?.attributes[NumberedListBlockKeys.number] as int? ?? 0) +
            1;
    return SizedBox(
      width: 24,
      child: Text('$index.', style: AxoType.editorBody.copyWith(color: color)),
    );
  }
}
