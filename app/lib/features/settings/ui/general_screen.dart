import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components.dart';
import '../state/settings_controller.dart';
import 'settings_labels.dart';
import 'settings_widgets.dart';

/// Ajustes generales (`/settings/general`, tablero «Android — Ajustes generales»). El tema, el
/// tamaño de letra y el orden por defecto tienen efecto real y se persisten por cuenta
/// (fase 11.2b).
class GeneralScreen extends ConsumerWidget {
  const GeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    void set(AppSettings next) => ctrl.update(next);
    return SettingsScaffold(
      title: 'Ajustes generales',
      children: [
        AxoSettingsGroup(
          title: 'Apariencia',
          children: [
            AxoSettingRow(
              label: 'Tema',
              value: settingsThemeLabel(s.theme.wire),
              chevron: true,
              onTap: () => showSettingsChoice(
                context,
                title: 'Tema',
                value: s.theme.wire,
                options: const [
                  ('system', 'Sistema'),
                  ('light', 'Claro'),
                  ('dark', 'Oscuro'),
                ],
                onSelected: (v) => set(
                  s.copyWith(
                    theme: ThemePreference.values.firstWhere(
                      (t) => t.wire == v,
                    ),
                  ),
                ),
              ),
            ),
            AxoSettingRow(
              label: 'Tamaño del texto',
              value: settingsTextSizeLabel(s.textSize.wire),
              chevron: true,
              onTap: () => showSettingsChoice(
                context,
                title: 'Tamaño del texto',
                value: s.textSize.wire,
                options: const [
                  ('small', 'Pequeño'),
                  ('medium', 'Mediano'),
                  ('large', 'Grande'),
                ],
                onSelected: (v) => set(
                  s.copyWith(
                    textSize: TextSize.values.firstWhere((t) => t.wire == v),
                  ),
                ),
              ),
            ),
            const AxoSettingRow(
              label: 'Fuente del editor',
              value: 'Inter',
              chevron: true,
            ),
          ],
        ),
        AxoSettingsGroup(
          title: 'Notas',
          children: [
            AxoSettingRow(
              label: 'Orden de las notas',
              value: settingsNoteOrderLabel(s.noteOrder.wire),
              chevron: true,
              onTap: () => showSettingsChoice(
                context,
                title: 'Orden de las notas',
                value: s.noteOrder.wire,
                options: const [
                  ('updated', 'Fecha de edición'),
                  ('created', 'Fecha de creación'),
                  ('title', 'Título'),
                ],
                onSelected: (v) => set(
                  s.copyWith(
                    noteOrder: NoteOrder.values.firstWhere((t) => t.wire == v),
                  ),
                ),
              ),
            ),
            AxoSettingRow(
              label: 'Abrir con una nota nueva',
              control: AxoSwitch(
                value: s.openWithNewNote,
                onChanged: (v) => set(s.copyWith(openWithNewNote: v)),
              ),
            ),
            AxoSettingRow(
              label: 'Mostrar vista previa en la lista',
              control: AxoSwitch(
                value: s.showPreview,
                onChanged: (v) => set(s.copyWith(showPreview: v)),
              ),
            ),
          ],
        ),
        const AxoSettingsGroup(
          title: 'Idioma',
          children: [
            AxoSettingRow(
              label: 'Idioma de la app',
              value: 'Español',
              chevron: true,
            ),
          ],
        ),
      ],
    );
  }
}
