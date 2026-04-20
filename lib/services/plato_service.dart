import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// PLATO SERVICE — CRUD + cálculo de costes
// ============================================================
class PlatoService {
  final Ref _ref;

  PlatoService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los platos CON costes calculados (vista SQL)
  Future<List<Plato>> getAll({String? categoria}) async {
    var query = _supabase
        .from('v_plato_costes')
        .select()
        .eq('activo', true);

    if (categoria != null && categoria != 'todos') {
      query = query.eq('categoria', categoria);
    }

    final List data = await query.order('nombre');
    return data.map((json) => Plato.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Obtener plato básico por ID (sin costes)
  Future<Plato> getById(String id) async {
    final data = await _supabase
        .from('platos')
        .select()
        .eq('id', id)
        .single();
    return Plato.fromJson(data);
  }

  /// Obtener plato CON costes detallados via RPC
  Future<Map<String, dynamic>> getConCostes(String id) async {
    final data = await _supabase.rpc(
      'calcular_coste_plato',
      params: {'plato_uuid': id},
    );
    return (data as List).first as Map<String, dynamic>;
  }

  /// Crear nuevo plato — devuelve el ID del plato creado
  Future<String> create(Plato plato) async {
    final profile = await _ref.read(currentProfileProvider.future);
    final restauranteId = profile!.restauranteId;

    // Insert sin .select() para evitar conflicto con RLS
    await _supabase
        .from('platos')
        .insert({
          ...plato.toJson(),
          'restaurante_id': restauranteId,
        });

    // Buscar el plato recién creado por nombre y restaurante
    final data = await _supabase
        .from('platos')
        .select('id')
        .eq('restaurante_id', restauranteId)
        .eq('nombre', plato.nombre)
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    return data['id'] as String;
  }

  /// Actualizar plato
  Future<void> update(String id, Plato plato) async {
    await _supabase
        .from('platos')
        .update(plato.toJson())
        .eq('id', id);
  }

  /// Eliminar plato (soft delete)
  Future<void> delete(String id) async {
    await _supabase.from('platos').update({'activo': false}).eq('id', id);
  }

  // ============================================================
  // INGREDIENTES DEL PLATO
  // ============================================================

  /// Obtener ingredientes asignados a un plato (con datos del ingrediente via join)
  Future<List<PlatoIngrediente>> getIngredientes(String platoId) async {
    final data = await _supabase
        .from('plato_ingredientes')
        .select('*, ingredientes(nombre, unidad, coste_por_unidad)')
        .eq('plato_id', platoId);

    return (data as List)
        .map((json) => PlatoIngrediente.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Asignar ingrediente a un plato
  Future<void> addIngrediente({
    required String platoId,
    required String ingredienteId,
    required double cantidad,
  }) async {
    await _supabase.from('plato_ingredientes').upsert(
      {
        'plato_id': platoId,
        'ingrediente_id': ingredienteId,
        'cantidad': cantidad,
      },
      onConflict: 'plato_id,ingrediente_id',
    );
  }

  /// Actualizar cantidad de un ingrediente en el plato
  Future<void> updateIngredienteCantidad(String id, double cantidad) async {
    await _supabase
        .from('plato_ingredientes')
        .update({'cantidad': cantidad})
        .eq('id', id);
  }

  /// Quitar ingrediente de un plato
  Future<void> removeIngrediente(String id) async {
    await _supabase.from('plato_ingredientes').delete().eq('id', id);
  }

  /// Reemplazar TODOS los ingredientes de un plato (transaccional)
  Future<void> replaceIngredientes(
    String platoId,
    List<PlatoIngrediente> ingredientes,
  ) async {
    // Borrar existentes
    await _supabase
        .from('plato_ingredientes')
        .delete()
        .eq('plato_id', platoId);

    // Insertar nuevos
    if (ingredientes.isNotEmpty) {
      await _supabase.from('plato_ingredientes').insert(
        ingredientes.map((pi) => pi.toJson()).toList(),
      );
    }
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final platoServiceProvider = Provider<PlatoService>((ref) {
  return PlatoService(ref);
});

/// Lista de platos con costes (vista SQL)
final platosProvider = FutureProvider.family<List<Plato>, String?>(
  (ref, categoria) async {
    final service = ref.read(platoServiceProvider);
    return service.getAll(categoria: categoria);
  },
);

/// Ingredientes de un plato específico
final platoIngredientesProvider =
    FutureProvider.family<List<PlatoIngrediente>, String>(
  (ref, platoId) async {
    final service = ref.read(platoServiceProvider);
    return service.getIngredientes(platoId);
  },
);

/// Dashboard stats via RPC
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.rpc('dashboard_stats');
  return data as Map<String, dynamic>;
});