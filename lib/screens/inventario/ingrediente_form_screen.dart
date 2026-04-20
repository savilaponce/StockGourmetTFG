import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/ingrediente_service.dart';
import '../../services/plato_service.dart';
import '../../services/proveedor_service.dart';
import '../../utils/constants.dart';

class IngredienteFormScreen extends ConsumerStatefulWidget {
  final String? ingredienteId;

  const IngredienteFormScreen({super.key, this.ingredienteId});

  bool get isEditing => ingredienteId != null;

  @override
  ConsumerState<IngredienteFormScreen> createState() => _IngredienteFormScreenState();
}

class _IngredienteFormScreenState extends ConsumerState<IngredienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _stockMinCtrl = TextEditingController(text: '0');
  final _costeCtrl = TextEditingController(text: '0');
  final _notasCtrl = TextEditingController();

  String _categoria = 'otros';
  String _unidad = 'kg';
  String? _proveedorSeleccionado;
  DateTime? _fechaCaducidad;
  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadIngrediente();
    }
  }

  Future<void> _loadIngrediente() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(ingredienteServiceProvider);
      final ing = await service.getById(widget.ingredienteId!);
      _nombreCtrl.text = ing.nombre;
      _stockCtrl.text = ing.stockActual.toString();
      _stockMinCtrl.text = ing.stockMinimo.toString();
      _costeCtrl.text = ing.costePorUnidad.toString();
      _proveedorSeleccionado = ing.proveedor;
      _notasCtrl.text = ing.notas ?? '';
      _categoria = ing.categoria;
      _unidad = ing.unidad;
      _fechaCaducidad = ing.fechaCaducidad;
      _initialized = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando ingrediente: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final service = ref.read(ingredienteServiceProvider);
      final ingrediente = Ingrediente(
        nombre: _nombreCtrl.text.trim(),
        categoria: _categoria,
        stockActual: double.tryParse(_stockCtrl.text) ?? 0,
        stockMinimo: double.tryParse(_stockMinCtrl.text) ?? 0,
        unidad: _unidad,
        costePorUnidad: double.tryParse(_costeCtrl.text) ?? 0,
        proveedor: _proveedorSeleccionado,
        fechaCaducidad: _fechaCaducidad,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );

      if (widget.isEditing) {
        await service.update(widget.ingredienteId!, ingrediente);
      } else {
        await service.create(ingrediente);
      }

      // Invalidar caches
      ref.invalidate(ingredientesProvider);
      ref.invalidate(ingredientesPorCaducarProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Ingrediente actualizado'
                : 'Ingrediente creado'),
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaCaducidad ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('es', 'ES'),
    );
    if (date != null) {
      setState(() => _fechaCaducidad = date);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ingrediente?'),
        content: const Text(
          'Este ingrediente se desactivará. Los platos que lo usen mantendrán su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(ingredienteServiceProvider);
      await service.delete(widget.ingredienteId!);
      ref.invalidate(ingredientesProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proveedoresAsync = ref.watch(proveedoresProvider);

    if (widget.isEditing && _loading && !_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Ingrediente' : 'Nuevo Ingrediente'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del ingrediente *',
                  hintText: 'Ej: Tomate cherry',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Categoría y Unidad (en fila)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: AppConstants.categoriasIngredientes.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoria = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidad,
                      decoration: const InputDecoration(labelText: 'Unidad'),
                      items: AppConstants.unidades.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _unidad = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stock actual y mínimo
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Stock actual',
                        suffixText: _unidad,
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockMinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Stock mínimo',
                        suffixText: _unidad,
                        prefixIcon: const Icon(Icons.warning_amber),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Coste por unidad
              TextFormField(
                controller: _costeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Coste por $_unidad (€) *',
                  prefixIcon: const Icon(Icons.euro),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'El coste es obligatorio';
                  if (double.tryParse(v) == null) return 'Número no válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fecha de caducidad
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de caducidad',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _fechaCaducidad != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _fechaCaducidad = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _fechaCaducidad != null
                        ? '${_fechaCaducidad!.day.toString().padLeft(2, '0')}/'
                          '${_fechaCaducidad!.month.toString().padLeft(2, '0')}/'
                          '${_fechaCaducidad!.year}'
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: _fechaCaducidad != null
                          ? null
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Proveedor — Dropdown con lista de proveedores predefinidos
              proveedoresAsync.when(
                data: (proveedores) => DropdownButtonFormField<String>(
                  value: proveedores.any((p) => p.nombre == _proveedorSeleccionado)
                      ? _proveedorSeleccionado
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  hint: const Text('Seleccionar proveedor'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin proveedor', style: TextStyle(color: Colors.grey)),
                    ),
                    ...proveedores.map((p) => DropdownMenuItem(
                      value: p.nombre,
                      child: Text(p.nombre),
                    )),
                  ],
                  onChanged: (v) => setState(() => _proveedorSeleccionado = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => TextFormField(
                  initialValue: _proveedorSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                    hintText: 'Ej: Frutas García S.L.',
                  ),
                  onChanged: (v) => _proveedorSeleccionado = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
              const SizedBox(height: 16),

              // Notas
              TextFormField(
                controller: _notasCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Observaciones, instrucciones de almacenaje...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // Botón guardar
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
                  label: Text(widget.isEditing ? 'Guardar Cambios' : 'Crear Ingrediente'),
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    _costeCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }
}