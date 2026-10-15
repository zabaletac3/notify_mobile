import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Tarjeta de nota del diseño nuevo (tablero «Android — Lista de notas»): fila plana de 80 px,
/// radio 10, relleno [12,14] y hueco 4, **sin relleno de fondo**. Tres filas: pin + título
/// (14/600), fecha (12/500) + vista previa (12/400) y carpeta (icono 11 + etiqueta 11/500).
///
/// `folderLabel` es el texto de la tercera fila (la carpeta, o «Se elimina en N días» en la
/// papelera). `highlight` resalta las coincidencias de la búsqueda en título y vista previa: el
/// color de resalte no está en el tablero, así que se usa el fondo seleccionado (`bgSelected`).
class AxoNoteCard extends StatelessWidget {
  const AxoNoteCard({
    super.key,
    required this.title,
    this.preview = '',
    this.date,
    this.pinned = false,
    this.folderLabel,
    this.unreadable = false,
    this.highlight,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String preview;
  final String? date;
  final bool pinned;
  final String? folderLabel;
  final bool unreadable;
  final String? highlight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final folder = folderLabel;
    return Semantics(
      button: onTap != null,
      label: title,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AxoRadii.chip),
        child: Container(
          height: AxoSizes.noteCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pinned) ...[
                    AppIcon('pin', size: 13, color: c.tagAmber),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: _HighlightedText(
                      text: unreadable ? 'Nota ilegible' : title,
                      highlight: highlight,
                      style: AxoType.noteTitle.copyWith(
                        color: unreadable ? c.textTertiary : c.textPrimary,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AxoSpacing.xs),
              Row(
                children: [
                  if (date != null) ...[
                    Text(
                      date!,
                      style: AxoType.meta12med.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(width: AxoSpacing.sm),
                  ],
                  Expanded(
                    child: _HighlightedText(
                      text: preview,
                      highlight: highlight,
                      style: AxoType.caption.copyWith(color: c.textTertiary),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (folder != null) ...[
                const SizedBox(height: AxoSpacing.xs),
                Row(
                  children: [
                    AppIcon('folder', size: 11, color: c.textTertiary),
                    const SizedBox(width: AxoSpacing.xs),
                    Expanded(
                      child: Text(
                        folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AxoType.meta11.copyWith(color: c.textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto con las coincidencias de [highlight] resaltadas (sin distinguir mayúsculas ni tildes).
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final String? highlight;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final term = highlight?.trim();
    if (term == null || term.isEmpty || text.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final c = Theme.of(context).extension<AxoColors>()!;
    final spans = highlightSpans(text, term, style, c.bgSelected);
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Divide [text] en tramos, resaltando (con [background]) los que coinciden con [term] sin
/// distinguir mayúsculas ni tildes. Se usa en la lista de resultados de búsqueda.
List<TextSpan> highlightSpans(
  String text,
  String term,
  TextStyle style,
  Color background,
) {
  final foldedText = _fold(text);
  final foldedTerm = _fold(term);
  if (foldedTerm.isEmpty) return [TextSpan(text: text, style: style)];
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = foldedText.indexOf(foldedTerm, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: style));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + term.length),
        style: style.copyWith(backgroundColor: background),
      ),
    );
    start = index + term.length;
  }
  return spans;
}

/// Forma plegada (minúsculas y sin tildes) para buscar coincidencias. `foldText` del dominio no se
/// importa aquí (la interfaz no depende de él); se pliega lo justo para latinas.
String _fold(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const to = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final ch = String.fromCharCode(rune);
    final index = from.indexOf(ch);
    buffer.write(index >= 0 ? to[index] : ch.toLowerCase());
  }
  return buffer.toString();
}
