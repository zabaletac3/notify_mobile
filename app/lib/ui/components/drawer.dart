import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Una entrada del menú lateral (tablero «Android — Menú lateral», «SidebarItem»): 34 de alto,
/// radio 8, relleno [7,10], hueco 10, icono 18, etiqueta 14/500 y contador 12/500. Activa: relleno
/// `bgSelected` y todo en `accent` (etiqueta 14/600).
class AxoDrawerItem extends StatelessWidget {
  const AxoDrawerItem({
    super.key,
    required this.label,
    this.icon,
    this.count,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String? icon;
  final String? count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final fg = selected ? c.accentDefault : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? c.bgSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(AxoRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AxoRadii.sm),
          child: Container(
            height: AxoSizes.sidebarItem,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, size: 18, color: fg),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (selected ? AxoType.chipActive : AxoType.navItem)
                        .copyWith(color: fg),
                  ),
                ),
                if (count != null)
                  Text(
                    count!,
                    style: AxoType.meta12med.copyWith(
                      color: selected ? c.accentDefault : c.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de sección del menú lateral («BIBLIOTECA», «CARPETAS», «ETIQUETAS»): 11/600
/// `textTertiary`, relleno [14,0,6,10].
class AxoDrawerSection extends StatelessWidget {
  const AxoDrawerSection({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 6, 10),
      child: Text(
        label.toUpperCase(),
        style: AxoType.sectionLabel.copyWith(color: c.textTertiary),
      ),
    );
  }
}

/// Menú lateral (tablero «Android — Menú lateral», «Drawer»): 304 de ancho, relleno `bgSidebar`,
/// radios [0,20,20,0], relleno [54,12,14,12], hueco 2 y borde derecho 1. Marca arriba y, al pie,
/// «Nueva carpeta».
class AxoDrawer extends StatelessWidget {
  const AxoDrawer({
    super.key,
    required this.sections,
    this.onNewFolder,
    this.onClose,
  });

  /// Bloques del menú (encabezados y entradas), en orden.
  final List<Widget> sections;
  final VoidCallback? onNewFolder;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Drawer(
      backgroundColor: c.bgSidebar,
      width: AxoSizes.drawer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.accentDefault,
                      borderRadius: BorderRadius.circular(AxoRadii.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'a',
                      style: TextStyle(
                        fontFamily: AxoType.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.accentOn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AxoNote',
                    style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
                  ),
                  const Spacer(),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: AppIcon('x', size: 18, color: c.textPrimary),
                    ),
                ],
              ),
              const SizedBox(height: AxoSpacing.sm),
              Expanded(child: ListView(children: sections)),
              if (onNewFolder != null)
                InkWell(
                  onTap: onNewFolder,
                  borderRadius: BorderRadius.circular(AxoRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '+',
                          style: AxoType.heading.copyWith(
                            color: c.accentDefault,
                          ),
                        ),
                        const SizedBox(width: AxoSpacing.sm),
                        Text(
                          'Nueva carpeta',
                          style: AxoType.label.copyWith(
                            color: c.accentDefault,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
