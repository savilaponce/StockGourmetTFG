import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'movimiento_stock_service.dart';
import 'ocr_service.dart'; // para LineaAlbaran

// ============================================================
// INGREDIENTE SERVICE — CRUD + flujo de albarán
// ============================================================
class IngredienteService {
  final Ref _ref;

  IngredienteService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los ingredientes del restaurante actual
  Future<List<Ingrediente>> getAll({String? categoria}) async {
    var query = _supabase.from('ingredientes').select().eq('activo', true);
    if (categoria != null && categoria != 'todos') {
      query = query.eq('categoria', categoria);
    }
    final data = await query.order('nombre');
    return data.map((json) => Ingrediente.fromJson(json)).toList();
  }

  Future<Ingrediente> getById(String id) async {
    final data = await _supabase
        .from('ingredientes')
        .select()
        .eq('id', id)
        .single();
    return Ingrediente.fromJson(data);
  }

  Future<Ingrediente> create(Ingrediente ingrediente) async {
    final profile = await _ref.read(currentProfileProvider.future);
    if (profile == null) {
      throw StateError(
          'No hay perfil de usuario activo. ¿Sesión caducada? Reinicia sesión.');
    }
    developer.log(
      'create: insert "${ingrediente.nombre}" en restaurante ${profile.restauranteId}',
      name: 'IngrSvc',
    );
    final data = await _supabase
        .from('ingredientes')
        .insert({
          ...ingrediente.toJson(),
          'restaurante_id': profile.restauranteId,
        })
        .select()
        .single();
    return Ingrediente.fromJson(data);
  }

  Future<Ingrediente> update(String id, Ingrediente ingrediente) async {
    final data = await _supabase
        .from('ingredientes')
        .update(ingrediente.toJson())
        .eq('id', id)
        .select()
        .single();
    return Ingrediente.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _supabase
        .from('ingredientes')
        .update({'activo': false}).eq('id', id);
  }

  Future<List<Ingrediente>> getPorCaducar() async {
    final data = await _supabase
        .from('v_ingredientes_por_caducar')
        .select()
        .order('fecha_caducidad');
    return data.map((json) => Ingrediente.fromJson(json)).toList();
  }

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

  /// Busca ingrediente activo por nombre exacto (case-insensitive). null si no existe.
  /// Ajusta el stock de un ingrediente sumando un delta (positivo o negativo)
  /// y registra el movimiento en el histórico.
  ///
  /// [motivo] es el tipo de movimiento ('entrada', 'salida', 'merma', 'ajuste').
  Future<Ingrediente> ajustarStock(
    String ingredienteId,
    double delta, {
    String motivo = 'ajuste',
    String? notas,
  }) async {
    // Leer estado actual
    final actual = await getById(ingredienteId);
    final stockAntes = actual.stockActual;
    final stockDespues =
        (actual.stockActual + delta).clamp(0.0, double.infinity);

    final actualizado = Ingrediente(
      nombre: actual.nombre,
      categoria: actual.categoria,
      stockActual: stockDespues,
      stockMinimo: actual.stockMinimo,
      unidad: actual.unidad,
      costePorUnidad: actual.costePorUnidad,
      proveedor: actual.proveedor,
      fechaCaducidad: actual.fechaCaducidad,
      notas: actual.notas,
      activo: true,
    );
    final result = await update(ingredienteId, actualizado);

    // Registrar movimiento (mejor esfuerzo: si falla, no rompemos el ajuste)
    try {
      final tipo = TipoMovimientoX.fromString(motivo);
      await _ref.read(movimientoStockServiceProvider).crear(
            ingredienteId: ingredienteId,
            tipo: tipo == TipoMovimiento.desconocido
                ? TipoMovimiento.ajuste
                : tipo,
            cantidad: delta.abs(),
            unidad: actual.unidad,
            stockAntes: stockAntes,
            stockDespues: stockDespues,
            costeUnitario: actual.costePorUnidad,
            notas: notas,
          );
    } catch (e) {
      developer.log('No se pudo registrar movimiento: $e', name: 'IngrSvc');
    }

    return result;
  }

  Future<Ingrediente?> findByNombre(String nombre) async {
    final data = await _supabase
        .from('ingredientes')
        .select()
        .eq('activo', true)
        .ilike('nombre', nombre.trim())
        .maybeSingle();
    if (data == null) return null;
    return Ingrediente.fromJson(data);
  }

  /// Para cada línea del OCR, comprobar si ya existe ese ingrediente.
  /// Devuelve una lista de [LineaAlbaranAnalizada] que la UI usará para
  /// que el usuario decida qué hacer con las que no existen.
  Future<List<LineaAlbaranAnalizada>> analizarLineas(
      List<LineaAlbaran> lineas) async {
    final analizadas = <LineaAlbaranAnalizada>[];
    for (final linea in lineas) {
      final existente = await findByNombre(linea.nombreProducto);
      analizadas.add(LineaAlbaranAnalizada(
        linea: linea,
        ingredienteExistente: existente,
        // Por defecto: si existe → fusionar, si no → crear nuevo
        accion: existente != null
            ? AccionLinea.fusionar
            : AccionLinea.crearNuevo,
      ));
    }
    return analizadas;
  }

  /// Aplica las decisiones del usuario línea a línea.
  Future<ResumenAlbaran> aplicarDecisiones(
      List<LineaAlbaranAnalizada> analizadas) async {
    developer.log(
        'aplicarDecisiones: ${analizadas.length} líneas a procesar',
        name: 'IngrSvc');

    int actualizados = 0;
    int creados = 0;
    int descartados = 0;
    final errores = <String>[];

    for (var i = 0; i < analizadas.length; i++) {
      final a = analizadas[i];
      final linea = a.linea;
      final nombre = linea.nombreProducto.trim();

      developer.log('[$i] "${nombre}" acción=${a.accion}', name: 'IngrSvc');

      if (a.accion == AccionLinea.descartar) {
        descartados++;
        continue;
      }
      if (nombre.isEmpty || linea.cantidad <= 0) {
        descartados++;
        continue;
      }

      try {
        switch (a.accion) {
          case AccionLinea.fusionar:
            final destino = a.ingredienteExistente;
            if (destino == null) {
              errores.add('$nombre: marcado como fusionar pero sin destino');
              continue;
            }
            // Política: sobrescribir el coste con el precio del albarán más
            // reciente. Si el usuario dejó el campo vacío (precioUnitario == 0)
            // mantenemos el coste anterior para no perder el dato bueno.
            final stockNuevo = destino.stockActual + linea.cantidad;
            final nuevoCoste = linea.precioUnitario > 0
                ? linea.precioUnitario
                : destino.costePorUnidad;
            developer.log(
              'fusionar "$nombre": stock ${destino.stockActual}+${linea.cantidad}=$stockNuevo, '
              'coste ${destino.costePorUnidad}→$nuevoCoste (precio albarán ${linea.precioUnitario})',
              name: 'IngrSvc',
            );
            final actualizado = Ingrediente(
              nombre: destino.nombre,
              categoria: destino.categoria,
              stockActual: stockNuevo,
              stockMinimo: destino.stockMinimo,
              unidad: destino.unidad,
              costePorUnidad: nuevoCoste,
              proveedor: destino.proveedor,
              fechaCaducidad: destino.fechaCaducidad,
              notas: destino.notas,
              activo: true,
            );
            await update(destino.id!, actualizado);
            actualizados++;

            // Registrar movimiento (best-effort)
            try {
              await _ref.read(movimientoStockServiceProvider).crear(
                    ingredienteId: destino.id!,
                    tipo: TipoMovimiento.albaran,
                    cantidad: linea.cantidad,
                    unidad: destino.unidad,
                    stockAntes: destino.stockActual,
                    stockDespues: stockNuevo,
                    costeUnitario: nuevoCoste,
                    notas: 'Albarán: $nombre',
                  );
            } catch (e) {
              developer.log('No se registró movimiento albarán: $e',
                  name: 'IngrSvc');
            }
            break;

          case AccionLinea.crearNuevo:
            final nuevo = await create(Ingrediente(
              nombre: nombre,
              categoria: 'otros',
              stockActual: linea.cantidad,
              stockMinimo: 0,
              unidad: linea.unidad,
              costePorUnidad: linea.precioUnitario,
              activo: true,
            ));
            creados++;

            // Registrar movimiento de creación inicial
            try {
              await _ref.read(movimientoStockServiceProvider).crear(
                    ingredienteId: nuevo.id!,
                    tipo: TipoMovimiento.albaran,
                    cantidad: linea.cantidad,
                    unidad: linea.unidad,
                    stockAntes: 0,
                    stockDespues: linea.cantidad,
                    costeUnitario: linea.precioUnitario,
                    notas: 'Alta por albarán: $nombre',
                  );
            } catch (e) {
              developer.log('No se registró movimiento albarán: $e',
                  name: 'IngrSvc');
            }
            break;

          case AccionLinea.descartar:
            break;
        }
      } catch (e, st) {
        developer.log('Error en línea "$nombre": $e\n$st',
            name: 'IngrSvc', error: e);
        errores.add('$nombre: $e');
      }
    }

    developer.log(
      'aplicarDecisiones DONE: $actualizados upd / $creados new / '
      '$descartados desc / ${errores.length} err',
      name: 'IngrSvc',
    );

    return ResumenAlbaran(
      actualizados: actualizados,
      creados: creados,
      descartados: descartados,
      errores: errores,
    );
  }
}

// ============================================================
// MODELOS AUXILIARES PARA EL FLUJO DE ALBARÁN
// ============================================================
enum AccionLinea {
  /// Sumar la cantidad al ingrediente existente
  fusionar,

  /// Crear un nuevo ingrediente con esta línea
  crearNuevo,

  /// Ignorar esta línea
  descartar,
}

/// Una línea del albarán tras analizarla contra el inventario actual
class LineaAlbaranAnalizada {
  final LineaAlbaran linea;
  final Ingrediente? ingredienteExistente;
  final AccionLinea accion;

  LineaAlbaranAnalizada({
    required this.linea,
    this.ingredienteExistente,
    required this.accion,
  });

  bool get yaExiste => ingredienteExistente != null;

  LineaAlbaranAnalizada copyWith({
    LineaAlbaran? linea,
    Ingrediente? ingredienteExistente,
    bool limpiarIngredienteExistente = false,
    AccionLinea? accion,
  }) {
    return LineaAlbaranAnalizada(
      linea: linea ?? this.linea,
      ingredienteExistente: limpiarIngredienteExistente
          ? null
          : (ingredienteExistente ?? this.ingredienteExistente),
      accion: accion ?? this.accion,
    );
  }
}

class ResumenAlbaran {
  final int actualizados;
  final int creados;
  final int descartados;
  final List<String> errores;

  ResumenAlbaran({
    this.actualizados = 0,
    this.creados = 0,
    this.descartados = 0,
    this.errores = const [],
  });

  int get totalAplicados => actualizados + creados;
  bool get tieneErrores => errores.isNotEmpty;
}

// ============================================================
// PROVIDERS
// ============================================================
final ingredienteServiceProvider = Provider<IngredienteService>((ref) {
  return IngredienteService(ref);
});

final ingredientesProvider = FutureProvider.family<List<Ingrediente>, String?>(
  (ref, categoria) async {
    final service = ref.read(ingredienteServiceProvider);
    return service.getAll(categoria: categoria);
  },
);

final ingredientesPorCaducarProvider = FutureProvider<List<Ingrediente>>(
  (ref) async {
    final service = ref.read(ingredienteServiceProvider);
    return service.getPorCaducar();
  },
);