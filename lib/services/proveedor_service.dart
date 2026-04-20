import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// PROVEEDOR SERVICE — CRUD de proveedores
// ============================================================
class ProveedorService {
  final Ref _ref;

  ProveedorService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los proveedores activos del restaurante
  Future<List<Proveedor>> getAll() async {
    final data = await _supabase
        .from('proveedores')
        .select()
        .eq('activo', true)
        .order('nombre');
    return (data as List)
        .map((json) => Proveedor.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Crear nuevo proveedor
  Future<Proveedor> create(Proveedor proveedor) async {
    final profile = await _ref.read(currentProfileProvider.future);
    final data = await _supabase
        .from('proveedores')
        .insert({
          ...proveedor.toJson(),
          'restaurante_id': profile!.restauranteId,
        })
        .select()
        .single();
    return Proveedor.fromJson(data);
  }

  /// Actualizar proveedor
  Future<void> update(String id, Proveedor proveedor) async {
    await _supabase
        .from('proveedores')
        .update(proveedor.toJson())
        .eq('id', id);
  }

  /// Eliminar proveedor (soft delete)
  Future<void> delete(String id) async {
    await _supabase
        .from('proveedores')
        .update({'activo': false})
        .eq('id', id);
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final proveedorServiceProvider = Provider<ProveedorService>((ref) {
  return ProveedorService(ref);
});

final proveedoresProvider = FutureProvider<List<Proveedor>>((ref) async {
  final service = ref.read(proveedorServiceProvider);
  return service.getAll();
});