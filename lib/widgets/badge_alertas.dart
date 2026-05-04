import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../services/alertas_service.dart';

/// Envuelve un widget (icono típicamente) y muestra un badge encima
/// con el número de alertas activas. Color rojo si hay críticas,
/// naranja si hay altas, gris en caso contrario.
///
/// Uso:
///   BadgeAlertas(
///     child: Icon(Icons.notifications_outlined),
///   )
class BadgeAlertas extends ConsumerWidget {
  final Widget child;

  const BadgeAlertas({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenAlertasProvider);

    final resumen = resumenAsync.value;
    if (resumen == null || resumen.total == 0) return child;

    final color = resumen.criticas > 0
        ? SGColors.red
        : resumen.altas > 0
            ? SGColors.orange
            : Colors.grey;

    final texto =
        resumen.total > 99 ? '99+' : resumen.total.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: texto.length > 1 ? 6 : 5,
              vertical: 2,
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}