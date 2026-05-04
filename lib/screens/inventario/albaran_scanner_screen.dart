import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/ocr_service.dart';
import '../../services/ingrediente_service.dart';

// ============================================================
// ESTADO DEL ESCÁNER
// ============================================================
enum EstadoEscaner {
  inicial,
  procesando,    // OCR en curso
  resultado,     // OCR listo, usuario revisa/edita las líneas extraídas
  analizando,    // Cruzando con el inventario
  decidiendo,    // Usuario revisa qué hacer con cada línea (fusionar/crear/descartar)
  guardando,     // Aplicando cambios en Supabase
  completado,    // Guardado OK, listos para navegar fuera
  error,
}

class EscanerState {
  final EstadoEscaner estado;
  final XFile? imagen;
  final ResultadoOCR? resultado;
  final List<LineaAlbaran> lineasEditadas;
  final List<LineaAlbaranAnalizada> lineasAnalizadas;
  final ResumenAlbaran? resumen;
  final String? mensajeError;

  const EscanerState({
    this.estado = EstadoEscaner.inicial,
    this.imagen,
    this.resultado,
    this.lineasEditadas = const [],
    this.lineasAnalizadas = const [],
    this.resumen,
    this.mensajeError,
  });

  EscanerState copyWith({
    EstadoEscaner? estado,
    XFile? imagen,
    ResultadoOCR? resultado,
    List<LineaAlbaran>? lineasEditadas,
    List<LineaAlbaranAnalizada>? lineasAnalizadas,
    ResumenAlbaran? resumen,
    String? mensajeError,
  }) =>
      EscanerState(
        estado: estado ?? this.estado,
        imagen: imagen ?? this.imagen,
        resultado: resultado ?? this.resultado,
        lineasEditadas: lineasEditadas ?? this.lineasEditadas,
        lineasAnalizadas: lineasAnalizadas ?? this.lineasAnalizadas,
        resumen: resumen ?? this.resumen,
        mensajeError: mensajeError ?? this.mensajeError,
      );
}

// ============================================================
// NOTIFIER
// ============================================================
class EscanerNotifier extends StateNotifier<EscanerState> {
  final OcrService _ocrService;
  final IngredienteService _ingredienteService;

  EscanerNotifier(this._ocrService, this._ingredienteService)
      : super(const EscanerState());

  Future<void> tomarFoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    await _procesarImagen(picked);
  }

  Future<void> seleccionarGaleria() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    await _procesarImagen(picked);
  }

  Future<void> _procesarImagen(XFile imagen) async {
    state = state.copyWith(estado: EstadoEscaner.procesando, imagen: imagen);

    final resultado = await _ocrService.escanearAlbaran(imagen);

    if (resultado.tieneError) {
      state = state.copyWith(
          estado: EstadoEscaner.error, resultado: resultado);
    } else {
      state = state.copyWith(
        estado: EstadoEscaner.resultado,
        resultado: resultado,
        lineasEditadas: List.from(resultado.lineas),
      );
    }
  }

  // -- edición de líneas durante el estado "resultado" -----------------------
  void actualizarLinea(int index, LineaAlbaran linea) {
    final nuevas = List<LineaAlbaran>.from(state.lineasEditadas);
    nuevas[index] = linea;
    state = state.copyWith(lineasEditadas: nuevas);
  }

  void eliminarLinea(int index) {
    final nuevas = List<LineaAlbaran>.from(state.lineasEditadas)
      ..removeAt(index);
    state = state.copyWith(lineasEditadas: nuevas);
  }

  void agregarLinea() {
    final nuevas = List<LineaAlbaran>.from(state.lineasEditadas)
      ..add(LineaAlbaran(nombreProducto: '', cantidad: 1, unidad: 'kg'));
    state = state.copyWith(lineasEditadas: nuevas);
  }

  // -- paso 2: analizar contra inventario -----------------------------------
  Future<void> analizarContraInventario() async {
    if (state.lineasEditadas.isEmpty) return;
    state = state.copyWith(estado: EstadoEscaner.analizando);
    try {
      final analizadas =
          await _ingredienteService.analizarLineas(state.lineasEditadas);
      state = state.copyWith(
        estado: EstadoEscaner.decidiendo,
        lineasAnalizadas: analizadas,
      );
    } catch (e) {
      state = state.copyWith(
        estado: EstadoEscaner.error,
        mensajeError: 'Error analizando: $e',
      );
    }
  }

  // -- edición de decisiones durante el estado "decidiendo" ------------------
  void cambiarAccion(int index, AccionLinea accion) {
    final nuevas =
        List<LineaAlbaranAnalizada>.from(state.lineasAnalizadas);
    nuevas[index] = nuevas[index].copyWith(accion: accion);
    state = state.copyWith(lineasAnalizadas: nuevas);
  }

  /// El usuario eligió manualmente fusionar con un ingrediente concreto
  void asignarFusionManual(int index, Ingrediente destino) {
    final nuevas =
        List<LineaAlbaranAnalizada>.from(state.lineasAnalizadas);
    nuevas[index] = nuevas[index].copyWith(
      ingredienteExistente: destino,
      accion: AccionLinea.fusionar,
    );
    state = state.copyWith(lineasAnalizadas: nuevas);
  }

  /// Actualiza el precio unitario de una línea (solo aplica al crear nuevo)
  void cambiarPrecio(int index, double precio) {
    final nuevas =
        List<LineaAlbaranAnalizada>.from(state.lineasAnalizadas);
    final actual = nuevas[index];
    nuevas[index] = actual.copyWith(
      linea: actual.linea.copyWith(precioUnitario: precio),
    );
    state = state.copyWith(lineasAnalizadas: nuevas);
  }

  void volverARevisarLineas() {
    state = state.copyWith(estado: EstadoEscaner.resultado);
  }

  // -- paso 3: aplicar ------------------------------------------------------
  /// Aplica los cambios. Al terminar, deja el estado en `completado` (con
  /// el resumen) o en `error`. La UI debe escuchar estas transiciones para
  /// navegar / mostrar mensajes.
  Future<void> confirmar() async {
    // Re-entry guard: si ya estamos guardando, ignorar pulsaciones extra
    if (state.estado == EstadoEscaner.guardando) return;
    if (state.lineasAnalizadas.isEmpty) return;

    state = state.copyWith(estado: EstadoEscaner.guardando);
    try {
      final resumen = await _ingredienteService
          .aplicarDecisiones(state.lineasAnalizadas);

      if (resumen.tieneErrores && resumen.totalAplicados == 0) {
        // Todo falló: vamos al estado de error con el detalle
        state = state.copyWith(
          estado: EstadoEscaner.error,
          mensajeError:
              'No se pudo guardar ninguna línea:\n\n${resumen.errores.join('\n\n')}',
          resumen: resumen,
        );
      } else {
        // OK total o parcial: marcamos completado, la UI navegará
        state = state.copyWith(
          estado: EstadoEscaner.completado,
          resumen: resumen,
        );
      }
    } catch (e) {
      state = state.copyWith(
        estado: EstadoEscaner.error,
        mensajeError: 'Error al guardar: $e',
      );
    }
  }

  void reiniciar() {
    state = const EscanerState();
  }
}

final escanerProvider =
    StateNotifierProvider.autoDispose<EscanerNotifier, EscanerState>((ref) {
  return EscanerNotifier(
    ref.read(ocrServiceProvider),
    ref.read(ingredienteServiceProvider),
  );
});

// ============================================================
// PANTALLA PRINCIPAL
// ============================================================
class AlbaranScannerScreen extends ConsumerWidget {
  const AlbaranScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(escanerProvider);

    // Reaccionar a la transición a "completado": refrescar inventario,
    // mostrar SnackBar y navegar al home.
    ref.listen<EscanerState>(escanerProvider, (prev, next) {
      if (prev?.estado != EstadoEscaner.completado &&
          next.estado == EstadoEscaner.completado) {
        final resumen = next.resumen;
        if (resumen == null) return;

        // Refrescar providers de inventario
        ref.invalidate(ingredientesProvider);
        ref.invalidate(ingredientesPorCaducarProvider);

        // Construir mensaje
        final partes = <String>[];
        if (resumen.actualizados > 0) {
          partes.add('${resumen.actualizados} actualizados');
        }
        if (resumen.creados > 0) partes.add('${resumen.creados} creados');
        if (resumen.descartados > 0) {
          partes.add('${resumen.descartados} descartados');
        }
        if (resumen.tieneErrores) {
          partes.add('${resumen.errores.length} con error');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventario actualizado: ${partes.join(', ')}'),
            backgroundColor:
                resumen.tieneErrores ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navegar al home (no solo pop, para no volver al scanner)
        if (context.mounted) context.go('/');
      }
    });

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        title: Text(_titulo(state.estado)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Si estamos guardando, no permitir salir
            if (state.estado == EstadoEscaner.guardando) return;
            // Si estamos decidiendo, volver al paso anterior; si no, salir
            if (state.estado == EstadoEscaner.decidiendo) {
              ref.read(escanerProvider.notifier).volverARevisarLineas();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (state.estado == EstadoEscaner.resultado ||
              state.estado == EstadoEscaner.decidiendo)
            TextButton(
              onPressed: () => ref.read(escanerProvider.notifier).reiniciar(),
              child: const Text('Nuevo'),
            ),
        ],
      ),
      body: switch (state.estado) {
        EstadoEscaner.inicial => _VistaInicial(
            onCamara: () => ref.read(escanerProvider.notifier).tomarFoto(),
            onGaleria: () =>
                ref.read(escanerProvider.notifier).seleccionarGaleria(),
          ),
        EstadoEscaner.procesando =>
          _VistaCargando(imagen: state.imagen, mensaje: 'Leyendo albarán...'),
        EstadoEscaner.analizando =>
          const _VistaCargando(mensaje: 'Comprobando inventario...'),
        EstadoEscaner.guardando =>
          const _VistaCargando(mensaje: 'Actualizando inventario...'),
        EstadoEscaner.completado =>
          const _VistaCargando(mensaje: 'Listo, redirigiendo...'),
        EstadoEscaner.resultado => _VistaResultado(state: state),
        EstadoEscaner.decidiendo => _VistaDecidiendo(state: state),
        EstadoEscaner.error => _VistaError(
            mensaje: state.mensajeError ??
                state.resultado?.error ??
                'Error desconocido',
            onReintentar: () => ref.read(escanerProvider.notifier).reiniciar(),
          ),
      },
    );
  }

  String _titulo(EstadoEscaner e) => switch (e) {
        EstadoEscaner.decidiendo => 'Revisar y confirmar',
        EstadoEscaner.resultado => 'Productos detectados',
        _ => 'Escanear Albarán',
      };
}

// ============================================================
// VISTA INICIAL
// ============================================================
class _VistaInicial extends StatelessWidget {
  final VoidCallback onCamara;
  final VoidCallback onGaleria;

  const _VistaInicial({required this.onCamara, required this.onGaleria});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: SGColors.primaryLight,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.document_scanner_outlined,
                size: 64, color: SGColors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            'Escanear Albarán',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onCamara,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Hacer Foto'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: onGaleria,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Seleccionar de Galería'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SGColors.primary,
                side: const BorderSide(color: SGColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VISTA CARGANDO (genérica para procesando / analizando / guardando)
// ============================================================
class _VistaCargando extends StatelessWidget {
  final XFile? imagen;
  final String mensaje;

  const _VistaCargando({this.imagen, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (imagen != null)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: kIsWeb
                    ? Image.network(imagen!.path, fit: BoxFit.contain)
                    : Image.file(File(imagen!.path), fit: BoxFit.contain),
              ),
            ),
          )
        else
          const Spacer(),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(color: SGColors.primary),
              const SizedBox(height: 12),
              Text(mensaje),
            ],
          ),
        ),
        if (imagen == null) const Spacer(),
      ],
    );
  }
}

// ============================================================
// VISTA RESULTADO (paso 1 → revisar líneas extraídas del OCR)
// ============================================================
class _VistaResultado extends ConsumerWidget {
  final EscanerState state;
  const _VistaResultado({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineas = state.lineasEditadas;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: SGColors.primaryLight,
          child: Text(
            '${lineas.length} productos detectados. Revisa antes de continuar.',
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: lineas.isEmpty
              ? const Center(child: Text('No se reconoció ningún producto'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lineas.length,
                  itemBuilder: (context, index) => Card(
                    child: ListTile(
                      title: Text(lineas[index].nombreProducto),
                      subtitle: Text(
                          '${lineas[index].cantidad} ${lineas[index].unidad}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _mostrarEditorLinea(
                                context, ref, index, lineas[index]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.redAccent),
                            onPressed: () => ref
                                .read(escanerProvider.notifier)
                                .eliminarLinea(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente: Revisar contra inventario'),
              onPressed: lineas.isEmpty
                  ? null
                  : () => ref
                      .read(escanerProvider.notifier)
                      .analizarContraInventario(),
            ),
          ),
        )
      ],
    );
  }

  void _mostrarEditorLinea(
      BuildContext context, WidgetRef ref, int index, LineaAlbaran linea) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditorLineaSheet(
          linea: linea,
          onGuardar: (nueva) =>
              ref.read(escanerProvider.notifier).actualizarLinea(index, nueva),
        ),
      ),
    );
  }
}

// ============================================================
// VISTA DECIDIENDO (paso 2 → confirmar qué hacer con cada línea)
// ============================================================
class _VistaDecidiendo extends ConsumerWidget {
  final EscanerState state;
  const _VistaDecidiendo({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analizadas = state.lineasAnalizadas;

    final aFusionar =
        analizadas.where((a) => a.accion == AccionLinea.fusionar).length;
    final aCrear =
        analizadas.where((a) => a.accion == AccionLinea.crearNuevo).length;
    final aDescartar =
        analizadas.where((a) => a.accion == AccionLinea.descartar).length;

    return Column(
      children: [
        // Cabecera resumen
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: SGColors.primaryLight,
          child: Column(
            children: [
              Text(
                'Resumen',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$aFusionar a sumar  ·  $aCrear nuevos  ·  $aDescartar descartados',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: analizadas.length,
            itemBuilder: (context, index) => _TarjetaDecision(
              analizada: analizadas[index],
              onCambiarAccion: (accion) => ref
                  .read(escanerProvider.notifier)
                  .cambiarAccion(index, accion),
              onCambiarPrecio: (precio) => ref
                  .read(escanerProvider.notifier)
                  .cambiarPrecio(index, precio),
              onFusionarManual: () => _mostrarSelectorIngrediente(
                context,
                ref,
                index,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: ((aFusionar + aCrear) == 0 ||
                      state.estado == EstadoEscaner.guardando)
                  ? null
                  : () => ref.read(escanerProvider.notifier).confirmar(),
              child: state.estado == EstadoEscaner.guardando
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Guardando...'),
                      ],
                    )
                  : Text('Confirmar Albarán (${aFusionar + aCrear} cambios)'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarSelectorIngrediente(
      BuildContext context, WidgetRef ref, int index) async {
    final destino = await showModalBottomSheet<Ingrediente>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SelectorIngredienteSheet(),
    );
    if (destino != null) {
      ref
          .read(escanerProvider.notifier)
          .asignarFusionManual(index, destino);
    }
  }
}

// ============================================================
// TARJETA DE DECISIÓN POR LÍNEA
// ============================================================
class _TarjetaDecision extends StatefulWidget {
  final LineaAlbaranAnalizada analizada;
  final ValueChanged<AccionLinea> onCambiarAccion;
  final ValueChanged<double> onCambiarPrecio;
  final VoidCallback onFusionarManual;

  const _TarjetaDecision({
    required this.analizada,
    required this.onCambiarAccion,
    required this.onCambiarPrecio,
    required this.onFusionarManual,
  });

  @override
  State<_TarjetaDecision> createState() => _TarjetaDecisionState();
}

class _TarjetaDecisionState extends State<_TarjetaDecision> {
  late final TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.analizada.linea.precioUnitario;
    _precioCtrl = TextEditingController(text: p > 0 ? p.toString() : '');
  }

  @override
  void didUpdateWidget(covariant _TarjetaDecision old) {
    super.didUpdateWidget(old);
    // Si cambió el precio "desde fuera" (raro, pero puede pasar) sincronizar
    final nuevo = widget.analizada.linea.precioUnitario;
    final actual =
        double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0;
    if (nuevo != actual && !_precioCtrl.value.composing.isValid) {
      _precioCtrl.text = nuevo > 0 ? nuevo.toString() : '';
    }
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  void _emitirPrecio(String s) {
    final v = double.tryParse(s.replaceAll(',', '.')) ?? 0;
    widget.onCambiarPrecio(v);
  }

  @override
  Widget build(BuildContext context) {
    final analizada = widget.analizada;
    final linea = analizada.linea;
    final existente = analizada.ingredienteExistente;
    final esDescartado = analizada.accion == AccionLinea.descartar;
    final esCrearNuevo = analizada.accion == AccionLinea.crearNuevo;

    Color colorBanda;
    IconData icono;
    String etiqueta;

    switch (analizada.accion) {
      case AccionLinea.fusionar:
        colorBanda = Colors.blue;
        icono = Icons.merge_type;
        etiqueta = 'Sumar al existente';
        break;
      case AccionLinea.crearNuevo:
        colorBanda = Colors.green;
        icono = Icons.add_circle_outline;
        etiqueta = 'Crear nuevo';
        break;
      case AccionLinea.descartar:
        colorBanda = Colors.grey;
        icono = Icons.block;
        etiqueta = 'Descartar';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: esDescartado ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: colorBanda, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      linea.nombreProducto,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Text('${linea.cantidad} ${linea.unidad}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              if (analizada.accion == AccionLinea.fusionar && existente != null)
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    '→ ${existente.nombre} (stock actual: '
                    '${existente.stockActual} ${existente.unidad}'
                    '${existente.costePorUnidad > 0 ? ", "
                        "${existente.costePorUnidad.toStringAsFixed(2)} €/${existente.unidad}" : ""})',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              if (esCrearNuevo)
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    'No existe en el inventario',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 8),
              // Botones de acción
              Wrap(
                spacing: 6,
                children: [
                  _ChipAccion(
                    label: 'Sumar',
                    icon: Icons.merge_type,
                    selected: analizada.accion == AccionLinea.fusionar,
                    enabled: existente != null,
                    onTap: () {
                      if (existente != null) {
                        widget.onCambiarAccion(AccionLinea.fusionar);
                      } else {
                        widget.onFusionarManual();
                      }
                    },
                  ),
                  _ChipAccion(
                    label: 'Buscar...',
                    icon: Icons.search,
                    selected: false,
                    enabled: true,
                    onTap: widget.onFusionarManual,
                  ),
                  _ChipAccion(
                    label: 'Crear nuevo',
                    icon: Icons.add,
                    selected: analizada.accion == AccionLinea.crearNuevo,
                    enabled: true,
                    onTap: () => widget.onCambiarAccion(AccionLinea.crearNuevo),
                  ),
                  _ChipAccion(
                    label: 'Descartar',
                    icon: Icons.block,
                    selected: analizada.accion == AccionLinea.descartar,
                    enabled: true,
                    onTap: () => widget.onCambiarAccion(AccionLinea.descartar),
                  ),
                ],
              ),
              // Campo de precio: para crear nuevo o sumar (no para descartar)
              if (!esDescartado) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _precioCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          onChanged: _emitirPrecio,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: esCrearNuevo
                                ? 'Precio por ${linea.unidad}'
                                : 'Precio por ${linea.unidad} (este albarán)',
                            prefixText: '€ ',
                            hintText: '0.00',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total: ${_calcularTotal(linea).toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (analizada.accion == AccionLinea.fusionar &&
                    existente != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      _textoMediaPonderada(existente, linea),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
              if (etiqueta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Acción: $etiqueta',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorBanda,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _calcularTotal(LineaAlbaran linea) {
    final precio =
        double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0;
    return precio * linea.cantidad;
  }

  String _textoMediaPonderada(Ingrediente existente, LineaAlbaran linea) {
    final precioNuevo =
        double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0;
    final actual = existente.costePorUnidad;
    if (precioNuevo <= 0) {
      return actual > 0
          ? 'Coste actual: ${actual.toStringAsFixed(2)} €/${existente.unidad} (sin cambios)'
          : 'Sin coste registrado';
    }
    if (actual <= 0) {
      return 'Se establecerá coste: ${precioNuevo.toStringAsFixed(2)} €/${existente.unidad}';
    }
    if ((precioNuevo - actual).abs() < 0.005) {
      return 'Coste: ${actual.toStringAsFixed(2)} €/${existente.unidad} (sin cambios)';
    }
    return 'Coste: ${actual.toStringAsFixed(2)} → ${precioNuevo.toStringAsFixed(2)} €/${existente.unidad}';
  }
}

class _ChipAccion extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChipAccion({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon,
          size: 16,
          color: selected ? Colors.white : Colors.grey.shade700),
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.grey.shade800,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      backgroundColor: selected ? SGColors.primary : Colors.grey.shade100,
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================
// SELECTOR DE INGREDIENTE (para fusión manual)
// ============================================================
class _SelectorIngredienteSheet extends ConsumerStatefulWidget {
  const _SelectorIngredienteSheet();

  @override
  ConsumerState<_SelectorIngredienteSheet> createState() =>
      _SelectorIngredienteSheetState();
}

class _SelectorIngredienteSheetState
    extends ConsumerState<_SelectorIngredienteSheet> {
  final _searchCtrl = TextEditingController();
  List<Ingrediente> _resultados = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    setState(() => _cargando = true);
    try {
      final servicio = ref.read(ingredienteServiceProvider);
      final res = query.isEmpty
          ? await servicio.getAll()
          : await servicio.search(query);
      if (mounted) {
        setState(() {
          _resultados = res;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Selecciona ingrediente al que sumar',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _resultados.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView.builder(
                          itemCount: _resultados.length,
                          itemBuilder: (_, i) {
                            final ing = _resultados[i];
                            return ListTile(
                              title: Text(ing.nombre),
                              subtitle: Text(
                                  'Stock: ${ing.stockActual} ${ing.unidad}'),
                              onTap: () => Navigator.pop(context, ing),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EDITOR DE LÍNEA (paso 1)
// ============================================================
class _EditorLineaSheet extends StatefulWidget {
  final LineaAlbaran linea;
  final ValueChanged<LineaAlbaran> onGuardar;

  const _EditorLineaSheet({required this.linea, required this.onGuardar});

  @override
  State<_EditorLineaSheet> createState() => _EditorLineaSheetState();
}

class _EditorLineaSheetState extends State<_EditorLineaSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cantidadCtrl;
  String _unidad = 'kg';

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.linea.nombreProducto);
    _cantidadCtrl =
        TextEditingController(text: widget.linea.cantidad.toString());
    _unidad = widget.linea.unidad;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantidadCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unidad,
                  items: ['kg', 'L', 'ud']
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unidad = v ?? _unidad),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final cantidad = double.tryParse(
                        _cantidadCtrl.text.replaceAll(',', '.')) ??
                    widget.linea.cantidad;
                widget.onGuardar(widget.linea.copyWith(
                  nombreProducto: _nombreCtrl.text.trim(),
                  cantidad: cantidad,
                  unidad: _unidad,
                ));
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VISTA ERROR
// ============================================================
class _VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _VistaError({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}