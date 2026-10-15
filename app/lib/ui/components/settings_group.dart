import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Grupo de ajustes (tableros «Android — Ajustes…»): encabezado de sección en mayúsculas (11/600
/// `textTertiary`) y una tarjeta `bgApp` con filas separadas por un divisor `borderDefault`.
class AxoSettingsGroup extends StatelessWidget {
  const AxoSettingsGroup({super.key, required this.children, this.title});

  /// Encabezado de la sección (p. ej. «Apariencia»). Si es `null`, la tarjeta va sin encabezado.
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: c.borderDefault));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: AxoType.settingsSectionLabel.copyWith(
                color: c.textTertiary,
              ),
            ),
          ),
        Material(
          color: c.bgApp,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AxoRadii.xl),
            side: BorderSide(color: c.borderDefault),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// Fila de una tarjeta de ajustes (tableros «Android — Ajustes…, Mi cuenta, …»): etiqueta 15/500 y,
/// a la derecha, un control ([control]), un valor 14/500, una acción 14/600 o un chevron. La altura
/// sale del contenido: 52 (valor/chevron), 54 (interruptor), 66 (con descripción) o 46 (solo acción
/// o fila de peligro).
class AxoSettingRow extends StatelessWidget {
  const AxoSettingRow({
    super.key,
    required this.label,
    this.description,
    this.value,
    this.action,
    this.onAction,
    this.chevron = false,
    this.danger = false,
    this.control,
    this.onTap,
  });

  final String label;
  final String? description;
  final String? value;

  /// Acción a la derecha («Cambiar», «Quitar»); se toca con [onAction].
  final String? action;
  final VoidCallback? onAction;
  final bool chevron;
  final bool danger;

  /// Control a la derecha (p. ej. un [AxoSwitch]). Tiene prioridad sobre [value]/[action].
  final Widget? control;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final labelColor = danger ? c.statusDanger : c.textPrimary;
    final height = description != null
        ? AxoSizes.settingsRowTall
        : control != null
        ? AxoSizes.settingsRowSwitch
        : (value != null || chevron)
        ? AxoSizes.settingsRow
        : AxoSizes.settingsRowCompact;

    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxoType.settingsRowLabel.copyWith(color: labelColor),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: AxoType.settingsRowDescription.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?control,
            if (control == null && value != null) ...[
              const SizedBox(width: 12),
              Text(
                value!,
                style: AxoType.settingsRowValue.copyWith(color: c.textTertiary),
              ),
            ],
            if (control == null && action != null) ...[
              const SizedBox(width: 12),
              _RowAction(
                label: action!,
                color: danger ? c.statusDanger : c.accentDefault,
                onTap: onAction,
              ),
            ],
            if (chevron) ...[
              const SizedBox(width: 12),
              AppIcon('chevron-right', size: 20, color: c.textTertiary),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: AxoType.settingsRowAction.copyWith(color: color),
    );
    if (onTap == null) return text;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: text,
      ),
    );
  }
}
