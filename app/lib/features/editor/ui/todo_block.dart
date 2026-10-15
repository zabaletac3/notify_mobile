import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/tokens.dart';

/// Claves del bloque de tareas (las mismas del editor vendorizado).
abstract final class TodoBlockKeys {
  static const String type = 'todo_list';
  static const String checked = 'checked';
}

/// Constructor del bloque de tareas con el diseño del tablero «Android — Editor»: casilla redonda y,
/// cuando está marcada, el texto con resguardo `bg/selected` r5 y color `text/secondary`.
class AxoTodoListBlockComponentBuilder extends BlockComponentBuilder {
  AxoTodoListBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return AxoTodoListBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
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

class AxoTodoListBlockComponentWidget extends BlockComponentStatefulWidget {
  const AxoTodoListBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<AxoTodoListBlockComponentWidget> createState() =>
      _AxoTodoListBlockComponentWidgetState();
}

class _AxoTodoListBlockComponentWidgetState
    extends State<AxoTodoListBlockComponentWidget>
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
    debugLabel: TodoBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool get checked =>
      (node.attributes[TodoBlockKeys.checked] as bool?) ?? false;

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget text = AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: node,
      editorState: editorState,
      textAlign: alignment?.toTextAlign ?? textAlign,
      placeholderText: placeholderText,
      textDirection: textDirection,
      textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
        textStyleWithTextSpan().copyWith(
          color: checked ? c.textSecondary : c.textPrimary,
        ),
      ),
      placeholderTextSpanDecorator: (textSpan) => textSpan.updateTextStyle(
        placeholderTextStyleWithTextSpan(textSpan: textSpan),
      ),
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      cursorWidth: editorState.editorStyle.cursorWidth,
    );

    if (checked) {
      // El tablero resguarda el texto marcado en un «Highlight» `bg/selected` r5.
      text = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.bgSelected,
          borderRadius: BorderRadius.circular(5),
        ),
        child: text,
      );
    }

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          _AxoTodoCheckbox(checked: checked, onTap: checkOrUncheck, colors: c),
          Flexible(
            child: Align(alignment: Alignment.centerLeft, child: text),
          ),
        ],
      ),
    );

    child = Container(
      decoration: withBackgroundColor ? decoration : null,
      key: blockComponentKey,
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

  void checkOrUncheck() {
    final transaction = editorState.transaction
      ..updateNode(node, {TodoBlockKeys.checked: !checked});
    editorState.apply(transaction, withUpdateSelection: false);
  }
}

/// Casilla redonda del diseño (22, radio 11): sin marcar, borde `text/tertiary` 1,5; marcada,
/// relleno `accent` con tilde blanca.
class _AxoTodoCheckbox extends StatelessWidget {
  const _AxoTodoCheckbox({
    required this.checked,
    required this.onTap,
    required this.colors,
  });

  final bool checked;
  final VoidCallback onTap;
  final AxoColors colors;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Container(
              width: AxoSizes.editorTask,
              height: AxoSizes.editorTask,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? colors.accentDefault : null,
                border: checked
                    ? null
                    : Border.all(color: colors.textTertiary, width: 1.5),
              ),
              child: checked
                  ? Center(
                      child: AppIcon('check', size: 13, color: colors.accentOn),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
