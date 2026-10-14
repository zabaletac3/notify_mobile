import 'package:flutter/material.dart';

import '../tokens.dart';

/// Barra de esqueleto de carga (tablero «Android — Cargando (skeletons)»): relleno `bgHover`
/// (medido `#e6dfd3` en claro) y radio 6.
class AxoSkeleton extends StatelessWidget {
  const AxoSkeleton({super.key, required this.width, this.height = 10});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.bgHover,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Esqueleto de una nota (tablero «Android — Cargando (skeletons)», «Skeleton — nota»): 92 de alto,
/// relleno [12,14] y hueco 8, con cuatro barras (197×14, 348×10, 251×10, 70×10).
class AxoNoteSkeleton extends StatelessWidget {
  const AxoNoteSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AxoSizes.noteSkeleton,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AxoSkeleton(width: 197, height: 14),
          SizedBox(height: AxoSpacing.sm),
          AxoSkeleton(width: 348),
          SizedBox(height: AxoSpacing.sm),
          AxoSkeleton(width: 251),
          SizedBox(height: AxoSpacing.sm),
          AxoSkeleton(width: 70),
        ],
      ),
    );
  }
}
