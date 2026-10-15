import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// Claves del bloque de código propio. El editor vendorizado no trae componente para `code`, así que
/// lo aporta la app (el diseño móvil tampoco lo dibuja; se sigue `prose.css` de `notify_web`).
abstract final class CodeBlockKeys {
  static const String type = 'code';
  static const String delta = blockComponentDelta;
  static const String language = 'language';
}

/// Constructor del bloque de código (monoespaciado, con el relleno del editor).
class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration, this.textStyleBuilder});

  final TextStyle Function()? textStyleBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CodeBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      textStyleBuilder: textStyleBuilder,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class CodeBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.textStyleBuilder,
  });

  final TextStyle Function()? textStyleBuilder;

  @override
  State<CodeBlockComponentWidget> createState() =>
      _CodeBlockComponentWidgetState();
}

class _CodeBlockComponentWidgetState extends State<CodeBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: CodeBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final language = node.attributes[CodeBlockKeys.language] as String?;

    Widget inner = AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: node,
      editorState: editorState,
      textAlign: alignment?.toTextAlign ?? textAlign,
      placeholderText: placeholderText,
      textDirection: textDirection,
      textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
        widget.textStyleBuilder?.call() ??
            AxoType.editorBody.copyWith(
              color: c.textPrimary,
              fontFamily: 'monospace',
              height: 1.45,
            ),
      ),
      placeholderTextSpanDecorator: (textSpan) => textSpan.updateTextStyle(
        placeholderTextStyleWithTextSpan(textSpan: textSpan)
            .copyWith(color: c.textTertiary, fontFamily: 'monospace'),
      ),
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      cursorWidth: editorState.editorStyle.cursorWidth,
    );

    Widget child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgInput,
        borderRadius: BorderRadius.circular(AxoRadii.inlineCode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (language != null && language.isNotEmpty) ...[
            Text(
              language,
              style: AxoType.meta11.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: 6),
          ],
          inner,
        ],
      ),
    );

    child = Container(
      key: blockComponentKey,
      decoration: withBackgroundColor ? decoration : null,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}
