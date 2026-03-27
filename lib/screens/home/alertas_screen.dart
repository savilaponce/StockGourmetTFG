import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/ingrediente_service.dart';
import '../../utils/formatters.dart';

class AlertasScreen extends ConsumerWidget {
  const AlertasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caducidadAsync = ref.watch(ingredientesPorCaducarProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Alertas y Notificaciones'),
      ),
      body: RefreshIndicator(
        color: SGColors.primary,
        onRefresh: () async {
          ref.invalidate(ingredientesPorCaducarProvider);
        },
        child: caducidadAsync.when(
          data: (items) => items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: SGColors.textHint),
                      SizedBox(height: 16),
                      Text('Sin alertas',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: SGColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Todo tu inventario está en orden',
                          style: TextStyle(color: SGColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _AlertaTile(ingrediente: items[i]),
                ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: SGColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _AlertaTile extends StatelessWidget {
  final Ingrediente ingrediente;
  const _AlertaTile({required this.ingrediente});

  @override
  Widget build(BuildContext context) {
    final dias = ingrediente.diasRestantes ?? 0;
    final caducado = dias < 0;
    final critico = dias <= 3 && !caducado;

    final Color accentColor = caducado
        ? SGColors.red
        : critico
            ? SGColors.orange
            : const Color(0xFFEAB308);

    final String tipo = caducado
        ? 'Caducado'
        : critico
            ? 'Próximo a Caducar'
            : 'Atención';

    final IconData icono = caducado
        ? Icons.error_outline
        : critico
            ? Icons.warning_amber_rounded
            : Icons.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tipo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        )),
                    const Spacer(),
                    Text(Formatters.date(ingrediente.fechaCaducidad),
                        style: const TextStyle(
                            fontSize: 11, color: SGColors.textHint)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  caducado
                      ? "'${ingrediente.nombre}' caducó hace ${dias.abs()} días"
                      : "'${ingrediente.nombre}' caduca en $dias días",
                  style: const TextStyle(
                      fontSize: 14, color: SGColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: SGColors.textHint, size: 20),
        ],
      ),
    );
  }
}
