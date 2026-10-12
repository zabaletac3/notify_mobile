import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';

/// Introducción de 3 pasos (tableros «1 · Onboarding — Onboarding 1–3», leídos por el MCP):
/// ilustración 362×340 (radio 28, `bgSelected`), título 28/700 centrado, cuerpo 15/400 centrado,
/// indicador de página, y botón primario 362×54. «Omitir» salta a la bienvenida.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;

  void _finish() => context.go('/welcome');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final steps = [
      (l10n.onboard1Title, l10n.onboard1Body, const _EditorIllustration()),
      (l10n.onboard2Title, l10n.onboard2Body, const _FoldersIllustration()),
      (l10n.onboard3Title, l10n.onboard3Body, const _SyncIllustration()),
    ];
    final (title, body, illustration) = steps[_index];
    final last = _index == steps.length - 1;

    return Scaffold(
      backgroundColor: c.bgEditor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: AxoSizes.menuItem,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      onTap: _finish,
                      borderRadius: BorderRadius.circular(AxoRadii.sm),
                      child: Text(
                        l10n.onboardSkip,
                        style: AxoType.noteTitle.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              illustration,
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AxoType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AxoType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.xxl),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? c.accentDefault
                              : c.borderDefault,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              AxoButton(
                label: last ? l10n.onboardStart : l10n.onboardNext,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    setState(() => _index++);
                  }
                },
              ),
              const SizedBox(height: AxoSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel de ilustración del diseño: 362×340, radio 28, `bgSelected`.
class _IllustrationPanel extends StatelessWidget {
  const _IllustrationPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SizedBox(
      height: 340,
      child: Container(
        decoration: BoxDecoration(
          color: c.bgSelected,
          borderRadius: BorderRadius.circular(AxoRadii.card),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Ilustración 1: tres notas con casilla (dos marcadas) y dos líneas.
class _EditorIllustration extends StatelessWidget {
  const _EditorIllustration();

  @override
  Widget build(BuildContext context) {
    return _IllustrationPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _NoteCard(checked: i < 2),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return _IllustrationCard(
      leading: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: checked ? c.accentDefault : Colors.transparent,
          shape: BoxShape.circle,
          border: checked ? null : Border.all(color: c.textTertiary, width: 2),
        ),
        child: checked
            ? Center(child: AppIcon('check', size: 12, color: c.accentOn))
            : null,
      ),
      lines: const [_Line(116, 8, true), _Line(80, 7, false)],
    );
  }
}

/// Ilustración 2: tres carpetas con nombre y número de notas.
class _FoldersIllustration extends StatelessWidget {
  const _FoldersIllustration();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    const folders = [('Universidad', '12'), ('Personal', '9'), ('Ideas', '5')];
    return _IllustrationPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < folders.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SizedBox(
              width: 240,
              height: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.bgEditor,
                  borderRadius: BorderRadius.circular(AxoRadii.lg),
                ),
                child: Row(
                  children: [
                    AppIcon('folder', size: 20, color: c.accentDefault),
                    const SizedBox(width: AxoSpacing.md),
                    Expanded(
                      child: Text(
                        folders[i].$1,
                        style: AxoType.bodyUi.copyWith(color: c.textPrimary),
                      ),
                    ),
                    Text(
                      folders[i].$2,
                      style: AxoType.label.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ilustración 3: escritorio y móvil con borde `accent`, y la pastilla «Sincronizado».
class _SyncIllustration extends StatelessWidget {
  const _SyncIllustration();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return _IllustrationPanel(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 72),
            child: SizedBox(
              width: 244,
              height: 156,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 40,
                    child: _DeviceFrame(width: 153, height: 116, radius: 10),
                  ),
                  Positioned(
                    left: 171,
                    top: 0,
                    child: _DeviceFrame(width: 73, height: 156, radius: 12),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 238),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AxoSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: c.bgEditor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.statusSuccess,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AxoSpacing.sm),
                  Text(
                    'Sincronizado',
                    style: AxoType.caption.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.bgEditor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.accentDefault, width: 2),
      ),
    );
  }
}

/// Tarjeta de ilustración 240×45, radio 12, `bgEditor`, con casilla/líneas.
class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.leading, required this.lines});

  final Widget leading;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SizedBox(
      width: 240,
      height: 45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.bgEditor,
          borderRadius: BorderRadius.circular(AxoRadii.lg),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AxoSpacing.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 3),
                  lines[i],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.width, this.height, this.dark);

  final double width;
  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? c.textTertiary : c.bgHover,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
