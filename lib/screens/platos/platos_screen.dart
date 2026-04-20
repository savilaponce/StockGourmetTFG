import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/plato_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

final platoCategoriaFiltroProvider = StateProvider<String?>((ref) => null);

class PlatosScreen extends ConsumerWidget {
  const PlatosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriaFiltro = ref.watch(platoCategoriaFiltroProvider);
    final platosAsync = ref.watch(platosProvider(categoriaFiltro));
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Platos y Recetas')),
      body: Column(
        children: [
          // Filtros de categoría
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: categoriaFiltro == null,
                  onTap: () =>
                      ref.read(platoCategoriaFiltroProvider.notifier).state = null,
                ),
                ...AppConstants.categoriasPlatos.entries.map((e) => _FilterChip(
                      label: e.value,
                      selected: categoriaFiltro == e.key,
                      onTap: () =>
                          ref.read(platoCategoriaFiltroProvider.notifier).state = e.key,
                    )),
              ],
            ),
          ),

          // Lista de platos
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(platosProvider(categoriaFiltro));
              },
              child: platosAsync.when(
                data: (platos) => platos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No hay platos aún',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 16)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => context.push('/plato/nuevo'),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear el primero'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: platos.length,
                        itemBuilder: (context, i) =>
                            _PlatoCard(plato: platos[i]),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: profileAsync.when(
        data: (profile) => (profile?.canEdit ?? false)
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/plato/nuevo'),
                icon: const Icon(Icons.add),
                label: const Text('Plato'),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 13)),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      ),
    );
  }
}

// ============================================================
// PLATO CARD — Tarjeta con indicadores visuales de coste/margen
// ============================================================
class _PlatoCard extends StatelessWidget {
  final Plato plato;
  const _PlatoCard({required this.plato});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/plato/${plato.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nombre + categoría
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plato.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppConstants.categoriasPlatos[plato.categoria] ?? plato.categoria,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              if (plato.descripcion != null && plato.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plato.descripcion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],

              const SizedBox(height: 12),

              // Indicadores de coste/beneficio
              Row(
                children: [
                  // Coste
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: 'Coste',
                    value: Formatters.currency(plato.costeTotal),
                    color: Colors.grey[700]!,
                  ),
                  const SizedBox(width: 8),

                  // Precio venta
                  if (plato.precioVenta != null) ...[
                    _InfoChip(
                      icon: Icons.sell_outlined,
                      label: 'PVP',
                      value: Formatters.currency(plato.precioVenta),
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Margen
                  if (plato.margenPorcentual != null) ...[
                    _InfoChip(
                      icon: Icons.trending_up,
                      label: 'Margen',
                      value: Formatters.percentage(plato.margenPorcentual),
                      color: _margenColor(plato.margenPorcentual!),
                    ),
                  ],

                  const Spacer(),

                  // Número de ingredientes
                  Text(
                    '${plato.numIngredientes ?? 0} ing.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),

              // Barra de margen visual
              if (plato.margenPorcentual != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (plato.margenPorcentual! / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      _margenColor(plato.margenPorcentual!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _margenColor(double margen) {
    if (margen >= 65) return const Color(0xFF2D6A4F);
    if (margen >= 40) return Colors.orange;
    return Colors.red;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}