import 'package:flutter/material.dart';

/// Skeleton con animación de shimmer suave.
///
/// Componentes disponibles:
/// - [SkeletonBox]: rectángulo sencillo (puedes componer formas custom).
/// - [SkeletonCard]: tarjeta tipo "fila de lista" con avatar + 2 líneas.
/// - [SkeletonList]: lista de SkeletonCard.
///
/// Sin dependencias externas; usa un AnimationController interno.
// ============================================================
// EFFECT WRAPPER
// ============================================================
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Gradiente animado moviéndose de izquierda a derecha
            final dx = -1.0 + 2.0 * _ctrl.value;
            return LinearGradient(
              begin: Alignment(dx - 0.6, 0),
              end: Alignment(dx + 0.6, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================
// COMPONENTES
// ============================================================

/// Rectángulo gris animado para componer skeletons custom.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Tarjeta tipo "fila de lista" con icono + 2 líneas de texto.
/// Para listas de ingredientes, platos, etc.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 160, height: 14),
                const SizedBox(height: 8),
                SkeletonBox(width: 100, height: 11),
              ],
            ),
          ),
          const SkeletonBox(width: 40, height: 12),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonCard(),
    );
  }
}