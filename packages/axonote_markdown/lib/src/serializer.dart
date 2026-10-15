/// Serializador Markdown: reproduce byte a byte lo que emite el editor de la web (TipTap 3).
///
/// Las reglas (marcadores de lista, sangría, líneas en blanco, escapes, entidades, anidación de
/// marcas) se fijan contra los vectores `contract/vectors/markdown.json`; ver §8.2.3 del plan.
library;

import 'ast.dart';

/// Convierte un árbol de bloques al Markdown canónico de AxoNote.
abstract final class MarkdownSerializer {
  /// Serializa un documento completo. Un documento vacío (o solo con espacios y `&nbsp;`) da `''`.
  static String serialize(MdNode doc) {
    final rendered = _renderBlockChildren(doc.content);
    return _isEmptyOutput(rendered) ? '' : rendered;
  }

  static bool _isEmptyOutput(String markdown) {
    if (markdown.trim().isEmpty) return true;
    return markdown
        .replaceAll('&nbsp;', '')
        .replaceAll('\u00A0', '')
        .trim()
        .isEmpty;
  }

  /// Serializa un único bloque (la conservación por bloque lo usa para los bloques cambiados).
  static String renderBlock(MdNode node) => _renderBlock(node);

  static String _renderBlockChildren(List<MdNode> blocks) {
    final buffer = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) buffer.write('\n\n');
      buffer.write(
        _renderBlock(blocks[i], previous: i > 0 ? blocks[i - 1] : null),
      );
    }
    return buffer.toString();
  }

  static String _renderBlock(MdNode node, {MdNode? previous}) {
    switch (node.type) {
      case MdNodeType.paragraph:
        if (node.isEmptyParagraph) {
          // Un párrafo vacío aislado se emite como línea en blanco; dos seguidos, con `&nbsp;`.
          return (previous != null && previous.isEmptyParagraph)
              ? '&nbsp;'
              : '';
        }
        return _renderInline(node.content);
      case MdNodeType.heading:
        final level = (node.attrs['level'] as num?)?.toInt() ?? 1;
        return '${'#' * level} ${_renderInline(node.content)}';
      case MdNodeType.bulletList:
        return _renderListItems(node.content, (i) => '- ', false);
      case MdNodeType.taskList:
        return _renderListItems(
          node.content,
          (i) =>
              (node.content[i].attrs['checked'] == true) ? '- [x] ' : '- [ ] ',
          false,
        );
      case MdNodeType.orderedList:
        final start = (node.attrs['start'] as num?)?.toInt() ?? 1;
        return _renderListItems(node.content, (i) => '${start + i}. ', true);
      case MdNodeType.blockquote:
        return _renderBlockquote(node.content);
      case MdNodeType.codeBlock:
        final language = node.attrs['language'] as String?;
        final code = node.content.isEmpty ? '' : node.content.first.text ?? '';
        return '```${language ?? ''}\n$code\n```';
      case MdNodeType.horizontalRule:
        return '---';
      case MdNodeType.opaque:
        return (node.attrs['source'] as String?) ?? '';
      default:
        return '';
    }
  }

  static String _renderListItems(
    List<MdNode> items,
    String Function(int index) prefixOf,
    bool alignNestedToPrefix,
  ) {
    final buffer = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(_renderListItem(items[i], prefixOf(i), alignNestedToPrefix));
    }
    return buffer.toString();
  }

  static String _renderListItem(
    MdNode item,
    String prefix,
    bool alignNestedToPrefix,
  ) {
    final content = item.content;
    if (content.isEmpty) return prefix;

    final indentWidth = alignNestedToPrefix && prefix.length > 2
        ? prefix.length
        : 2;
    final indent = ' ' * indentWidth;

    final buffer = StringBuffer(prefix);
    buffer.write(_renderBlock(content.first));

    for (var i = 1; i < content.length; i++) {
      final child = content[i];
      final childText = _renderBlock(child);
      final indented = childText
          .split('\n')
          .map((line) => '$indent$line')
          .join('\n');
      // Los párrafos se separan con línea en blanco; el resto pegado.
      buffer.write(child.type == MdNodeType.paragraph ? '\n\n' : '\n');
      buffer.write(indented);
    }
    return buffer.toString();
  }

  static String _renderBlockquote(List<MdNode> children) {
    final inner = _renderBlockChildren(children);
    return inner
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
  }

  // ── Marcas en línea ──

  /// Renderiza el contenido en línea aplicando las marcas con su anidación medida.
  static String _renderInline(List<MdNode> nodes) {
    final buffer = StringBuffer();
    var active = const <MdMark>[];

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.type == MdNodeType.hardBreak) {
        // Un salto duro cierra las marcas abiertas y no las reabre (igual que la web).
        buffer.write(_closeAll(active));
        active = const [];
        buffer.write('  \n');
        continue;
      }
      if (node.type != MdNodeType.text) continue;

      final target = _sortedMarks(node.marks);
      final next = i + 1 < nodes.length && nodes[i + 1].type == MdNodeType.text
          ? _sortedMarks(nodes[i + 1].marks)
          : const <MdMark>[];

      final closesHere = target
          .where((m) => !next.contains(m))
          .toList()
          .reversed
          .toList();
      final opensHere = target.where((m) => !active.contains(m)).toList();

      var core = node.text ?? '';
      var leading = '';
      var trailing = '';
      if (opensHere.isNotEmpty) {
        final match = RegExp(r'^\s+').firstMatch(core);
        if (match != null) {
          leading = match.group(0)!;
          core = core.substring(leading.length);
        }
      }
      if (closesHere.isNotEmpty) {
        final match = RegExp(r'\s+$').firstMatch(core);
        if (match != null) {
          trailing = match.group(0)!;
          core = core.substring(0, core.length - trailing.length);
        }
      }

      final hasCode = target.any((m) => m.type == MdMarkType.code);
      final codeFence = hasCode ? _codeFenceLength(core) : null;
      buffer.write(leading);
      buffer.write(opensHere.map((m) => _opening(m, codeFence)).join());
      buffer.write(hasCode ? core : _encodeText(core));
      buffer.write(closesHere.map((m) => _closing(m, codeFence)).join());
      buffer.write(trailing);

      active = target.where(next.contains).toList();
    }
    buffer.write(_closeAll(active));
    return buffer.toString();
  }

  static List<MdMark> _sortedMarks(List<MdMark> marks) =>
      [...marks]..sort(MdMark.compareByRank);

  static String _closeAll(List<MdMark> active) =>
      active.reversed.map((m) => _closing(m, null)).join();

  static String _opening(MdMark mark, int? codeFence) => switch (mark.type) {
    MdMarkType.bold => '**',
    MdMarkType.italic => '*',
    MdMarkType.strike => '~~',
    MdMarkType.underline => '++',
    MdMarkType.link => '[',
    MdMarkType.code => '`' * (codeFence ?? 1),
    _ => '',
  };

  static String _closing(MdMark mark, int? codeFence) => switch (mark.type) {
    MdMarkType.bold => '**',
    MdMarkType.italic => '*',
    MdMarkType.strike => '~~',
    MdMarkType.underline => '++',
    MdMarkType.link => _linkClose(mark),
    MdMarkType.code => '`' * (codeFence ?? 1),
    _ => '',
  };

  static String _linkClose(MdMark mark) {
    final href = mark.href ?? '';
    return mark.title == null ? ']($href)' : ']($href "${mark.title}")';
  }

  /// Longitud de la valla de código: una comilla invertida más que la racha más larga del texto.
  static int _codeFenceLength(String content) {
    var longest = 0;
    for (final run in RegExp('`+').allMatches(content)) {
      if (run.group(0)!.length > longest) longest = run.group(0)!.length;
    }
    return longest + 1;
  }

  /// Texto literal del Markdown: entidades HTML y escapes de la sintaxis en línea.
  static String _encodeText(String text) {
    final encoded = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return encoded.replaceAllMapped(
      RegExp(r'[\\`*_\[\]~]'),
      (m) => '\\${m.group(0)}',
    );
  }
}
