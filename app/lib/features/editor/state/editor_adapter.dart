/// Adaptador entre el modelo de bloques de `axonote_markdown` y los nodos de `appflowy_editor`
/// (§8.2.6). El códec no importa AppFlowy; esta es la única costura. Vive en `state/` para que la
/// interfaz no hable directamente con el editor.
library;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:axonote_markdown/axonote_markdown.dart';

/// Tipos de nodo de AppFlowy que usa el adaptador (los estándar; `axonoteOpaque` es propio).
abstract final class EditorNodeType {
  static const page = 'page';
  static const paragraph = 'paragraph';
  static const heading = 'heading';
  static const bulletedList = 'bulleted_list';
  static const numberedList = 'numbered_list';
  static const todoList = 'todo_list';
  static const quote = 'quote';
  static const code = 'code';
  static const divider = 'divider';
  static const text = 'text';

  /// Bloque opaco propio: se muestra como tarjeta de solo lectura (§8.2.5).
  static const opaque = 'axonote_opaque';
}

/// Claves de atributo de los nodos de AppFlowy.
abstract final class EditorAttr {
  static const delta = 'delta';
  static const level = 'level';
  static const checked = 'checked';
  static const language = 'language';
  static const source = 'source';

  /// Marca propia para distinguir un salto duro (AppFlowy usa `\n` para el salto suave).
  static const hardBreak = 'hardBreak';

  /// Título del enlace (AppFlowy solo guarda `href`).
  static const hrefTitle = 'hrefTitle';
}

/// Conversión en los dos sentidos entre bloques de AxoNote y el documento de AppFlowy.
abstract final class EditorAdapter {
  /// Bloques → documento de AppFlowy.
  static Document toDocument(List<MdNode> blocks) {
    final children = <Node>[];
    for (final block in blocks) {
      children.addAll(_nodesFromBlock(block));
    }
    // El editor añade un párrafo vacío al final (para poder escribir detrás); si ya lo hay, no se
    // duplica.
    if (children.isNotEmpty &&
        children.last.type == EditorNodeType.paragraph &&
        (children.last.delta?.toPlainText().isEmpty ?? true)) {
      children.removeLast();
    }
    return Document(
      root: Node(type: EditorNodeType.page, children: children),
    );
  }

  /// Documento de AppFlowy → bloques.
  static List<MdNode> toBlocks(Document document) {
    final blocks = <MdNode>[];
    final children = document.root.children;
    var i = 0;
    while (i < children.length) {
      final node = children[i];
      final kind = _listKind(node.type);
      if (kind != null) {
        // AppFlowy guarda cada elemento de lista como un nodo hermano: se agrupan los consecutivos
        // del mismo tipo en un solo bloque (§8.2.6).
        final items = <MdNode>[];
        while (i < children.length && children[i].type == node.type) {
          items.add(_listItem(children[i]));
          i++;
        }
        blocks.add(_listBlockOf(kind, items));
        continue;
      }
      blocks.addAll(_blocksFromNode(node));
      i++;
    }
    return blocks;
  }

  static String? _listKind(String type) => switch (type) {
    EditorNodeType.bulletedList => MdNodeType.bulletList,
    EditorNodeType.numberedList => MdNodeType.orderedList,
    EditorNodeType.todoList => MdNodeType.taskList,
    _ => null,
  };

  static MdNode _listBlockOf(String kind, List<MdNode> items) => switch (kind) {
    MdNodeType.bulletList => MdNode.bulletList(items),
    MdNodeType.orderedList => MdNode.orderedList(1, items),
    _ => MdNode.taskList(items),
  };

  // ── Bloques → nodos ──

  static List<Node> _nodesFromBlock(MdNode block) {
    switch (block.type) {
      case MdNodeType.paragraph:
        return [
          Node(
            type: EditorNodeType.paragraph,
            attributes: {
              EditorAttr.delta: _deltaFromInline(block.content).toJson(),
            },
          ),
        ];
      case MdNodeType.heading:
        final level = (block.attrs['level'] as num?)?.toInt() ?? 1;
        return [
          Node(
            type: EditorNodeType.heading,
            attributes: {
              EditorAttr.delta: _deltaFromInline(block.content).toJson(),
              EditorAttr.level: level.clamp(1, 6),
            },
          ),
        ];
      case MdNodeType.bulletList:
        return [
          for (final item in block.content)
            _listNode(EditorNodeType.bulletedList, item),
        ];
      case MdNodeType.orderedList:
        return [
          for (final item in block.content)
            _listNode(EditorNodeType.numberedList, item),
        ];
      case MdNodeType.taskList:
        return [
          for (final item in block.content)
            _listNode(
              EditorNodeType.todoList,
              item,
              extra: {EditorAttr.checked: item.attrs['checked'] == true},
            ),
        ];
      case MdNodeType.blockquote:
        return [_quoteNode(block.content)];
      case MdNodeType.codeBlock:
        final language = block.attrs['language'] as String?;
        final code = block.content.isEmpty
            ? ''
            : block.content.first.text ?? '';
        final attributes = <String, Object?>{
          EditorAttr.delta: _deltaFromInline([MdNode.textNode(code)]).toJson(),
        };
        if (language != null) attributes[EditorAttr.language] = language;
        return [Node(type: EditorNodeType.code, attributes: attributes)];
      case MdNodeType.horizontalRule:
        return [Node(type: EditorNodeType.divider)];
      case MdNodeType.opaque:
        return [
          Node(
            type: EditorNodeType.opaque,
            attributes: {
              EditorAttr.source: (block.attrs['source'] as String?) ?? '',
            },
          ),
        ];
      default:
        return const [];
    }
  }

  /// Un elemento de lista: el texto va en el `delta` del nodo y los bloques hijos (listas anidadas,
  /// párrafos extra, código, cita) cuelgan como nodos hijos.
  static Node _listNode(
    String type,
    MdNode item, {
    Map<String, Object?> extra = const {},
  }) {
    final content = item.content;
    final first = content.isEmpty
        ? MdNode.paragraph()
        : (content.first.type == MdNodeType.paragraph
              ? content.first
              : MdNode.paragraph([MdNode.textNode(content.first.plainText)]));
    final children = <Node>[];
    final rest = content.length > 1 ? content.sublist(1) : const <MdNode>[];
    for (final child in rest) {
      children.addAll(_nodesFromBlock(child));
    }
    return Node(
      type: type,
      attributes: {
        EditorAttr.delta: _deltaFromInline(first.content).toJson(),
        ...extra,
      },
      children: children,
    );
  }

  static Node _quoteNode(List<MdNode> children) {
    final first = children.isEmpty ? MdNode.paragraph() : children.first;
    final rest = children.length > 1 ? children.sublist(1) : const <MdNode>[];
    final childNodes = <Node>[];
    for (final child in rest) {
      childNodes.addAll(_nodesFromBlock(child));
    }
    return Node(
      type: EditorNodeType.quote,
      attributes: {
        EditorAttr.delta: _deltaFromInline(
          first.type == MdNodeType.paragraph
              ? first.content
              : [MdNode.textNode(first.plainText)],
        ).toJson(),
      },
      children: childNodes,
    );
  }

  // ── Nodos → bloques ──

  static List<MdNode> _blocksFromNode(Node node) {
    switch (node.type) {
      case EditorNodeType.paragraph:
        return [MdNode.paragraph(_inlineFromDelta(node.delta))];
      case EditorNodeType.heading:
        final level = (node.attributes[EditorAttr.level] as num?)?.toInt() ?? 1;
        return [
          MdNode.heading(level.clamp(1, 6), _inlineFromDelta(node.delta)),
        ];
      case EditorNodeType.bulletedList:
        return [_listBlock(MdNodeType.bulletList, node)];
      case EditorNodeType.numberedList:
        return [_listBlock(MdNodeType.orderedList, node)];
      case EditorNodeType.todoList:
        return [_listBlock(MdNodeType.taskList, node)];
      case EditorNodeType.quote:
        return [_quoteBlock(node)];
      case EditorNodeType.code:
        final delta = node.delta;
        final code = delta?.toPlainText() ?? '';
        return [
          MdNode.codeBlock(
            node.attributes[EditorAttr.language] as String?,
            code,
          ),
        ];
      case EditorNodeType.divider:
        return [MdNode.horizontalRule];
      case EditorNodeType.opaque:
        return [
          MdNode.opaque(node.attributes[EditorAttr.source] as String? ?? ''),
        ];
      default:
        return const [];
    }
  }

  static MdNode _listBlock(String kind, Node node) {
    final item = _listItem(node);
    switch (kind) {
      case MdNodeType.bulletList:
        return MdNode.bulletList([item]);
      case MdNodeType.orderedList:
        return MdNode.orderedList(1, [item]);
      default:
        return MdNode.taskList([item]);
    }
  }

  static MdNode _listItem(Node node) {
    final content = <MdNode>[MdNode.paragraph(_inlineFromDelta(node.delta))];
    for (final child in node.children) {
      content.addAll(_blocksFromNode(child));
    }
    final isTask = node.type == EditorNodeType.todoList;
    return isTask
        ? MdNode.taskItem(node.attributes[EditorAttr.checked] == true, content)
        : MdNode.listItem(content);
  }

  static MdNode _quoteBlock(Node node) {
    final children = <MdNode>[MdNode.paragraph(_inlineFromDelta(node.delta))];
    for (final child in node.children) {
      children.addAll(_blocksFromNode(child));
    }
    return MdNode.blockquote(children);
  }

  // ── Delta ↔ texto con marcas ──

  static Delta _deltaFromInline(List<MdNode> inline) {
    final operations = <TextOperation>[];
    for (final node in inline) {
      if (node.type == MdNodeType.hardBreak) {
        operations.add(
          TextInsert('\n', attributes: {EditorAttr.hardBreak: true}),
        );
      } else if (node.type == MdNodeType.text) {
        final attributes = _attributesOf(node.marks);
        operations.add(TextInsert(node.text ?? '', attributes: attributes));
      }
    }
    if (operations.isEmpty) operations.add(TextInsert(''));
    return Delta(operations: operations);
  }

  static Map<String, dynamic>? _attributesOf(List<MdMark> marks) {
    final attributes = <String, dynamic>{};
    for (final mark in marks) {
      switch (mark.type) {
        case MdMarkType.bold:
          attributes['bold'] = true;
        case MdMarkType.italic:
          attributes['italic'] = true;
        case MdMarkType.strike:
          attributes['strikethrough'] = true;
        case MdMarkType.underline:
          attributes['underline'] = true;
        case MdMarkType.code:
          attributes['code'] = true;
        case MdMarkType.link:
          attributes['href'] = mark.href;
          if (mark.title != null) attributes[EditorAttr.hrefTitle] = mark.title;
      }
    }
    return attributes.isEmpty ? null : attributes;
  }

  static List<MdNode> _inlineFromDelta(Delta? delta) {
    final out = <MdNode>[];
    if (delta == null) return out;
    for (final operation in delta) {
      if (operation is! TextInsert) continue;
      final text = operation.text;
      final attributes = operation.attributes ?? const <String, dynamic>{};
      final isHardBreak = attributes[EditorAttr.hardBreak] == true;
      if (!isHardBreak) {
        out.add(MdNode.textNode(text, _marksOf(attributes)));
        continue;
      }
      // Un salto duro puede venir mezclado con texto en el mismo `insert`.
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) out.add(MdNode.hardBreak);
        if (parts[i].isNotEmpty) {
          out.add(MdNode.textNode(parts[i], _marksOf(attributes)));
        }
      }
    }
    return out;
  }

  static List<MdMark> _marksOf(Map<String, dynamic> attributes) {
    final marks = <MdMark>[];
    if (attributes['bold'] == true) marks.add(MdMark.bold);
    if (attributes['italic'] == true) marks.add(MdMark.italic);
    if (attributes['strikethrough'] == true) marks.add(MdMark.strike);
    if (attributes['underline'] == true) marks.add(MdMark.underline);
    if (attributes['code'] == true) marks.add(MdMark.code);
    final href = attributes['href'];
    if (href is String && href.isNotEmpty) {
      marks.add(
        MdMark(
          MdMarkType.link,
          href: href,
          title: attributes[EditorAttr.hrefTitle] as String?,
        ),
      );
    }
    return marks;
  }
}
