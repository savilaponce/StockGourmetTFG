import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/ingrediente_service.dart';
import '../../services/plato_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class PlatoFormScreen extends ConsumerStatefulWidget {
  final String? platoId;
  const PlatoFormScreen({super.key, this.platoId});
  bool get isEditing => platoId != null;

  @override
  ConsumerState<PlatoFormScreen> createState() => _PlatoFormScreenState();
}

class _PlatoFormScreenState extends ConsumerState<PlatoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();

  String _categoria = 'principal';
  bool _loading = false;
  bool _initialized = false;

  // Ingredientes seleccionados para el plato
  // Map<ingredienteId, {ingrediente: Ingrediente, cantidad: double}>
  final Map<String, _IngredienteSeleccion> _ingredientesSeleccionados = {};

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadPlato();
  }

  Future<void> _loadPlato() async {
    setState(() => _loading = true);
    try {
      final platoService = ref.read(platoServiceProvider);
      final plato = await platoService.getById(widget.platoId!);
      final ingredientes = await platoService.getIngredientes(widget.platoId!);

      _nombreCtrl.text = plato.nombre;
      _descripcionCtrl.text = plato.descripcion ?? '';
      _precioVentaCtrl.text = plato.precioVenta?.toString() ?? '';
      _categoria = plato.categoria;

      // Cargar ingredientes asignados
      for (final pi in ingredientes) {
        if (pi.nombreIngrediente != null) {
          _ingredientesSeleccionados[pi.ingredienteId] = _IngredienteSeleccion(
            ingrediente: Ingrediente(
              id: pi.ingredienteId,
              nombre: pi.nombreIngrediente!,
              unidad: pi.unidadIngrediente ?? 'kg',
              costePorUnidad: pi.costeUnitario ?? 0,
            ),
            cantidad: pi.cantidad,
          );
        }
      }

      _initialized = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando plato: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Coste total calculado en vivo
  double get _costeTotal {
    double total = 0;
    for (final sel in _ingredientesSeleccionados.values) {
      total += sel.cantidad * sel.ingrediente.costePorUnidad;
    }
    return total;
  }

  /// Beneficio y margen calculados en vivo
  double? get _beneficio {
    final pv = double.tryParse(_precioVentaCtrl.text);
    if (pv == null) return null;
    return pv - _costeTotal;
  }

  double? get _margen {
    final pv = double.tryParse(_precioVentaCtrl.text);
    if (pv == null || pv <= 0) return null;
    return ((_beneficio!) / pv) * 100;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final platoService = ref.read(platoServiceProvider);

      final plato = Plato(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        categoria: _categoria,
        precioVenta: double.tryParse(_precioVentaCtrl.text),
      );

      String platoId;
      if (widget.isEditing) {
        await platoService.update(widget.platoId!, plato);
        platoId = widget.platoId!;
      } else {
        final created = await platoService.create(plato);
        platoId = created.id!;
      }

      // Guardar ingredientes del plato
      final platoIngredientes = _ingredientesSeleccionados.entries
          .map((e) => PlatoIngrediente(
                platoId: platoId,
                ingredienteId: e.key,
                cantidad: e.value.cantidad,
              ))
          .toList();

      await platoService.replaceIngredientes(platoId, platoIngredientes);

      // Invalidar caches
      ref.invalidate(platosProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Plato actualizado' : 'Plato creado'),
            backgroundColor: const Color(0xFF2D6A4F),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Abrir diálogo para buscar y añadir un ingrediente
  Future<void> _addIngrediente() async {
    final result = await showModalBottomSheet<_IngredienteSeleccion>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IngredienteSelectorSheet(
        alreadySelected: _ingredientesSeleccionados.keys.toSet(),
      ),
    );

    if (result != null) {
      setState(() {
        _ingredientesSeleccionados[result.ingrediente.id!] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isEditing && _loading && !_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Plato' : 'Nuevo Plato'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === INFO BÁSICA ===
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del plato *',
                  hintText: 'Ej: Risotto de setas con trufa',
                  prefixIcon: Icon(Icons.restaurant_menu),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nombre obligatorio' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: AppConstants.categoriasPlatos.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Breve descripción del plato...',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _precioVentaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Precio de venta (€)',
                  prefixIcon: Icon(Icons.euro),
                ),
                onChanged: (_) => setState(() {}), // Recalcular indicadores
              ),
              const SizedBox(height: 24),

              // === INGREDIENTES ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingredientes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addIngrediente,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_ingredientesSeleccionados.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Añade ingredientes al plato',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              else
                ...(_ingredientesSeleccionados.entries.map((entry) {
                  final sel = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(sel.ingrediente.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${Formatters.cantidad(sel.cantidad, sel.ingrediente.unidad)}'
                        ' × ${Formatters.currency(sel.ingrediente.costePorUnidad)}'
                        ' = ${Formatters.currency(sel.cantidad * sel.ingrediente.costePorUnidad)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _ingredientesSeleccionados.remove(entry.key);
                          });
                        },
                      ),
                    ),
                  );
                })),

              const SizedBox(height: 24),

              // === RESUMEN DE COSTES (en vivo) ===
              if (_ingredientesSeleccionados.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Coste total',
                        value: Formatters.currency(_costeTotal),
                        bold: true,
                      ),
                      if (_beneficio != null) ...[
                        const Divider(height: 20),
                        _SummaryRow(
                          label: 'Precio de venta',
                          value: Formatters.currency(
                              double.tryParse(_precioVentaCtrl.text)),
                        ),
                        const SizedBox(height: 4),
                        _SummaryRow(
                          label: 'Beneficio bruto',
                          value: Formatters.currency(_beneficio),
                          valueColor: _beneficio! >= 0 ? Colors.green : Colors.red,
                          bold: true,
                        ),
                        const SizedBox(height: 4),
                        _SummaryRow(
                          label: 'Margen',
                          value: Formatters.percentage(_margen),
                          valueColor: _margenColor(),
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        // Barra visual
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ((_margen ?? 0) / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(_margenColor()),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _margenRecomendacion(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _margenColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // === BOTÓN GUARDAR ===
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label:
                      Text(widget.isEditing ? 'Guardar Cambios' : 'Crear Plato'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _margenColor() {
    final m = _margen ?? 0;
    if (m >= 65) return const Color(0xFF2D6A4F);
    if (m >= 40) return Colors.orange;
    return Colors.red;
  }

  String _margenRecomendacion() {
    final m = _margen ?? 0;
    if (m >= 70) return '✅ Excelente margen';
    if (m >= 60) return '👍 Buen margen';
    if (m >= 40) return '⚠️ Margen ajustado — considera subir precio';
    return '🔴 Margen bajo — revisa costes o precio';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioVentaCtrl.dispose();
    super.dispose();
  }
}

// ============================================================
// Helper class para ingrediente seleccionado
// ============================================================
class _IngredienteSeleccion {
  final Ingrediente ingrediente;
  double cantidad;

  _IngredienteSeleccion({required this.ingrediente, required this.cantidad});
}

// ============================================================
// SUMMARY ROW — Fila del resumen de costes
// ============================================================
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            )),
      ],
    );
  }
}

// ============================================================
// INGREDIENTE SELECTOR BOTTOM SHEET
// Busca ingredientes del restaurante y permite elegir cantidad
// ============================================================
class _IngredienteSelectorSheet extends ConsumerStatefulWidget {
  final Set<String> alreadySelected;
  const _IngredienteSelectorSheet({required this.alreadySelected});

  @override
  ConsumerState<_IngredienteSelectorSheet> createState() =>
      _IngredienteSelectorSheetState();
}

class _IngredienteSelectorSheetState
    extends ConsumerState<_IngredienteSelectorSheet> {
  String _search = '';
  Ingrediente? _selectedIngrediente;
  final _cantidadCtrl = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    final ingredientesAsync = ref.watch(ingredientesProvider(null));
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Añadir Ingrediente',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),

            // Si ya seleccionó uno → mostrar selector de cantidad
            if (_selectedIngrediente != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: Color(0xFF2D6A4F)),
                        title: Text(_selectedIngrediente!.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${Formatters.currency(_selectedIngrediente!.costePorUnidad)} / ${_selectedIngrediente!.unidad}'),
                        trailing: TextButton(
                          onPressed: () =>
                              setState(() => _selectedIngrediente = null),
                          child: const Text('Cambiar'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cantidadCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText:
                            'Cantidad (${_selectedIngrediente!.unidad})',
                        prefixIcon: const Icon(Icons.scale),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final cant = double.tryParse(_cantidadCtrl.text);
                          if (cant == null || cant <= 0) return;
                          Navigator.pop(
                            context,
                            _IngredienteSeleccion(
                              ingrediente: _selectedIngrediente!,
                              cantidad: cant,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Añadir al plato'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Búsqueda
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar ingrediente...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(height: 8),

              // Lista de ingredientes
              Expanded(
                child: ingredientesAsync.when(
                  data: (items) {
                    final filtered = items
                        .where((i) =>
                            !widget.alreadySelected.contains(i.id) &&
                            i.nombre.toLowerCase().contains(_search))
                        .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text('No se encontraron ingredientes',
                            style: TextStyle(color: Colors.grey[500])),
                      );
                    }

                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final ing = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[100],
                            child: Text(
                              AppConstants.categoriasIngredientes[ing.categoria]
                                      ?.substring(0, 2) ??
                                  '📦',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          title: Text(ing.nombre),
                          subtitle: Text(
                            '${Formatters.currency(ing.costePorUnidad)}/${ing.unidad}'
                            ' · Stock: ${Formatters.cantidad(ing.stockActual, ing.unidad)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () =>
                              setState(() => _selectedIngrediente = ing),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    super.dispose();
  }
}
