import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/pedido_service.dart';
import '../../services/ingrediente_service.dart';
import '../../services/proveedor_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class PedidoFormScreen extends ConsumerStatefulWidget {
  const PedidoFormScreen({super.key});

  @override
  ConsumerState<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends ConsumerState<PedidoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  String? _proveedorSeleccionado;
  DateTime? _fechaEntrega;
  bool _loading = false;

  // Líneas del pedido
  final List<_LineaTemp> _lineas = [];

  double get _costeTotal => _lineas.fold(0, (sum, l) => sum + l.cantidad * l.precioUnitario);

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorSeleccionado == null || _proveedorSeleccionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un proveedor'), backgroundColor: SGColors.orange),
      );
      return;
    }
    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un producto al pedido'), backgroundColor: SGColors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(pedidoServiceProvider);

      // 1. Crear pedido
      final pedido = await service.create(Pedido(
        proveedor: _proveedorSeleccionado!,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        fechaEntregaEstimada: _fechaEntrega,
      ));

      // 2. Añadir líneas
      for (final linea in _lineas) {
        await service.addLinea(PedidoLinea(
          pedidoId: pedido.id!,
          ingredienteId: linea.ingredienteId,
          nombreProducto: linea.nombre,
          cantidad: linea.cantidad,
          unidad: linea.unidad,
          precioUnitario: linea.precioUnitario,
        ));
      }

      // 3. Recalcular coste total
      await service.recalcularCosteTotal(pedido.id!);

      ref.invalidate(pedidosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido creado'), backgroundColor: SGColors.primary),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: SGColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addLinea() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddLineaSheet(
        ref: ref,
        onAdd: (linea) {
          setState(() => _lineas.add(linea));
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (date != null) setState(() => _fechaEntrega = date);
  }

  @override
  Widget build(BuildContext context) {
    final proveedoresAsync = ref.watch(proveedoresProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Nuevo Pedido'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Proveedor — Dropdown con lista de proveedores predefinidos
              proveedoresAsync.when(
                data: (proveedores) => proveedores.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No hay proveedores creados',
                              style: TextStyle(color: SGColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => context.push('/proveedores'),
                            icon: const Icon(Icons.add, color: SGColors.primary),
                            label: const Text('Crear proveedor primero', style: TextStyle(color: SGColors.primary)),
                          ),
                        ],
                      )
                    : DropdownButtonFormField<String>(
                        value: _proveedorSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Proveedor *',
                          prefixIcon: Icon(Icons.business_outlined, color: SGColors.textHint),
                        ),
                        hint: const Text('Seleccionar proveedor'),
                        isExpanded: true,
                        items: proveedores.map((p) => DropdownMenuItem(
                          value: p.nombre,
                          child: Text(p.nombre),
                        )).toList(),
                        onChanged: (v) => setState(() => _proveedorSeleccionado = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un proveedor' : null,
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error cargando proveedores'),
              ),
              const SizedBox(height: 14),

              // Fecha entrega estimada
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de entrega estimada',
                    prefixIcon: const Icon(Icons.calendar_today, color: SGColors.textHint),
                    suffixIcon: _fechaEntrega != null
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _fechaEntrega = null))
                        : null,
                  ),
                  child: Text(
                    _fechaEntrega != null ? Formatters.date(_fechaEntrega) : 'Seleccionar fecha',
                    style: TextStyle(color: _fechaEntrega != null ? SGColors.textPrimary : SGColors.textHint),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Notas
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Observaciones del pedido...',
                  prefixIcon: Icon(Icons.notes, color: SGColors.textHint),
                ),
              ),
              const SizedBox(height: 24),

              // Líneas del pedido
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Productos del pedido',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
                  TextButton.icon(
                    onPressed: _addLinea,
                    icon: const Icon(Icons.add, size: 18, color: SGColors.primary),
                    label: const Text('Añadir', style: TextStyle(color: SGColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_lineas.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: SGColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 40, color: SGColors.textHint),
                        const SizedBox(height: 8),
                        Text('Añade productos al pedido', style: TextStyle(color: SGColors.textHint)),
                      ],
                    ),
                  ),
                )
              else
                ..._lineas.asMap().entries.map((entry) {
                  final i = entry.key;
                  final linea = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SGColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(linea.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                '${Formatters.cantidad(linea.cantidad, linea.unidad)} × ${Formatters.currency(linea.precioUnitario)} = ${Formatters.currency(linea.cantidad * linea.precioUnitario)}',
                                style: const TextStyle(fontSize: 12, color: SGColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: SGColors.textHint),
                          onPressed: () => setState(() => _lineas.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),

              // Coste total
              if (_lineas.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SGColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Coste total estimado',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SGColors.textPrimary)),
                      Text(Formatters.currency(_costeTotal),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SGColors.primary)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _guardar,
                  icon: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Crear Pedido'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }
}

// ============================================================
// Línea temporal (antes de guardar)
// ============================================================
class _LineaTemp {
  final String? ingredienteId;
  final String nombre;
  final double cantidad;
  final String unidad;
  final double precioUnitario;

  _LineaTemp({
    this.ingredienteId,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.precioUnitario,
  });
}

// ============================================================
// Bottom sheet para añadir línea
// ============================================================
class _AddLineaSheet extends StatefulWidget {
  final WidgetRef ref;
  final Function(_LineaTemp) onAdd;
  const _AddLineaSheet({required this.ref, required this.onAdd});

  @override
  State<_AddLineaSheet> createState() => _AddLineaSheetState();
}

class _AddLineaSheetState extends State<_AddLineaSheet> {
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController(text: '0');
  String _unidad = 'kg';
  Ingrediente? _ingredienteVinculado;

  @override
  Widget build(BuildContext context) {
    final ingredientesAsync = widget.ref.watch(ingredientesProvider(null));

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: SGColors.textHint, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          const Text('Añadir producto al pedido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Puedes vincular a un ingrediente existente o crear uno libre.',
              style: TextStyle(fontSize: 13, color: SGColors.textSecondary)),
          const SizedBox(height: 16),

          // Vincular ingrediente (opcional)
          ingredientesAsync.when(
            data: (ingredientes) => DropdownButtonFormField<Ingrediente>(
              decoration: const InputDecoration(
                labelText: 'Vincular a ingrediente (opcional)',
                prefixIcon: Icon(Icons.link, color: SGColors.textHint),
              ),
              hint: const Text('Sin vincular'),
              isExpanded: true,
              items: ingredientes.map((ing) => DropdownMenuItem(
                value: ing,
                child: Text('${ing.nombre} (${ing.unidad})'),
              )).toList(),
              onChanged: (ing) {
                setState(() {
                  _ingredienteVinculado = ing;
                  if (ing != null) {
                    _nombreCtrl.text = ing.nombre;
                    _unidad = ing.unidad;
                    _precioCtrl.text = ing.costePorUnidad.toString();
                  }
                });
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 14),

          // Nombre
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del producto *', prefixIcon: Icon(Icons.label_outlined, color: SGColors.textHint)),
          ),
          const SizedBox(height: 14),

          // Cantidad + Unidad + Precio
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cantidadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unidad,
                  decoration: const InputDecoration(labelText: 'Ud.'),
                  items: AppConstants.unidades.entries.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.key))).toList(),
                  onChanged: (v) => setState(() => _unidad = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _precioCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(labelText: 'Precio/ud (€)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final nombre = _nombreCtrl.text.trim();
                final cant = double.tryParse(_cantidadCtrl.text) ?? 0;
                final precio = double.tryParse(_precioCtrl.text) ?? 0;
                if (nombre.isEmpty || cant <= 0) return;

                widget.onAdd(_LineaTemp(
                  ingredienteId: _ingredienteVinculado?.id,
                  nombre: nombre,
                  cantidad: cant,
                  unidad: _unidad,
                  precioUnitario: precio,
                ));
                Navigator.pop(context);
              },
              child: const Text('Añadir al pedido'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }
}