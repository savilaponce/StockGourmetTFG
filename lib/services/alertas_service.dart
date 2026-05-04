import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// ALERTAS SERVICE
// Lee la vista v_alertas y la función contar_alertas() de Supabase.
// La RLS filtra por restaurante automáticamente.
// ============================================================
class AlertasService {
  final Ref _ref;
  AlertasService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Devuelve todas las alertas activas, ordenadas por severidad.
  Future<List<Alerta>> getAll({TipoAlerta? filtroTipo}) async {
    var query = _supabase.from('v_alertas').select();
    if (filtroTipo != null) {
      String? raw;
      switch (filtroTipo) {
        case TipoAlerta.caducidadVencida:
          raw = 'caducidad_vencida';
          break;
        case TipoAlerta.caducidadCritica:
          raw = 'caducidad_critica';
          break;
        case TipoAlerta.caducidadProxima:
          raw = 'caducidad_proxima';
          break;
        case TipoAlerta.stockCritico:
          raw = 'stock_critico';
          break;
        case TipoAlerta.stockBajo:
          raw = 'stock_bajo';
          break;
        case TipoAlerta.desconocido:
          raw = null;
          break;
      }
      if (raw != null) query = query.eq('tipo', raw);
    }
    final data = await query.order('severidad').order('nombre');
    return (data as List)
        .map((j) => Alerta.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Resumen agregado para el badge.
  Future<ResumenAlertas> getResumen() async {
    final data = await _supabase.rpc('contar_alertas');
    if (data is List && data.isNotEmpty) {
      return ResumenAlertas.fromJson(data.first as Map<String, dynamic>);
    }
    if (data is Map<String, dynamic>) {
      return ResumenAlertas.fromJson(data);
    }
    return const ResumenAlertas();
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final alertasServiceProvider = Provider<AlertasService>((ref) {
  return AlertasService(ref);
});

/// Lista completa de alertas, opcionalmente filtrada por tipo.
final alertasProvider =
    FutureProvider.family<List<Alerta>, TipoAlerta?>((ref, filtro) async {
  final service = ref.read(alertasServiceProvider);
  return service.getAll(filtroTipo: filtro);
});

/// Resumen para el badge. Auto-refresca cada 60 segundos.
final resumenAlertasProvider = StreamProvider<ResumenAlertas>((ref) async* {
  final service = ref.read(alertasServiceProvider);

  // Emitir inmediatamente
  yield await service.getResumen();

  // Refrescar cada 60 s
  await for (final _
      in Stream<void>.periodic(const Duration(seconds: 60))) {
    try {
      yield await service.getResumen();
    } catch (_) {
      // Silenciar errores transitorios
    }
  }
});