import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// PEDIDO SERVICE — CRUD + recepción con actualización de stock
// ============================================================
class PedidoService {
  final Ref _ref;

  PedidoService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los pedidos del restaurante
  Future<List<Pedido>> getAll({String? estado}) async {
    var query = _supabase
        .from('pedidos')
        .select();

    if (estado != null && estado != 'todos') {
      query = query.eq('estado', estado);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((json) => Pedido.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Obtener un pedido por ID
  Future<Pedido> getById(String id) async {
    final data = await _supabase
        .from('pedidos')
        .select()
        .eq('id', id)
        .single();
    return Pedido.fromJson(data);
  }

  /// Crear nuevo pedido
  Future<Pedido> create(Pedido pedido) async {
    final profile = await _ref.read(currentProfileProvider.future);
    final data = await _supabase
        .from('pedidos')
        .insert({
          ...pedido.toJson(),
          'restaurante_id': profile!.restauranteId,
        })
        .select()
        .single();
    return Pedido.fromJson(data);
  }

  /// Actualizar pedido (estado, notas, etc.)
  Future<void> update(String id, Map<String, dynamic> changes) async {
    await _supabase
        .from('pedidos')
        .update(changes)
        .eq('id', id);
  }

  /// Cambiar estado del pedido
  Future<void> cambiarEstado(String id, String nuevoEstado) async {
    await _supabase
        .from('pedidos')
        .update({'estado': nuevoEstado})
        .eq('id', id);
  }

  /// Eliminar pedido (solo si está pendiente o cancelado)
  Future<void> delete(String id) async {
    await _supabase.from('pedidos').delete().eq('id', id);
  }

  /// Recibir pedido: actualiza stock de ingredientes (transaccional via RPC)
  Future<void> recibirPedido(String pedidoId) async {
    await _supabase.rpc('recibir_pedido', params: {'pedido_uuid': pedidoId});
  }

  // ============================================================
  // LÍNEAS DEL PEDIDO
  // ============================================================

  /// Obtener líneas de un pedido
  Future<List<PedidoLinea>> getLineas(String pedidoId) async {
    final data = await _supabase
        .from('pedido_lineas')
        .select()
        .eq('pedido_id', pedidoId)
        .order('created_at');
    return (data as List)
        .map((json) => PedidoLinea.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Añadir línea a un pedido
  Future<PedidoLinea> addLinea(PedidoLinea linea) async {
    final data = await _supabase
        .from('pedido_lineas')
        .insert(linea.toJson())
        .select()
        .single();
    return PedidoLinea.fromJson(data);
  }

  /// Eliminar línea de un pedido
  Future<void> removeLinea(String lineaId) async {
    await _supabase.from('pedido_lineas').delete().eq('id', lineaId);
  }

  /// Actualizar coste total del pedido (recalcular desde líneas)
  Future<void> recalcularCosteTotal(String pedidoId) async {
    final lineas = await getLineas(pedidoId);
    final total = lineas.fold<double>(0, (sum, l) => sum + l.costeLinea);
    await _supabase
        .from('pedidos')
        .update({'coste_total': total})
        .eq('id', pedidoId);
  }

  /// Estadísticas de pedidos
  Future<Map<String, dynamic>> getStats() async {
    final data = await _supabase.rpc('pedidos_stats');
    return data as Map<String, dynamic>;
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final pedidoServiceProvider = Provider<PedidoService>((ref) {
  return PedidoService(ref);
});

/// Lista de pedidos (filtrable por estado)
final pedidosProvider = FutureProvider.family<List<Pedido>, String?>(
  (ref, estado) async {
    final service = ref.read(pedidoServiceProvider);
    return service.getAll(estado: estado);
  },
);

/// Líneas de un pedido específico
final pedidoLineasProvider = FutureProvider.family<List<PedidoLinea>, String>(
  (ref, pedidoId) async {
    final service = ref.read(pedidoServiceProvider);
    return service.getLineas(pedidoId);
  },
);