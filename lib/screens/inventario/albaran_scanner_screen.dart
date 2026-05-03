import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/ocr_service.dart';
import '../../services/pedido_service.dart';
import '../../services/ingrediente_service.dart';

// ============================================================
// ESTADO DEL ESCÁNER
// ============================================================
enum EstadoEscaner { inicial, procesando, resultado, error }

class EscanerState {
  final EstadoEscaner estado;
  final File? imagen;
  final ResultadoOCR? resultado;
  final List<LineaAlbaran> lineasEditadas;

  const EscanerState({
    this.estado = EstadoEscaner.inicial,
    this.imagen,
    this.resultado,
    this.lineasEditadas = const [],
  });

  EscanerState copyWith({
    EstadoEscaner? estado,
    File? imagen,
    ResultadoOCR? resultado,
    List<LineaAlbaran>? lineasEditadas,
  }) =>
      EscanerState(
        estado: estado ?? this.estado,
        imagen: imagen ?? this.imagen,
        resultado: resultado ?? this.resultado,
        lineasEditadas: lineasEditadas ?? this.lineasEditadas,
      );
}

// ============================================================
// NOTIFIER
// ============================================================
class EscanerNotifier extends StateNotifier<EscanerState> {
  final OcrService _ocrService;

  EscanerNotifier(this._ocrService) : super(const EscanerState());

  Future<void> tomarFoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    await _procesarImagen(File(picked.path));
  }

  Future<void> seleccionarGaleria() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    await _procesarImagen(File(picked.path));
  }

  Future<void> _procesarImagen(File imagen) async {
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

  void reiniciar() {
    state = const EscanerState();
  }
}

final escanerProvider =
    StateNotifierProvider.autoDispose<EscanerNotifier, EscanerState>((ref) {
  return EscanerNotifier(ref.read(ocrServiceProvider));
});

// ============================================================
// PANTALLA PRINCIPAL DEL ESCÁNER
// ============================================================
class AlbaranScannerScreen extends ConsumerWidget {
  const AlbaranScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(escanerProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        title: const Text('Escanear Albarán'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.estado == EstadoEscaner.resultado)
            TextButton(
              onPressed: () => ref.read(escanerProvider.notifier).reiniciar(),
              child: const Text('Nuevo'),
            ),
        ],
      ),
      body: switch (state.estado) {
        EstadoEscaner.inicial => _VistaInicial(
            onCamara: () =>
                ref.read(escanerProvider.notifier).tomarFoto(),
            onGaleria: () =>
                ref.read(escanerProvider.notifier).seleccionarGaleria(),
          ),
        EstadoEscaner.procesando => _VistaProcesando(imagen: state.imagen),
        EstadoEscaner.resultado => _VistaResultado(state: state),
        EstadoEscaner.error => _VistaError(
            mensaje: state.resultado?.error ?? 'Error desconocido',
            onReintentar: () =>
                ref.read(escanerProvider.notifier).reiniciar(),
          ),
      },
    );
  }
}

// ============================================================
// VISTA INICIAL — Elegir fuente de imagen
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
          const SizedBox(height: 12),
          Text(
            'Fotografía el albarán de tu proveedor y el sistema detectará automáticamente los productos, cantidades y precios.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: SGColors.textSecondary),
          ),
          const SizedBox(height: 48),
          // Botón cámara
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
          // Botón galería
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SGColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: SGColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Para mejores resultados: buena iluminación, imagen centrada y enfocada.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SGColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VISTA PROCESANDO — Spinner con preview de imagen
// ============================================================
class _VistaProcesando extends StatelessWidget {
  final File? imagen;

  const _VistaProcesando({this.imagen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (imagen != null)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: FileImage(imagen!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(color: SGColors.primary),
              const SizedBox(height: 20),
              Text(
                'Analizando albarán...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SGColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Google Cloud Vision está extrayendo el texto',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: SGColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// VISTA RESULTADO — Lista editable de líneas detectadas
// ============================================================
class _VistaResultado extends ConsumerWidget {
  final EscanerState state;

  const _VistaResultado({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = state.resultado!;
    final lineas = state.lineasEditadas;

    return Column(
      children: [
        // Cabecera resumen
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SGColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SGColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: SGColors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${lineas.length} productos detectados',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: SGColors.green),
                  ),
                ],
              ),
              if (resultado.proveedor != null) ...[
                const SizedBox(height: 8),
                Text('Proveedor: ${resultado.proveedor}',
                    style: const TextStyle(
                        fontSize: 13, color: SGColors.textSecondary)),
              ],
              if (resultado.numeroAlbaran != null) ...[
                const SizedBox(height: 4),
                Text('Albarán nº: ${resultado.numeroAlbaran}',
                    style: const TextStyle(
                        fontSize: 13, color: SGColors.textSecondary)),
              ],
            ],
          ),
        ),
        // Aviso si hay pocas líneas
        if (lineas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No se detectaron líneas de producto. Revisa la imagen o añade manualmente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SGColors.textSecondary),
            ),
          ),
        // Lista de líneas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lineas.length,
            itemBuilder: (context, index) => _LineaCard(
              linea: lineas[index],
              index: index,
              onEditar: () => _mostrarEditorLinea(context, ref, index, lineas[index]),
              onEliminar: () =>
                  ref.read(escanerProvider.notifier).eliminarLinea(index),
            ),
          ),
        ),
        // Botones de acción
        _BarraAcciones(
          lineas: lineas,
          proveedor: resultado.proveedor,
          onAgregarLinea: () =>
              ref.read(escanerProvider.notifier).agregarLinea(),
        ),
      ],
    );
  }

  void _mostrarEditorLinea(
      BuildContext context, WidgetRef ref, int index, LineaAlbaran linea) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditorLineaSheet(
        linea: linea,
        onGuardar: (lineaEditada) {
          ref.read(escanerProvider.notifier).actualizarLinea(index, lineaEditada);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ============================================================
// CARD DE CADA LÍNEA DETECTADA
// ============================================================
class _LineaCard extends StatelessWidget {
  final LineaAlbaran linea;
  final int index;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _LineaCard({
    required this.linea,
    required this.index,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SGColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: SGColors.primaryLight,
          child: Text('${index + 1}',
              style: const TextStyle(
                  color: SGColors.primary, fontWeight: FontWeight.w700)),
        ),
        title: Text(
          linea.nombreProducto.isNotEmpty
              ? linea.nombreProducto
              : 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${linea.cantidad} ${linea.unidad}  •  ${linea.precioUnitario.toStringAsFixed(2)} €/ud',
          style: const TextStyle(color: SGColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: SGColors.primary, size: 20),
              onPressed: onEditar,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: SGColors.red, size: 20),
              onPressed: onEliminar,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BARRA DE ACCIONES INFERIOR
// ============================================================
class _BarraAcciones extends ConsumerWidget {
  final List<LineaAlbaran> lineas;
  final String? proveedor;
  final VoidCallback onAgregarLinea;

  const _BarraAcciones({
    required this.lineas,
    this.proveedor,
    required this.onAgregarLinea,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: SGColors.surface,
        border: const Border(top: BorderSide(color: SGColors.border)),
      ),
      child: Row(
        children: [
          // Botón añadir línea manual
          OutlinedButton.icon(
            onPressed: onAgregarLinea,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SGColors.primary,
              side: const BorderSide(color: SGColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          // Botón confirmar e importar
          Expanded(
            child: ElevatedButton.icon(
              onPressed: lineas.isEmpty
                  ? null
                  : () => _confirmarImportacion(context, ref),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Importar al Inventario'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarImportacion(
      BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Importar mercancía'),
        content: Text(
            '¿Crear un pedido con ${lineas.length} productos y actualizar el inventario?\n\n'
            'El stock de cada producto se incrementará con la cantidad indicada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar')),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    // Crear pedido con las líneas escaneadas
    try {
      final pedidoService = ref.read(pedidoServiceProvider);
      final ingredienteService = ref.read(ingredienteServiceProvider);

      // 1. Crear el pedido en estado "recibido" (ya está en almacén)
      final pedido = Pedido(
        proveedor: proveedor ?? 'Proveedor (OCR)',
        estado: 'recibido',
        notas: 'Importado automáticamente desde albarán escaneado',
        fechaRecibido: DateTime.now(),
      );
      final pedidoCreado = await pedidoService.create(pedido);

      // 2. Crear las líneas del pedido
      for (final linea in lineas) {
        final lineaPedido = PedidoLinea(
          pedidoId: pedidoCreado.id,
          nombreProducto: linea.nombreProducto,
          cantidad: linea.cantidad,
          unidad: linea.unidad,
          precioUnitario: linea.precioUnitario,
          recibido: true,
        );
        await pedidoService.addLinea(lineaPedido);

        // 3. Actualizar stock si existe el ingrediente con ese nombre
        final ingredientes = await ingredienteService.search(linea.nombreProducto);
        if (ingredientes.isNotEmpty) {
          final ing = ingredientes.first;
          final actualizado = Ingrediente(
            nombre: ing.nombre,
            categoria: ing.categoria,
            stockActual: ing.stockActual + linea.cantidad,
            stockMinimo: ing.stockMinimo,
            unidad: ing.unidad,
            costePorUnidad: linea.precioUnitario > 0
                ? linea.precioUnitario
                : ing.costePorUnidad,
            proveedor: proveedor ?? ing.proveedor,
            fechaCaducidad: ing.fechaCaducidad,
            notas: ing.notas,
          );
          await ingredienteService.update(ing.id!, actualizado);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ ${lineas.length} productos importados correctamente'),
            backgroundColor: SGColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
            backgroundColor: SGColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ============================================================
// EDITOR DE LÍNEA (Bottom Sheet)
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
  late final TextEditingController _precioCtrl;
  String _unidad = 'kg';

  static const _unidades = [
    'kg', 'g', 'L', 'ud', 'caja', 'bote', 'bolsa', 'saco'
  ];

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.linea.nombreProducto);
    _cantidadCtrl =
        TextEditingController(text: widget.linea.cantidad.toString());
    _precioCtrl =
        TextEditingController(text: widget.linea.precioUnitario.toString());
    _unidad = widget.linea.unidad;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: SGColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Editar producto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 20),
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del producto'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantidadCtrl,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unidad,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                  items: _unidades
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unidad = v ?? _unidad),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precioCtrl,
            decoration: const InputDecoration(
              labelText: 'Precio unitario (€)',
              prefixText: '€ ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                widget.onGuardar(widget.linea.copyWith(
                  nombreProducto: _nombreCtrl.text.trim(),
                  cantidad:
                      double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ??
                          widget.linea.cantidad,
                  unidad: _unidad,
                  precioUnitario:
                      double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ??
                          widget.linea.precioUnitario,
                ));
              },
              child: const Text('Guardar cambios'),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: SGColors.red, size: 72),
          const SizedBox(height: 24),
          Text('No se pudo procesar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 12),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SGColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }
}