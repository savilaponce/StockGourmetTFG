import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/ingrediente_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

final categoriaFiltroProvider = StateProvider<String?>((ref) => null);

class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriaFiltro = ref.watch(categoriaFiltroProvider);
    final ingredientesAsync = ref.watch(ingredientesProvider(categoriaFiltro));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: SGColors.textSecondary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search, color: SGColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros horizontales
          Container(
            color: SGColors.surface,
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterPill(
                  label: 'Todos',
                  selected: categoriaFiltro == null,
                  onTap: () =>
                      ref.read(categoriaFiltroProvider.notifier).state = null,
                ),
                ...AppConstants.categoriasIngredientes.entries.map((e) =>
                    _FilterPill(
                      label: e.value,
                      selected: categoriaFiltro == e.key,
                      onTap: () =>
                          ref.read(categoriaFiltroProvider.notifier).state =
                              e.key,
                    )),
              ],
            ),
          ),

          // Lista de ingredientes
          Expanded(
            child: RefreshIndicator(
              color: SGColors.primary,
              onRefresh: () async {
                ref.invalidate(ingredientesProvider(categoriaFiltro));
              },
              child: ingredientesAsync.when(
                data: (items) => items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 64, color: SGColors.textHint),
                            const SizedBox(height: 16),
                            const Text('No hay ingredientes',
                                style: TextStyle(
                                    color: SGColors.textSecondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  context.push('/ingrediente/nuevo'),
                              icon: const Icon(Icons.add,
                                  color: SGColors.primary),
                              label: const Text('Añadir el primero',
                                  style: TextStyle(color: SGColors.primary)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _IngredienteCard(ingrediente: items[i]),
                      ),
                loading: () => const Center(
                    child: CircularProgressIndicator(color: SGColors.primary)),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: profileAsync.when(
        data: (profile) => (profile?.canEdit ?? false)
            ? FloatingActionButton(
                onPressed: () => context.push('/ingrediente/nuevo'),
                backgroundColor: SGColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                child: const Icon(Icons.add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? SGColors.primary : SGColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? SGColors.primary : SGColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : SGColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INGREDIENTE CARD — Estilo mockup: icono circular, nombre,
// stock, valor, fecha caducidad coloreada
// ============================================================
class _IngredienteCard extends StatelessWidget {
  final Ingrediente ingrediente;
  const _IngredienteCard({required this.ingrediente});

  @override
  Widget build(BuildContext context) {
    final expText = ingrediente.fechaCaducidad != null
        ? 'Exp: ${Formatters.date(ingrediente.fechaCaducidad)}'
        : 'Exp: N/A';

    final dias = ingrediente.diasRestantes;
    Color expColor = SGColors.textSecondary;
    if (dias != null) {
      if (dias < 0) {
        expColor = SGColors.red;
      } else if (dias <= 3) {
        expColor = SGColors.red;
      } else if (dias <= 7) {
        expColor = SGColors.orange;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _categoriaColor(ingrediente.categoria),
          child: Text(
            AppConstants.categoriasIngredientes[ingrediente.categoria]
                    ?.substring(0, 2) ??
                '📦',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ingrediente.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: SGColors.textPrimary),
              ),
            ),
            Text(expText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: expColor)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                'Stock: ${Formatters.cantidad(ingrediente.stockActual, ingrediente.unidad)}',
                style: const TextStyle(
                    fontSize: 13, color: SGColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Text(
                'Valor: ${Formatters.currency(ingrediente.stockActual * ingrediente.costePorUnidad)}',
                style: const TextStyle(
                    fontSize: 13, color: SGColors.textSecondary),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.expand_more,
            color: SGColors.textHint, size: 22),
        onTap: () => context.push('/ingrediente/editar/${ingrediente.id}'),
      ),
    );
  }

  Color _categoriaColor(String cat) => switch (cat) {
        'carnes' => const Color(0xFFFFCDD2),
        'pescados' => const Color(0xFFBBDEFB),
        'verduras' => const Color(0xFFC8E6C9),
        'frutas' => const Color(0xFFFFE0B2),
        'lacteos' => const Color(0xFFFFF9C4),
        'especias' => const Color(0xFFFFCCBC),
        'aceites' => const Color(0xFFF0F4C3),
        'bebidas' => const Color(0xFFB3E5FC),
        'congelados' => const Color(0xFFB2EBF2),
        _ => const Color(0xFFE0E0E0),
      };
}
