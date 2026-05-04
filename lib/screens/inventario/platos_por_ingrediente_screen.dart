import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/ingrediente_service.dart';
import '../../services/plato_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';

// ============================================================
// "Platos que usan este ingrediente"
// Acceso por swipe desde inventario o desde el detalle.
// ============================================================
class PlatosPorIngredienteScreen extends ConsumerWidget {
  final String ingredienteId;

  const PlatosPorIngredienteScreen({
    super.key,
    required this.ingredienteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platosAsync = ref.watch(platosPorIngredienteProvider(ingredienteId));
    final ingredienteAsync = ref.watch(_ingredienteByIdProvider(ingredienteId));

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: ingredienteAsync.when(
          data: (i) => Text(i.nombre,
              style: const TextStyle(fontSize: 16)),
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Platos'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: platosAsync.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (platos) {
          if (platos.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant_outlined,
              title: 'Sin platos asociados',
              message: 'Este ingrediente no se usa en ningún plato actualmente.',
              actionLabel: 'Crear nuevo plato',
              onAction: () => context.push('/plato/nuevo'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: platos.length,
            itemBuilder: (_, i) => _PlatoTile(plato: platos[i]),
          );
        },
      ),
    );
  }
}

// Provider auxiliar para mostrar el nombre del ingrediente en la cabecera
final _ingredienteByIdProvider =
    FutureProvider.family<Ingrediente, String>((ref, id) async {
  final service = ref.read(ingredienteServiceProvider);
  return service.getById(id);
});

class _PlatoTile extends StatelessWidget {
  final Plato plato;
  const _PlatoTile({required this.plato});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SGColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_menu,
              color: SGColors.primary),
        ),
        title: Text(
          plato.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: plato.precioVenta != null && plato.precioVenta! > 0
            ? Text(Formatters.currency(plato.precioVenta!))
            : null,
        trailing: plato.margenPorcentual != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: plato.margenBueno
                      ? Colors.green.shade50
                      : plato.margenMedio
                          ? Colors.orange.shade50
                          : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${plato.margenPorcentual!.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: plato.margenBueno
                        ? Colors.green.shade700
                        : plato.margenMedio
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, color: SGColors.textHint),
        onTap: () => context.push('/plato/${plato.id}'),
      ),
    );
  }
}