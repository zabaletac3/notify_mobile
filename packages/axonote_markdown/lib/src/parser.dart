/// Analizador Markdown: convierte el texto guardado en el árbol de bloques de AxoNote.
///
/// Reproduce la lectura del editor de la web (TipTap 3 con `marked`): líneas en blanco como párrafos
/// vacíos, entidades HTML, escapes, normalización de listas y saltos duros (§8.1 y §8.2.2 del plan).
/// Dart puro.
library;

import 'ast.dart';

/// Resultado del análisis: el árbol y la lista de bloques de primer nivel con su texto original.
class ParsedMarkdown {
  ParsedMarkdown(this.doc, this.blocks);

  final MdNode doc;
  final List<MarkdownBlock> blocks;
}

/// Un bloque de primer nivel con su texto original exacto y su separador.
///
/// `source` es la rebanada literal de la nota; `''` para los párrafos vacíos que solo aportan una
/// línea en blanco (no ocupan bytes). `separatorBefore` es el texto que lo precede (el separador
/// original respecto del bloque anterior). La conservación por bloque (§8.2.4) usa ambos.
class MarkdownBlock {
  MarkdownBlock({
    required this.node,
    required this.source,
    required this.separatorBefore,
  });

  MdNode node;
  final String source;
  final String separatorBefore;

  /// Huella estructural del bloque en el momento del análisis (la fija [MarkdownDocument]).
  String? fingerprint;
}

class _BlockResult {
  _BlockResult(this.node, this.next);
  final MdNode node;
  final int next;
}

class _Entry {
  _Entry(this.node, this.startLine, this.endLine, {this.virtual = false});
  final MdNode node;
  final int startLine;
  int endLine;
  final bool virtual;
}

/// Analizador del Markdown de AxoNote.
abstract final class MarkdownParser {
  static final RegExp _headingRe = RegExp(r'^(#{1,6}) (.*)$');
  static final RegExp _hrRe = RegExp(r'^(-{3,}|\*{3,}|_{3,}) *$');
  static final RegExp _fenceRe = RegExp(r'^(`{3,})(.*)$');
  static final RegExp _fenceCloseRe = RegExp(r'^`{3,}\s*$');
  static final RegExp _quoteRe = RegExp(r'^>');
  static final RegExp _listRe = RegExp(r'^(\s*)([-+*]|\d+[.)])( +)(.*)$');
  static final RegExp _taskRe = RegExp(r'^\[([ xX])\]( ?)(.*)$');
  static final RegExp _imageRe = RegExp(r'!\[[^\]]*\]\(');
  static final RegExp _footnoteRe = RegExp(r'^\[\^[^\]]+\]:');
  static final RegExp _tableSepRe = RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$');
  static final RegExp _htmlBlockRe = RegExp(
    r'^\s*<(address|article|aside|base|blockquote|body|caption|center|col|colgroup|'
    r'dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|'
    r'h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|'
    r'optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|'
    r'track|ul)(\s|>|/)',
    caseSensitive: false,
  );

  /// Detecta un bloque que el editor de la web no entiende (tabla, HTML de bloque o nota al pie).
  static _Opaque? _matchOpaque(List<String> lines, int i) {
    final line = lines[i];
    if (_footnoteRe.hasMatch(line)) {
      var j = i;
      while (j < lines.length && lines[j].trim().isNotEmpty) {
        j++;
      }
      return _Opaque(lines.sublist(i, j).join('\n'), j);
    }
    if (_htmlBlockRe.hasMatch(line)) {
      var j = i;
      while (j < lines.length && lines[j].trim().isNotEmpty) {
        j++;
      }
      return _Opaque(lines.sublist(i, j).join('\n'), j);
    }
    if (line.contains('|') &&
        i + 1 < lines.length &&
        _tableSepRe.hasMatch(lines[i + 1])) {
      var j = i;
      while (j < lines.length && lines[j].contains('|')) {
        j++;
      }
      return _Opaque(lines.sublist(i, j).join('\n'), j);
    }
    return null;
  }

  /// Analiza el texto y devuelve solo el árbol (para serializar de vuelta).
  static MdNode parse(String source) => parseDetailed(source).doc;

  /// Analiza el texto y devuelve el árbol más los bloques de primer nivel con su texto original.
  static ParsedMarkdown parseDetailed(String rawSource) {
    final source = rawSource.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = source.split('\n');
    final lineStart = _lineStarts(source);
    final entries = _topLevelEntries(lines);

    final blocks = <MarkdownBlock>[];
    final docBlocks = <MdNode>[];

    // Recorrido con cursor: cada entrada aporta su separador (el texto entre ella y la anterior) y,
    // si es real, su rebanada de origen exacta. Los vacíos virtuales consumen un `\n\n` del hueco.
    var cursor = 0;
    for (final e in entries) {
      final String source0;
      final String separator;
      if (e.virtual) {
        final end = (cursor + 2).clamp(0, source.length);
        separator = source.substring(cursor, end < cursor ? cursor : end);
        cursor = end < cursor ? cursor : end;
        source0 = '';
      } else {
        final start = lineStart[e.startLine];
        final end = e.endLine >= lines.length
            ? source.length
            : lineStart[e.endLine] - 1;
        final safeEnd = end < start ? start : end;
        separator = source.substring(cursor.clamp(0, start), start);
        source0 = source.substring(start, safeEnd);
        cursor = safeEnd;
      }
      docBlocks.add(e.node);
      blocks.add(
        MarkdownBlock(
          node: e.node,
          source: source0,
          separatorBefore: separator,
        ),
      );
    }

    return ParsedMarkdown(MdNode.doc(docBlocks), blocks);
  }

  static List<int> _lineStarts(String source) {
    final starts = <int>[0];
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0A) starts.add(i + 1);
    }
    return starts;
  }

  /// Bloques de primer nivel, incluyendo los párrafos vacíos que aportan líneas en blanco.
  static List<_Entry> _topLevelEntries(List<String> lines) {
    final entries = <_Entry>[];
    var i = 0;
    final n = lines.length;
    while (i < n) {
      if (lines[i].trim().isEmpty) {
        var j = i;
        while (j < n && lines[j].trim().isEmpty) {
          j++;
        }
        final blanks = j - i;
        final sepCount = (blanks + 1) ~/ 2;
        final before = entries.isNotEmpty;
        final after = j < n;
        final empties = (before && after)
            ? (sepCount > 0 ? sepCount - 1 : 0)
            : sepCount;
        for (var k = 0; k < empties; k++) {
          entries.add(_Entry(MdNode.paragraph(), i, i, virtual: true));
        }
        i = j;
        continue;
      }
      final result = _parseBlock(lines, i);
      entries.add(_Entry(result.node, i, result.next));
      i = result.next;
    }
    return entries;
  }

  static List<MdNode> _parseBlockLines(List<String> lines) {
    final blocks = <MdNode>[];
    var i = 0;
    final n = lines.length;
    while (i < n) {
      if (lines[i].trim().isEmpty) {
        var j = i;
        while (j < n && lines[j].trim().isEmpty) {
          j++;
        }
        final blanks = j - i;
        final sepCount = (blanks + 1) ~/ 2;
        final before = blocks.isNotEmpty;
        final after = j < n;
        final empties = (before && after)
            ? (sepCount > 0 ? sepCount - 1 : 0)
            : sepCount;
        for (var k = 0; k < empties; k++) {
          blocks.add(MdNode.paragraph());
        }
        i = j;
        continue;
      }
      final result = _parseBlock(lines, i);
      blocks.add(result.node);
      i = result.next;
    }
    return blocks;
  }

  static _BlockResult _parseBlock(List<String> lines, int i) {
    final line = lines[i];

    final heading = _headingRe.firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final text = heading.group(2)!;
      return _BlockResult(
        MdNode.heading(level, text.isEmpty ? const [] : _inline(text)),
        i + 1,
      );
    }

    if (_hrRe.hasMatch(line)) {
      return _BlockResult(MdNode.horizontalRule, i + 1);
    }

    final fence = _fenceRe.firstMatch(line);
    if (fence != null) {
      final marker = fence.group(1)!;
      final info = fence.group(2)!.trim();
      final close = _findFenceClose(lines, i + 1, marker);
      if (close >= 0) {
        final code = lines.sublist(i + 1, close).join('\n');
        return _BlockResult(
          MdNode.codeBlock(info.isEmpty ? null : info, code),
          close + 1,
        );
      }
    }

    if (_quoteRe.hasMatch(line)) {
      final inner = <String>[];
      var j = i;
      while (j < lines.length && _quoteRe.hasMatch(lines[j])) {
        inner.add(_stripQuote(lines[j]));
        j++;
      }
      return _BlockResult(MdNode.blockquote(_parseBlockLines(inner)), j);
    }

    final marker = _listMarker(line);
    if (marker != null && marker.indent == 0) {
      return _parseList(lines, i, marker);
    }

    // Bloque opaco: lo que el editor de la web no entiende y el móvil conserva intacto (§8.2.5).
    final opaque = _matchOpaque(lines, i);
    if (opaque != null) {
      return _BlockResult(MdNode.opaque(opaque.text), opaque.next);
    }

    final paragraph = <String>[];
    var j = i;
    // La primera línea se toma siempre (aunque parezca el inicio de otro bloque sin cuerpo, como una
    // valla sin cerrar): si no, no se avanzaría. Las siguientes, solo si no abren un bloque nuevo.
    while (j < lines.length &&
        lines[j].trim().isNotEmpty &&
        (j == i || !_startsBlock(lines[j]))) {
      paragraph.add(lines[j]);
      j++;
    }
    final paragraphText = paragraph.join('\n');
    // Un párrafo con una imagen en línea es opaco: la web la degrada a su texto alternativo.
    if (_imageRe.hasMatch(paragraphText)) {
      return _BlockResult(MdNode.opaque(paragraphText), j);
    }
    return _BlockResult(
      MdNode.paragraph(_inline(_withHardBreaks(paragraphText))),
      j,
    );
  }

  static bool _startsBlock(String line) {
    if (_headingRe.hasMatch(line)) return true;
    if (_hrRe.hasMatch(line)) return true;
    if (_fenceRe.hasMatch(line)) return true;
    if (_quoteRe.hasMatch(line)) return true;
    final marker = _listMarker(line);
    return marker != null && marker.indent == 0;
  }

  static int _findFenceClose(List<String> lines, int from, String marker) {
    for (var j = from; j < lines.length; j++) {
      if (_fenceCloseRe.hasMatch(lines[j])) return j;
    }
    return -1;
  }

  static String _stripQuote(String line) =>
      line.startsWith('> ') ? line.substring(2) : line.substring(1);

  static int _indentOf(String line) {
    var count = 0;
    for (final unit in line.codeUnits) {
      if (unit == 0x20) {
        count++;
      } else if (unit == 0x09) {
        count += 2;
      } else {
        break;
      }
    }
    return count;
  }

  static List<String> _dedent(List<String> lines) {
    var min = 1 << 30;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final indent = _indentOf(line);
      if (indent < min) min = indent;
    }
    if (min == 1 << 30 || min == 0) return lines;
    return [
      for (final line in lines)
        line.trim().isEmpty ? '' : line.substring(min.clamp(0, line.length)),
    ];
  }

  static _ListMarker? _listMarker(String line) {
    final match = _listRe.firstMatch(line);
    if (match == null) return null;
    final indent = match.group(1)!.length;
    final bullet = match.group(2)!;
    final content = match.group(4)!;
    final isOrdered = RegExp(r'^\d').hasMatch(bullet);
    if (!isOrdered) {
      final task = _taskRe.firstMatch(content);
      if (task != null) {
        return _ListMarker(
          indent: indent,
          kind: 'task',
          number: 0,
          checked: task.group(1)!.toLowerCase() == 'x',
          content: task.group(3)!,
        );
      }
    }
    return _ListMarker(
      indent: indent,
      kind: isOrdered ? 'ordered' : 'bullet',
      number: isOrdered ? int.parse(bullet.replaceAll(RegExp(r'[.)]'), '')) : 0,
      checked: false,
      content: content,
    );
  }

  static _BlockResult _parseList(
    List<String> lines,
    int start,
    _ListMarker first,
  ) {
    final items = <MdNode>[];
    var j = start;
    final n = lines.length;
    while (j < n) {
      final marker = _listMarker(lines[j]);
      if (marker == null || marker.indent != 0 || marker.kind != first.kind) {
        break;
      }

      final nested = <String>[];
      var k = j + 1;
      while (k < n) {
        if (lines[k].trim().isEmpty) {
          var kk = k;
          while (kk < n && lines[kk].trim().isEmpty) {
            kk++;
          }
          if (kk < n && _indentOf(lines[kk]) >= 1) {
            for (var t = k; t < kk; t++) {
              nested.add(lines[t]);
            }
            k = kk;
          } else {
            break;
          }
        } else if (_indentOf(lines[k]) >= 1) {
          nested.add(lines[k]);
          k++;
        } else {
          break;
        }
      }

      final innerLines = <String>[marker.content, ..._dedent(nested)];
      final content = _parseBlockLines(innerLines);
      items.add(
        first.kind == 'task'
            ? MdNode.taskItem(marker.checked, content)
            : MdNode.listItem(content),
      );
      j = k;
    }

    final node = switch (first.kind) {
      'task' => MdNode.taskList(items),
      'ordered' => MdNode.orderedList(first.number, items),
      _ => MdNode.bulletList(items),
    };
    return _BlockResult(node, j);
  }

  // ── En línea ──

  /// Sustituye los marcadores de salto duro (dos espacios o barra invertida al final de línea) por
  /// el centinela `\u0000`, que el analizador en línea convierte en un nodo de salto.
  static String _withHardBreaks(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (var k = 0; k < lines.length; k++) {
      final line = lines[k];
      if (k < lines.length - 1) {
        final match = RegExp(r'( {2,}|\\)$').firstMatch(line);
        if (match != null) {
          buffer.write(line.substring(0, line.length - match.group(0)!.length));
          buffer.write('\u0000');
        } else {
          buffer.write(line);
          buffer.write('\n');
        }
      } else {
        buffer.write(line);
      }
    }
    return buffer.toString();
  }

  static List<MdNode> _inline(String text) => _parseInline(text);

  static List<MdNode> _parseInline(String text) {
    final root = <MdNode>[];
    final frames = <List<MdNode>>[root];
    final open = <_Open>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      frames.last.add(MdNode.textNode(buffer.toString()));
      buffer.clear();
    }

    void close(_Open o) {
      flush();
      final children = frames.removeLast();
      frames.last.addAll(_applyMark(children, o.mark));
    }

    var i = 0;
    final len = text.length;
    while (i < len) {
      final c = text[i];

      if (c == '\u0000') {
        flush();
        frames.last.add(MdNode.hardBreak);
        i++;
        continue;
      }

      if (c == '\\' && i + 1 < len && _escapable.contains(text[i + 1])) {
        buffer.write(text[i + 1]);
        i += 2;
        continue;
      }

      if (c == '`') {
        final run = _runLength(text, i, '`');
        final closeAt = _findBacktickClose(text, i + run, run);
        if (closeAt >= 0) {
          flush();
          var content = text.substring(i + run, closeAt);
          if (content.length >= 2 &&
              content.startsWith(' ') &&
              content.endsWith(' ') &&
              content.trim().isNotEmpty) {
            content = content.substring(1, content.length - 1);
          }
          frames.last.add(MdNode.textNode(content, const [MdMark.code]));
          i = closeAt + run;
          continue;
        }
        buffer.write(text.substring(i, i + run));
        i += run;
        continue;
      }

      if (c == '[') {
        final link = _tryLink(text, i);
        if (link != null) {
          flush();
          frames.last.addAll(_applyMark(link.content, link.mark));
          i = link.end;
          continue;
        }
        buffer.write('[');
        i++;
        continue;
      }

      if (c == '<') {
        final autolink = _tryAutolink(text, i);
        if (autolink != null) {
          flush();
          frames.last.addAll(_applyMark(autolink.content, autolink.mark));
          i = autolink.end;
          continue;
        }
        buffer.write('<');
        i++;
        continue;
      }

      if (c == '&') {
        final entity = _tryEntity(text, i);
        if (entity != null) {
          buffer.write(entity.text);
          i = entity.end;
          continue;
        }
        buffer.write('&');
        i++;
        continue;
      }

      if (c == '*' || c == '_' || c == '~' || c == '+') {
        var remaining = _runLength(text, i, c);
        final runLength = remaining;
        while (open.isNotEmpty &&
            open.last.char == c &&
            remaining >= open.last.length) {
          remaining -= open.last.length;
          close(open.removeLast());
        }
        if (remaining > 0) {
          final marks = _marksForRun(c, remaining);
          if (marks.isEmpty) {
            buffer.write(text.substring(i, i + runLength));
          } else {
            for (final m in marks) {
              flush();
              frames.add(<MdNode>[]);
              open.add(_Open(m, c, _delimiterLength(c, m)));
            }
          }
        }
        i += runLength;
        continue;
      }

      buffer.write(c);
      i++;
    }
    flush();
    return root;
  }

  static const String _escapable = r'*_`[]~\\<>#-+.()!';

  static int _runLength(String text, int start, String ch) {
    var i = start;
    while (i < text.length && text[i] == ch) {
      i++;
    }
    return i - start;
  }

  static int _findBacktickClose(String text, int from, int run) {
    var i = from;
    while (i < text.length) {
      if (text[i] == '`') {
        final length = _runLength(text, i, '`');
        if (length == run) return i;
        i += length;
      } else {
        i++;
      }
    }
    return -1;
  }

  static int _delimiterLength(String char, MdMark mark) => switch (mark.type) {
    MdMarkType.bold => 2,
    MdMarkType.italic => 1,
    MdMarkType.strike => 2,
    MdMarkType.underline => 2,
    _ => 1,
  };

  static List<MdMark> _marksForRun(String char, int length) {
    switch (char) {
      case '*':
      case '_':
        if (length >= 3) return const [MdMark.bold, MdMark.italic];
        if (length == 2) return const [MdMark.bold];
        return const [MdMark.italic];
      case '~':
        return length >= 2 ? const [MdMark.strike] : const [];
      case '+':
        return length >= 2 ? const [MdMark.underline] : const [];
    }
    return const [];
  }

  static List<MdNode> _applyMark(List<MdNode> nodes, MdMark mark) {
    final out = <MdNode>[];
    for (final node in nodes) {
      if (node.type == MdNodeType.text) {
        final marks = [...node.marks];
        if (!marks.contains(mark)) marks.add(mark);
        out.add(MdNode.textNode(node.text ?? '', marks));
      } else {
        out.add(node);
      }
    }
    return out;
  }

  static _InlineLink? _tryLink(String text, int start) {
    final close = _matchBracket(text, start);
    if (close < 0) return null;
    if (close + 1 >= text.length || text[close + 1] != '(') return null;
    final parenClose = _matchParen(text, close + 1);
    if (parenClose < 0) return null;

    final label = text.substring(start + 1, close);
    var destination = text.substring(close + 2, parenClose);
    String? title;
    final titleMatch = RegExp(r'^(\S+)\s+"([^"]*)"$').firstMatch(destination);
    if (titleMatch != null) {
      destination = titleMatch.group(1)!;
      title = titleMatch.group(2);
    }
    final mark = MdMark(MdMarkType.link, href: destination, title: title);
    return _InlineLink(_parseInline(label), mark, parenClose + 1);
  }

  static int _matchBracket(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '[') depth++;
      if (c == ']') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static int _matchParen(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static _InlineLink? _tryAutolink(String text, int start) {
    final match = RegExp(r'^<((?:https?://|mailto:)[^>\s]+)>')
        .firstMatch(text.substring(start));
    if (match == null) return null;
    final url = match.group(1)!;
    final href = url.startsWith('mailto:') ? url : url;
    return _InlineLink(
      [MdNode.textNode(url)],
      MdMark(MdMarkType.link, href: href),
      start + match.group(0)!.length,
    );
  }

  static _InlineEntity? _tryEntity(String text, int start) {
    final match = RegExp(
      r'^&(?:#([0-9]+)|#x([0-9a-fA-F]+)|([a-zA-Z][a-zA-Z0-9]*));',
    ).firstMatch(text.substring(start));
    if (match == null) return null;
    final end = start + match.group(0)!.length;
    String? decoded;
    if (match.group(1) != null) {
      decoded = String.fromCharCode(int.parse(match.group(1)!));
    } else if (match.group(2) != null) {
      decoded = String.fromCharCode(int.parse(match.group(2)!, radix: 16));
    } else {
      decoded = _namedEntities[match.group(3)!];
    }
    if (decoded == null) return null;
    return _InlineEntity(decoded, end);
  }

  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': '\u00A0',
  };
}

class _ListMarker {
  _ListMarker({
    required this.indent,
    required this.kind,
    required this.number,
    required this.checked,
    required this.content,
  });

  final int indent;
  final String kind;
  final int number;
  final bool checked;
  final String content;
}

class _Open {
  _Open(this.mark, this.char, this.length);
  final MdMark mark;
  final String char;
  final int length;
}

class _InlineLink {
  _InlineLink(this.content, this.mark, this.end);
  final List<MdNode> content;
  final MdMark mark;
  final int end;
}

class _InlineEntity {
  _InlineEntity(this.text, this.end);
  final String text;
  final int end;
}

class _Opaque {
  _Opaque(this.text, this.next);
  final String text;
  final int next;
}
