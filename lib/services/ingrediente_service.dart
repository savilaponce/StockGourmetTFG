import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// INGREDIENTE SERVICE — CRUD + consultas de inventario
// ============================================================
class IngredienteService {
  final Ref _ref;

  IngredienteService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los ingredientes del restaurante actual
  /// RLS se encarga de filtrar por restaurante_id
  Future<List<Ingrediente>> getAll({String? categoria}) async {
    var query = _supabase
        .from('ingredientes')
        .select()
        .eq('activo', true);

    if (categoria != null && categoria != 'todos') {
      query = query.eq('categoria', categoria);
    }

    final data = await query.order('nombre');
    return data.map((json) => Ingrediente.fromJson(json)).toList();
  }

  /// Obtener un ingrediente por ID
  Future<Ingrediente> getById(String id) async {
    final data = await _supabase
        .from('ingredientes')
        .select()
        .eq('id', id)
        .single();
    return Ingrediente.fromJson(data);
  }

  /// Crear nuevo ingrediente
  Future<Ingrediente> create(Ingrediente ingrediente) async {
    final profile = await _ref.read(currentProfileProvider.future);
    final data = await _supabase
        .from('ingredientes')
        .insert({
          ...ingrediente.toJson(),
          'restaurante_id': profile!.restauranteId,
        })
        .select()
        .single();
    return Ingrediente.fromJson(data);
  }

  /// Actualizar ingrediente
  Future<Ingrediente> update(String id, Ingrediente ingrediente) async {
    final data = await _supabase
        .from('ingredientes')
        .update(ingrediente.toJson())
        .eq('id', id)
        .select()
        .single();
    return Ingrediente.fromJson(data);
  }

  /// Eliminar ingrediente (soft delete)
  Future<void> delete(String id) async {
    await _supabase
        .from('ingredientes')
        .update({'activo': false})
        .eq('id', id);
  }

  /// Ingredientes próximos a caducar (vista SQL)
  Future<List<Ingrediente>> getPorCaducar() async {
    final data = await _supabase
        .from('v_ingredientes_por_caducar')
        .select()
        .order('fecha_caducidad');
    return data.map((json) => Ingrediente.fromJson(json)).toList();
  }

  /// Buscar ingredientes por nombre
  Future<List<Ingrediente>> search(String query) async {
    final data = await _supabase
        .from('ingredientes')
        .select()
        .eq('activo', true)
        .ilike('nombre', '%$query%')
        .order('nombre')
        .limit(20);
    return data.map((json) => Ingrediente.fromJson(json)).toList();
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final ingredienteServiceProvider = Provider<IngredienteService>((ref) {
  return IngredienteService(ref);
});

/// Lista de ingredientes (se invalida manualmente al crear/editar/borrar)
final ingredientesProvider = FutureProvider.family<List<Ingrediente>, String?>(
  (ref, categoria) async {
    final service = ref.read(ingredienteServiceProvider);
    return service.getAll(categoria: categoria);
  },
);

/// Ingredientes por caducar (para el dashboard)
final ingredientesPorCaducarProvider = FutureProvider<List<Ingrediente>>(
  (ref) async {
    final service = ref.read(ingredienteServiceProvider);
    return service.getPorCaducar();
  },
);
