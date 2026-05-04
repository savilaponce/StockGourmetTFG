import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// MOVIMIENTO STOCK SERVICE
// Histórico inmutable de cambios de stock.
// ============================================================
class MovimientoStockService {
  final Ref _ref;
  MovimientoStockService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Registra un movimiento. Lo llaman desde IngredienteService
  /// cuando hay cambios de stock; raramente se llama directo.
  Future<MovimientoStock> crear({
    required String ingredienteId,
    required TipoMovimiento tipo,
    required double cantidad,
    String? unidad,
    double? stockAntes,
    double? stockDespues,
    double? costeUnitario,
    String? notas,
    String? referencia,
  }) async {
    final profile = await _ref.read(currentProfileProvider.future);
    if (profile == null) {
      throw StateError('No hay perfil de usuario activo.');
    }
    final session = _supabase.auth.currentSession;
    final userId = session?.user.id;

    final data = await _supabase
        .from('movimientos_stock')
        .insert({
          'restaurante_id': profile.restauranteId,
          'ingrediente_id': ingredienteId,
          'tipo': tipo.raw,
          'cantidad': cantidad.abs(),
          'unidad': unidad,
          'stock_antes': stockAntes,
          'stock_despues': stockDespues,
          'coste_unitario': costeUnitario,
          'usuario_id': userId,
          'notas': notas,
          'referencia': referencia,
        })
        .select()
        .single();

    return MovimientoStock.fromJson(data);
  }

  /// Movimientos de un ingrediente, los más recientes primero.
  Future<List<MovimientoStock>> getByIngrediente(
    String ingredienteId, {
    int limit = 50,
  }) async {
    final data = await _supabase
        .from('movimientos_stock')
        .select()
        .eq('ingrediente_id', ingredienteId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((j) => MovimientoStock.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Evolución de stock de un ingrediente en los últimos 30 días.
  Future<List<PuntoEvolucionStock>> getEvolucion30Dias(
    String ingredienteId,
  ) async {
    final data = await _supabase
        .from('v_evolucion_stock_30d')
        .select('fecha, stock_estimado')
        .eq('ingrediente_id', ingredienteId)
        .order('fecha');
    return (data as List)
        .map((j) =>
            PuntoEvolucionStock.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final movimientoStockServiceProvider =
    Provider<MovimientoStockService>((ref) {
  return MovimientoStockService(ref);
});

final movimientosPorIngredienteProvider =
    FutureProvider.family<List<MovimientoStock>, String>(
  (ref, ingredienteId) async {
    final service = ref.read(movimientoStockServiceProvider);
    return service.getByIngrediente(ingredienteId);
  },
);

final evolucionStockProvider =
    FutureProvider.family<List<PuntoEvolucionStock>, String>(
  (ref, ingredienteId) async {
    final service = ref.read(movimientoStockServiceProvider);
    return service.getEvolucion30Dias(ingredienteId);
  },
);