import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/plato_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class PlatoDetailScreen extends ConsumerStatefulWidget {
  final String platoId;
  const PlatoDetailScreen({super.key, required this.platoId});

  @override
  ConsumerState<PlatoDetailScreen> createState() => _PlatoDetailScreenState();
}

class _PlatoDetailScreenState extends ConsumerState<PlatoDetailScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final service = ref.read(platoServiceProvider);
    final plato = await service.getById(widget.platoId);
    final costes = await service.getConCostes(widget.platoId);
    return {'plato': plato, 'costes': costes};
  }

  @override
  Widget build(BuildContext context) {
    final ingredientesAsync = ref.watch(platoIngredientesProvider(widget.platoId));
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final plato = data?['plato'] as Plato?;
        final costes = data?['costes'] as Map<String, dynamic>?;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del Plato'),
            actions: [
              if (plato != null)
                profileAsync.when(
                  data: (profile) => (profile?.canEdit ?? false)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => context.push('/plato/editar/${widget.platoId}'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar',
                              onPressed: () => _confirmDelete(context),
                            ),
                          ],
                        )
                      : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(child: Text('Error: ${snapshot.error}'))
                  : plato == null || costes == null
                      ? const Center(child: Text('Plato no encontrado'))
                      : _buildBody(context, plato, costes, ingredientesAsync, theme),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    Plato plato,
    Map<String, dynamic> costes,
    AsyncValue<List<PlatoIngrediente>> ingredientesAsync,
    ThemeData theme,
  ) {
    final costeTotal = (costes['coste_total'] as num?)?.toDouble() ?? 0;
    final precioVenta = (costes['precio_venta'] as num?)?.toDouble();
    final beneficio = (costes['beneficio_bruto'] as num?)?.toDouble();
    final margen = (costes['margen_porcentual'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Text(
          plato.nombre,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppConstants.categoriasPlatos[plato.categoria] ??
                    plato.categoria,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        if (plato.descripcion != null && plato.descripcion!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(plato.descripcion!,
              style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        ],
        const SizedBox(height: 24),

        // === RESUMEN FINANCIERO ===
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.08),
                theme.colorScheme.primary.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen Financiero',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Coste',
                      value: Formatters.currency(costeTotal),
                      icon: Icons.payments_outlined,
                      color: Colors.grey[700]!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'PVP',
                      value: Formatters.currency(precioVenta),
                      icon: Icons.sell_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Beneficio',
                      value: Formatters.currency(beneficio),
                      icon: Icons.trending_up,
                      color: (beneficio ?? 0) >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Margen',
                      value: Formatters.percentage(margen),
                      icon: Icons.pie_chart_outline,
                      color: _margenColor(margen ?? 0),
                    ),
                  ),
                ],
              ),
              if (margen != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (margen / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation(_margenColor(margen)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === INGREDIENTES ===
        Text(
          'Ingredientes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ingredientesAsync.when(
          data: (ingredientes) => ingredientes.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay ingredientes asignados'),
                  ),
                )
              : Column(
                  children: [
                    ...ingredientes.map((pi) => _IngredienteRow(pi: pi)),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        Text(
                          Formatters.currency(costeTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Color _margenColor(double margen) {
    if (margen >= 65) return const Color(0xFF2D6A4F);
    if (margen >= 40) return Colors.orange;
    return Colors.red;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar plato?'),
        content: const Text('Este plato se desactivará.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(platoServiceProvider).delete(widget.platoId);
      ref.invalidate(platosProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) context.pop();
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _IngredienteRow extends StatelessWidget {
  final PlatoIngrediente pi;
  const _IngredienteRow({required this.pi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              pi.nombreIngrediente ?? 'Ingrediente',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formatters.cantidad(pi.cantidad, pi.unidadIngrediente ?? 'kg'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formatters.currency(pi.costeLinea),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}