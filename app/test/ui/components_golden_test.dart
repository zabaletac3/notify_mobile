import 'package:axonote_app/ui/components.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga la fuente Inter (empaquetada en `assets/fonts`) en las pruebas.
Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

/// Renderiza `child` en claro y en oscuro sobre una superficie fija y compara con el golden.
Future<void> runGolden(WidgetTester tester, String name, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 260);
  addTearDown(tester.view.reset);

  for (final (mode, theme) in [
    ('light', AxoTheme.light()),
    ('dark', AxoTheme.dark()),
  ]) {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name-$mode.png'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('botón', (t) async {
    await runGolden(
      t,
      'button',
      const AxoButton(label: 'Guardar', onPressed: _noop),
    );
  });

  testWidgets('campo', (t) async {
    await runGolden(
      t,
      'field',
      const AxoField(label: 'Correo', hint: 'tu@correo.com'),
    );
  });

  testWidgets('interruptor', (t) async {
    await runGolden(
      t,
      'switch',
      const AxoSwitch(value: true, onChanged: _onChanged),
    );
  });

  testWidgets('casilla', (t) async {
    await runGolden(
      t,
      'checkbox',
      const AxoCheckbox(
        value: true,
        label: 'Recordarme',
        onChanged: _onChanged,
      ),
    );
  });

  testWidgets('otp', (t) async {
    await runGolden(t, 'otp', const AxoOtpField(value: '1234'));
  });

  testWidgets('entrada OTP', (t) async {
    await runGolden(t, 'otp-input', const AxoOtpInput());
  });

  testWidgets('fuerza de contraseña', (t) async {
    await runGolden(
      t,
      'password-strength',
      const SizedBox(width: 300, child: AxoPasswordStrength(score: 2)),
    );
  });

  testWidgets('toast', (t) async {
    await runGolden(
      t,
      'toast',
      const SizedBox(
        width: 340,
        child: AxoToast(
          message: 'Nota movida a Ideas',
          variant: AxoToastVariant.success,
          actionLabel: 'Deshacer',
        ),
      ),
    );
  });

  testWidgets('tarjeta de nota', (t) async {
    await runGolden(
      t,
      'note-card',
      const AxoNoteCard(
        title: 'Resumen: Bases de datos II',
        preview: 'La normalización organiza las tablas…',
        date: '28 sep',
        pinned: true,
      ),
    );
  });

  testWidgets('hoja inferior', (t) async {
    await runGolden(
      t,
      'bottom-sheet',
      const AxoBottomSheet(
        title: 'Nueva carpeta',
        children: [
          AxoField(hint: 'Nombre de la carpeta'),
          SizedBox(height: 16),
          AxoButton(label: 'Crear', onPressed: _noop, expand: true),
        ],
      ),
    );
  });

  testWidgets('elemento de menú', (t) async {
    await runGolden(
      t,
      'menu-item',
      const AxoMenuItem(label: 'Duplicar', icon: 'copy', onTap: _noop),
    );
  });

  testWidgets('diálogo', (t) async {
    await runGolden(
      t,
      'dialog',
      const AxoDialog(
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
    );
  });

  testWidgets('aviso', (t) async {
    await runGolden(
      t,
      'banner',
      const AxoBanner(
        message: 'Sin conexión. Se sincronizará al recuperar la red.',
        variant: AxoBannerVariant.danger,
      ),
    );
  });
}

void _noop() {}
void _onChanged(bool _) {}
