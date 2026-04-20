import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/proveedor_service.dart';

class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedoresAsync = ref.watch(proveedoresProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Proveedores'),
      ),
      body: RefreshIndicator(
        color: SGColors.primary,
        onRefresh: () async => ref.invalidate(proveedoresProvider),
        child: proveedoresAsync.when(
          data: (proveedores) => proveedores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business_outlined, size: 64, color: SGColors.textHint),
                      const SizedBox(height: 16),
                      const Text('No hay proveedores',
                          style: TextStyle(color: SGColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _mostrarFormulario(context, ref),
                        icon: const Icon(Icons.add, color: SGColors.primary),
                        label: const Text('Añadir el primero', style: TextStyle(color: SGColors.primary)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: proveedores.length,
                  itemBuilder: (context, i) => _ProveedorCard(
                    proveedor: proveedores[i],
                    onEdit: () => _mostrarFormulario(context, ref, proveedor: proveedores[i]),
                    onDelete: () => _eliminar(context, ref, proveedores[i]),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: SGColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: profileAsync.when(
        data: (profile) => (profile?.canEdit ?? false)
            ? FloatingActionButton(
                onPressed: () => _mostrarFormulario(context, ref),
                backgroundColor: SGColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  void _mostrarFormulario(BuildContext context, WidgetRef ref, {Proveedor? proveedor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProveedorFormSheet(
        ref: ref,
        proveedor: proveedor,
      ),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Proveedor proveedor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar proveedor?'),
        content: Text('${proveedor.nombre} se eliminará de la lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SGColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(proveedorServiceProvider).delete(proveedor.id!);
      ref.invalidate(proveedoresProvider);
    }
  }
}

class _ProveedorCard extends StatelessWidget {
  final Proveedor proveedor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProveedorCard({
    required this.proveedor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proveedor.nombre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SGColors.textPrimary)),
                if (proveedor.contacto != null && proveedor.contacto!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(proveedor.contacto!,
                      style: const TextStyle(fontSize: 13, color: SGColors.textSecondary)),
                ],
                if (proveedor.telefono != null && proveedor.telefono!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: SGColors.textHint),
                      const SizedBox(width: 4),
                      Text(proveedor.telefono!,
                          style: const TextStyle(fontSize: 12, color: SGColors.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: SGColors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: SGColors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ProveedorFormSheet extends StatefulWidget {
  final WidgetRef ref;
  final Proveedor? proveedor;
  const _ProveedorFormSheet({required this.ref, this.proveedor});

  @override
  State<_ProveedorFormSheet> createState() => _ProveedorFormSheetState();
}

class _ProveedorFormSheetState extends State<_ProveedorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _contactoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  bool _loading = false;

  bool get isEditing => widget.proveedor != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.proveedor?.nombre ?? '');
    _contactoCtrl = TextEditingController(text: widget.proveedor?.contacto ?? '');
    _telefonoCtrl = TextEditingController(text: widget.proveedor?.telefono ?? '');
    _emailCtrl = TextEditingController(text: widget.proveedor?.email ?? '');
    _direccionCtrl = TextEditingController(text: widget.proveedor?.direccion ?? '');
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final service = widget.ref.read(proveedorServiceProvider);
      final proveedor = Proveedor(
        nombre: _nombreCtrl.text.trim(),
        contacto: _contactoCtrl.text.trim().isEmpty ? null : _contactoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      );

      if (isEditing) {
        await service.update(widget.proveedor!.id!, proveedor);
      } else {
        await service.create(proveedor);
      }

      widget.ref.invalidate(proveedoresProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Proveedor actualizado' : 'Proveedor creado'),
            backgroundColor: SGColors.primary,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: SGColors.textHint, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(isEditing ? 'Editar proveedor' : 'Nuevo proveedor',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del proveedor *',
                prefixIcon: Icon(Icons.business_outlined, color: SGColors.textHint),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Nombre requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoCtrl,
              decoration: const InputDecoration(
                labelText: 'Persona de contacto',
                prefixIcon: Icon(Icons.person_outlined, color: SGColors.textHint),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined, color: SGColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, color: SGColors.textHint),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined, color: SGColors.textHint),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _guardar,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Guardar Cambios' : 'Crear Proveedor'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contactoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }
}