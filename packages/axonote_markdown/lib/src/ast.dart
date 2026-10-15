/// Modelo de bloques y marcas del Markdown de AxoNote.
///
/// Refleja el documento que emite y lee el editor de la web (TipTap 3 con `StarterKit` +
/// `TaskList` + `TaskItem` anidado, §8.1 del plan). Es un árbol de nodos con nombre, atributos,
/// contenido y marcas, igual que el JSON de TipTap, para que el códec sea el mismo de ida y de
/// vuelta. Dart puro.
library;

/// Nombres de los tipos de nodo (los mismos de TipTap).
abstract final class MdNodeType {
  static const doc = 'doc';
  static const paragraph = 'paragraph';
  static const heading = 'heading';
  static const bulletList = 'bulletList';
  static const orderedList = 'orderedList';
  static const listItem = 'listItem';
  static const taskList = 'taskList';
  static const taskItem = 'taskItem';
  static const blockquote = 'blockquote';
  static const codeBlock = 'codeBlock';
  static const horizontalRule = 'horizontalRule';
  static const hardBreak = 'hardBreak';
  static const text = 'text';

  /// Bloque que el editor de la web no entiende (tabla, HTML, imagen, nota al pie): se conserva
  /// intacto y se muestra como tarjeta de solo lectura (§8.2.5).
  static const opaque = 'opaque';
}

/// Nombres de marca (los mismos de TipTap).
abstract final class MdMarkType {
  static const bold = 'bold';
  static const italic = 'italic';
  static const strike = 'strike';
  static const underline = 'underline';
  static const code = 'code';
  static const link = 'link';
}

/// Rango de apertura de cada marca, de fuera hacia dentro (medido contra los vectores
/// `markdown.json`; el enlace envuelve a las demás y el subrayado queda dentro de todo).
const Map<String, int> _markRank = {
  MdMarkType.link: 0,
  MdMarkType.bold: 1,
  MdMarkType.italic: 2,
  MdMarkType.strike: 3,
  MdMarkType.underline: 4,
  MdMarkType.code: 5,
};

/// Una marca aplicada a un texto.
class MdMark {
  const MdMark(this.type, {this.href, this.title});

  final String type;

  /// Solo para `link`.
  final String? href;

  /// Solo para `link` (puede ser `null`).
  final String? title;

  static const MdMark bold = MdMark(MdMarkType.bold);
  static const MdMark italic = MdMark(MdMarkType.italic);
  static const MdMark strike = MdMark(MdMarkType.strike);
  static const MdMark underline = MdMark(MdMarkType.underline);
  static const MdMark code = MdMark(MdMarkType.code);

  MdMark copyWith({String? href, String? title}) =>
      MdMark(type, href: href ?? this.href, title: title ?? this.title);

  Map<String, Object?> toJson() {
    final attrs = <String, Object?>{};
    if (type == MdMarkType.link) {
      attrs['href'] = href;
      attrs['title'] = title;
    }
    return attrs.isEmpty ? {'type': type} : {'type': type, 'attrs': attrs};
  }

  static MdMark fromJson(Map<String, Object?> json) {
    final type = json['type']! as String;
    final attrs = json['attrs'];
    if (type == MdMarkType.link && attrs is Map) {
      return MdMark(
        type,
        href: attrs['href'] as String?,
        title: attrs['title'] as String?,
      );
    }
    return MdMark(type);
  }

  @override
  bool operator ==(Object other) =>
      other is MdMark &&
      other.type == type &&
      other.href == href &&
      other.title == title;

  @override
  int get hashCode => Object.hash(type, href, title);

  @override
  String toString() => 'MdMark($type, href: $href, title: $title)';

  static int compareByRank(MdMark a, MdMark b) =>
      (_markRank[a.type] ?? 99).compareTo(_markRank[b.type] ?? 99);
}

/// Un nodo del árbol: bloque, texto o salto duro.
class MdNode {
  MdNode(
    this.type, {
    Map<String, Object?>? attrs,
    List<MdNode>? content,
    this.text,
    List<MdMark>? marks,
  }) : attrs = attrs ?? const {},
       content = content ?? const [],
       marks = marks ?? const [];

  final String type;
  final Map<String, Object?> attrs;
  final List<MdNode> content;
  final String? text;
  final List<MdMark> marks;

  bool get isText => type == MdNodeType.text;
  bool get isBlockText => type == MdNodeType.paragraph;

  // ── Constructores de conveniencia ──
  static MdNode doc([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.doc, content: content);
  static MdNode paragraph([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.paragraph, content: content);
  static MdNode heading(int level, [List<MdNode> content = const []]) =>
      MdNode(MdNodeType.heading, attrs: {'level': level}, content: content);
  static MdNode bulletList([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.bulletList, content: content);
  static MdNode orderedList(int start, [List<MdNode> content = const []]) =>
      MdNode(MdNodeType.orderedList, attrs: {'start': start}, content: content);
  static MdNode listItem([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.listItem, content: content);
  static MdNode taskList([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.taskList, content: content);
  static MdNode taskItem(bool checked, [List<MdNode> content = const []]) =>
      MdNode(
        MdNodeType.taskItem,
        attrs: {'checked': checked},
        content: content,
      );
  static MdNode blockquote([List<MdNode> content = const []]) =>
      MdNode(MdNodeType.blockquote, content: content);
  static MdNode codeBlock(String? language, String code) => MdNode(
    MdNodeType.codeBlock,
    attrs: {'language': language},
    content: code.isEmpty ? const [] : [MdNode.textNode(code)],
  );
  static final MdNode horizontalRule = MdNode(MdNodeType.horizontalRule);
  static final MdNode hardBreak = MdNode(MdNodeType.hardBreak);
  static MdNode textNode(String value, [List<MdMark> marks = const []]) =>
      MdNode(MdNodeType.text, text: value, marks: marks);

  /// Bloque opaco: conserva su texto original en `attrs['source']`.
  static MdNode opaque(String source) =>
      MdNode(MdNodeType.opaque, attrs: {'source': source});

  /// Texto plano del subárbol (sin marcas), uniendo los nodos de texto.
  String get plainText => type == MdNodeType.text
      ? (text ?? '')
      : content.map((c) => c.plainText).join();

  /// `true` si es un bloque vacío (párrafo o elemento de lista sin texto real).
  bool get isEmptyParagraph {
    if (type != MdNodeType.paragraph) return false;
    final t = plainText.replaceAll('\u00A0', '');
    return t.trim().isEmpty;
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{'type': type};
    if (attrs.isNotEmpty) json['attrs'] = attrs;
    if (text != null) json['text'] = text;
    if (marks.isNotEmpty) json['marks'] = marks.map((m) => m.toJson()).toList();
    if (content.isNotEmpty) {
      json['content'] = content.map((c) => c.toJson()).toList();
    }
    return json;
  }

  /// Huella estructural estable (claves ordenadas) para la conservación por bloque (§8.2.4).
  String get fingerprint {
    final buffer = StringBuffer(type);
    if (attrs.isNotEmpty) {
      final keys = attrs.keys.toList()..sort();
      buffer.write('{');
      for (final key in keys) {
        buffer.write('$key=${attrs[key]};');
      }
      buffer.write('}');
    }
    if (text != null) buffer.write('t:${text!.length}:$text');
    if (marks.isNotEmpty) {
      final sorted = [...marks]..sort((a, b) => a.type.compareTo(b.type));
      for (final mark in sorted) {
        buffer.write('m:${mark.type}');
        if (mark.href != null) buffer.write(':${mark.href}');
        if (mark.title != null) buffer.write(':"${mark.title}"');
      }
    }
    if (content.isNotEmpty) {
      buffer.write('[');
      for (final child in content) {
        buffer.write(child.fingerprint);
        buffer.write(',');
      }
      buffer.write(']');
    }
    return buffer.toString();
  }

  static MdNode fromJson(Map<String, Object?> json) {
    final marksJson = json['marks'];
    return MdNode(
      json['type']! as String,
      attrs: (json['attrs'] as Map?)?.cast<String, Object?>() ?? const {},
      content: ((json['content'] as List?) ?? const [])
          .map((c) => MdNode.fromJson((c as Map).cast<String, Object?>()))
          .toList(),
      text: json['text'] as String?,
      marks: marksJson is List
          ? marksJson
                .map((m) => MdMark.fromJson((m as Map).cast<String, Object?>()))
                .toList()
          : const [],
    );
  }
}
