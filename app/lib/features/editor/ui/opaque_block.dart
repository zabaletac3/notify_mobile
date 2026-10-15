import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ui/tokens.dart';

/// Claves del bloque opaco propio (tabla, HTML, imagen o nota al pie que la web no entiende).
abstract final class OpaqueBlockKeys {
  static const String type = 'axonote_opaque';
  static const String source = 'source';
}

/// Crea el nodo de un bloque opaco (conserva su texto original).
Node opaqueNode(String source) => Node(
  type: OpaqueBlockKeys.type,
  attributes: {OpaqueBlockKeys.source: source},
);

/// Constructor del bloque opaco: una tarjeta de solo lectura con el texto original (§8.2.5).
class OpaqueBlockComponentBuilder extends BlockComponentBuilder {
  OpaqueBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return OpaqueBlockComponentWidget(
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
      (node) => node.children.isEmpty;
}

/// Tarjeta de solo lectura de un bloque opaco. No admite cursor ni edición.
class OpaqueBlockComponentWidget extends BlockComponentStatefulWidget {
  const OpaqueBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<OpaqueBlockComponentWidget> createState() =>
      _OpaqueBlockComponentWidgetState();
}

class _OpaqueBlockComponentWidgetState extends State<OpaqueBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  final _cardKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget build(BuildContext context) {
    final source = node.attributes[OpaqueBlockKeys.source] as String? ?? '';
    final c = Theme.of(context).extension<AxoColors>()!;

    Widget child = Container(
      key: _cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AxoSpacing.md),
      decoration: BoxDecoration(
        color: c.bgHover,
        borderRadius: BorderRadius.circular(AxoRadii.lg),
        border: Border.all(color: c.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 14, color: c.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Bloque no editable',
                style: AxoType.meta12med.copyWith(color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            source,
            style: AxoType.bodyUi.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );

    final editorState = context.read<EditorState>();
    child = Padding(
      padding: padding,
      child: BlockSelectionContainer(
        node: node,
        delegate: this,
        listenable: editorState.selectionNotifier,
        remoteSelection: editorState.remoteSelections,
        blockColor: editorState.editorStyle.selectionColor,
        cursorColor: editorState.editorStyle.cursorColor,
        selectionColor: editorState.editorStyle.selectionColor,
        supportTypes: const [BlockSelectionType.block],
        child: child,
      ),
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

  @override
  Position start() => Position(path: node.path, offset: 0);

  @override
  Position end() => Position(path: node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final rects = getRectsInSelection(Selection.invalid());
    return rects.isEmpty ? Rect.zero : rects.first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) => null;

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final cardBox = _cardKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && cardBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? cardBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            cardBox.size,
      ];
    }
    if (_renderBox != null) return [Offset.zero & _renderBox!.size];
    return const [];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);

  @override
  TextDirection textDirection() => TextDirection.ltr;
}
