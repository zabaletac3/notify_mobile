import 'package:flutter/material.dart';

import '../ui/app_icon.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/tokens.dart';

/// Galería de los componentes base, solo para depuración (se abre desde la bienvenida vacía en modo
/// debug). Muestra cada componente con sus variantes y estados, con conmutador claro/oscuro.
class ComponentsGallery extends StatefulWidget {
  const ComponentsGallery({super.key});

  @override
  State<ComponentsGallery> createState() => _ComponentsGalleryState();
}

class _ComponentsGalleryState extends State<ComponentsGallery> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? AxoTheme.dark() : AxoTheme.light(),
      child: Builder(
        builder: (context) {
          final c = Theme.of(context).extension<AxoColors>()!;
          return Scaffold(
            backgroundColor: c.bgApp,
            appBar: AppBar(
              title: Text(
                'Componentes (dev)',
                style: AxoType.heading.copyWith(color: c.textPrimary),
              ),
              backgroundColor: c.bgApp,
              surfaceTintColor: Colors.transparent,
              actions: [
                AppIcon(_dark ? 'moon' : 'sun', color: c.textSecondary),
                const SizedBox(width: AxoSpacing.sm),
                AxoSwitch(
                  value: _dark,
                  onChanged: (v) => setState(() => _dark = v),
                ),
                const SizedBox(width: AxoSpacing.md),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AxoSpacing.lg),
              children: [
                const _Section('Botón', [
                  Wrap(
                    spacing: AxoSpacing.md,
                    runSpacing: AxoSpacing.md,
                    children: [
                      AxoButton(label: 'Primario', onPressed: _noop),
                      AxoButton(
                        label: 'Secundario',
                        variant: AxoButtonVariant.outline,
                        onPressed: _noop,
                      ),
                      AxoButton(
                        label: 'Destructivo',
                        variant: AxoButtonVariant.destructive,
                        onPressed: _noop,
                      ),
                      AxoButton(
                        label: 'Ternario',
                        variant: AxoButtonVariant.destructiveSoft,
                        onPressed: _noop,
                      ),
                      AxoButton(label: 'Deshabilitado'),
                      AxoButton(
                        label: 'Pequeño',
                        size: AxoButtonSize.sm,
                        onPressed: _noop,
                      ),
                      AxoButton(
                        label: 'Grande',
                        size: AxoButtonSize.lg,
                        onPressed: _noop,
                      ),
                      AxoButton(
                        label: 'Con icono',
                        icon: 'plus',
                        onPressed: _noop,
                      ),
                    ],
                  ),
                ]),
                const _Section('Campo', [
                  AxoField(label: 'Correo', hint: 'tu@correo.com'),
                  SizedBox(height: AxoSpacing.md),
                  AxoField(
                    label: 'Contraseña',
                    hint: '••••••••',
                    obscure: true,
                  ),
                  SizedBox(height: AxoSpacing.md),
                  AxoField(
                    label: 'Con error',
                    hint: 'tu@correo.com',
                    error: 'Ingresa un correo válido.',
                  ),
                ]),
                _Section('Interruptor', [
                  Row(
                    children: [
                      const AxoSwitch(value: true, onChanged: _onChanged),
                      const SizedBox(width: AxoSpacing.lg),
                      const AxoSwitch(value: false, onChanged: _onChanged),
                      const SizedBox(width: AxoSpacing.lg),
                      const AxoSwitch(value: true),
                      const SizedBox(width: AxoSpacing.sm),
                      Text(
                        '(deshabilitado)',
                        style: AxoType.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ]),
                const _Section('Casilla', [
                  Row(
                    children: [
                      AxoCheckbox(
                        value: true,
                        onChanged: _onChanged,
                        label: 'Marcada',
                      ),
                      SizedBox(width: AxoSpacing.xl),
                      AxoCheckbox(
                        value: false,
                        onChanged: _onChanged,
                        label: 'Sin marcar',
                      ),
                    ],
                  ),
                ]),
                const _Section('OTP', [
                  Row(
                    children: [
                      AxoOtpField(value: '1234'),
                      SizedBox(width: AxoSpacing.xl),
                      AxoOtpField(),
                    ],
                  ),
                ]),
                const _Section('Tarjeta de nota', [
                  AxoNoteCard(
                    title: 'Resumen: Bases de datos II',
                    preview: 'La normalización organiza…',
                    date: '28 sep',
                    pinned: true,
                  ),
                  SizedBox(height: AxoSpacing.sm),
                  AxoNoteCard(
                    title: 'Lista de compras',
                    preview: 'Leche, pan, tomates…',
                  ),
                ]),
                const _Section('Hoja inferior', [
                  AxoBottomSheet(
                    title: 'Nueva carpeta',
                    children: [
                      AxoField(hint: 'Nombre de la carpeta'),
                      SizedBox(height: AxoSpacing.lg),
                      AxoButton(label: 'Crear', onPressed: _noop, expand: true),
                    ],
                  ),
                ]),
                _Section('Elemento de menú', [
                  Container(
                    decoration: BoxDecoration(
                      color: c.bgEditor,
                      borderRadius: BorderRadius.circular(AxoRadii.lg),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AxoSpacing.xs,
                    ),
                    child: const Column(
                      children: [
                        AxoMenuItem(
                          label: 'Duplicar',
                          icon: 'copy',
                          onTap: _noop,
                        ),
                        AxoMenuItem(
                          label: 'Mover a carpeta',
                          icon: 'folder',
                          onTap: _noop,
                        ),
                        AxoMenuItem(
                          label: 'Eliminar',
                          icon: 'trash',
                          destructive: true,
                          onTap: _noop,
                        ),
                      ],
                    ),
                  ),
                ]),
                const _Section('Diálogo', [
                  AxoDialog(
                    title: 'Eliminar nota',
                    content: Text('Esta acción no se puede deshacer.'),
                    actions: [
                      AxoButton(
                        label: 'Cancelar',
                        variant: AxoButtonVariant.outline,
                        onPressed: _noop,
                      ),
                      AxoButton(
                        label: 'Eliminar',
                        variant: AxoButtonVariant.destructive,
                        onPressed: _noop,
                      ),
                    ],
                  ),
                ]),
                const _Section('Aviso', [
                  AxoBanner(
                    message:
                        'Sin conexión. Se sincronizará al recuperar la red.',
                    variant: AxoBannerVariant.danger,
                  ),
                  SizedBox(height: AxoSpacing.sm),
                  AxoBanner(
                    message: 'Nota guardada.',
                    variant: AxoBannerVariant.success,
                  ),
                  SizedBox(height: AxoSpacing.sm),
                  AxoBanner(message: 'Puedes deshacer esta acción.'),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AxoSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AxoType.caption.copyWith(
              color: c.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AxoSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

void _noop() {}
void _onChanged(bool _) {}
