import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/ingrediente_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';

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
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No hay ingredientes',
                        message:
                            'Empieza añadiendo tu primer ingrediente o escanea un albarán.',
                        actionLabel: 'Añadir ingrediente',
                        onAction: () =>
                            context.push('/ingrediente/nuevo'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _IngredienteCard(ingrediente: items[i]),
                      ),
                loading: () => const SkeletonList(count: 6),
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
class _IngredienteCard extends ConsumerWidget {
  final Ingrediente ingrediente;
  const _IngredienteCard({required this.ingrediente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Slidable(
      key: ValueKey(ingrediente.id),
      // Izquierda → ajustar stock
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) => _abrirAjustarStock(context, ref),
            backgroundColor: SGColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.tune,
            label: 'Ajustar',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      // Derecha → ver platos que lo usan
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) => context.push(
                '/ingrediente/${ingrediente.id}/platos'),
            backgroundColor: SGColors.orange,
            foregroundColor: Colors.white,
            icon: Icons.restaurant_menu,
            label: 'Platos',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: Container(
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
          trailing: const Icon(Icons.swipe_outlined,
              color: SGColors.textHint, size: 20),
          onTap: () =>
              context.push('/ingrediente/editar/${ingrediente.id}'),
        ),
      ),
    );
  }

  void _abrirAjustarStock(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AjustarStockSheet(ingrediente: ingrediente),
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

// ============================================================
// BOTTOM SHEET: AJUSTAR STOCK
// ============================================================
class _AjustarStockSheet extends ConsumerStatefulWidget {
  final Ingrediente ingrediente;
  const _AjustarStockSheet({required this.ingrediente});

  @override
  ConsumerState<_AjustarStockSheet> createState() =>
      _AjustarStockSheetState();
}

class _AjustarStockSheetState extends ConsumerState<_AjustarStockSheet> {
  final _cantidadCtrl = TextEditingController();
  String _tipo = 'entrada'; // entrada / salida / merma / ajuste
  bool _guardando = false;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    super.dispose();
  }

  double get _cantidad =>
      double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _delta {
    if (_cantidad <= 0) return 0;
    return _tipo == 'entrada' ? _cantidad : -_cantidad;
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica una cantidad válida')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(ingredienteServiceProvider).ajustarStock(
            widget.ingrediente.id!,
            _delta,
            motivo: _tipo,
          );
      if (!mounted) return;
      ref.invalidate(ingredientesProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock ${_tipo == 'entrada' ? 'sumado' : 'restado'}: '
            '${_cantidad.toStringAsFixed(2)} ${widget.ingrediente.unidad}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingrediente;
    final stockResultante =
        (ing.stockActual + _delta).clamp(0.0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Ajustar stock',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            ing.nombre,
            style: const TextStyle(
                fontSize: 14, color: SGColors.textSecondary),
          ),
          const SizedBox(height: 16),
          // Selector de tipo
          Wrap(
            spacing: 6,
            children: [
              _ChipTipo(
                label: 'Entrada',
                icon: Icons.add,
                color: Colors.green,
                selected: _tipo == 'entrada',
                onTap: () => setState(() => _tipo = 'entrada'),
              ),
              _ChipTipo(
                label: 'Salida',
                icon: Icons.remove,
                color: Colors.blue,
                selected: _tipo == 'salida',
                onTap: () => setState(() => _tipo = 'salida'),
              ),
              _ChipTipo(
                label: 'Merma',
                icon: Icons.delete_outline,
                color: Colors.red,
                selected: _tipo == 'merma',
                onTap: () => setState(() => _tipo = 'merma'),
              ),
              _ChipTipo(
                label: 'Ajuste',
                icon: Icons.tune,
                color: SGColors.primary,
                selected: _tipo == 'ajuste',
                onTap: () => setState(() => _tipo = 'ajuste'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Input cantidad
          TextField(
            controller: _cantidadCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: ing.unidad,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Resumen
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SGColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock actual',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${ing.stockActual} ${ing.unidad}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward,
                    color: SGColors.textHint, size: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Stock resultante',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${stockResultante.toStringAsFixed(2)} ${ing.unidad}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _delta > 0
                              ? Colors.green.shade700
                              : _delta < 0
                                  ? Colors.red.shade700
                                  : SGColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChipTipo extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChipTipo({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon,
          size: 16,
          color: selected ? Colors.white : color),
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          )),
      backgroundColor: selected ? color : color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}