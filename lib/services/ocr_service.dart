import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ============================================================
// MODELO — Línea detectada en el albarán
// ============================================================
class LineaAlbaran {
  final String nombreProducto;
  final double cantidad;
  final String unidad;
  final double precioUnitario;
  final bool confirmada;

  LineaAlbaran({
    required this.nombreProducto,
    required this.cantidad,
    this.unidad = 'kg',
    this.precioUnitario = 0,
    this.confirmada = false,
  });

  LineaAlbaran copyWith({
    String? nombreProducto,
    double? cantidad,
    String? unidad,
    double? precioUnitario,
    bool? confirmada,
  }) {
    return LineaAlbaran(
      nombreProducto: nombreProducto ?? this.nombreProducto,
      cantidad: cantidad ?? this.cantidad,
      unidad: unidad ?? this.unidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      confirmada: confirmada ?? this.confirmada,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre_producto': nombreProducto,
        'cantidad': cantidad,
        'unidad': unidad,
        'precio_unitario': precioUnitario,
      };
}

// ============================================================
// RESULTADO DEL ESCANEO
// ============================================================
class ResultadoOCR {
  final String textoRaw;
  final List<LineaAlbaran> lineas;
  final String? proveedor;
  final DateTime? fechaAlbaran;
  final String? numeroAlbaran;
  final String error;

  ResultadoOCR({
    this.textoRaw = '',
    this.lineas = const [],
    this.proveedor,
    this.fechaAlbaran,
    this.numeroAlbaran,
    this.error = '',
  });

  bool get tieneError => error.isNotEmpty;
  bool get tieneLineas => lineas.isNotEmpty;
}

// ============================================================
// OCR SERVICE — Llama a Google Cloud Vision y parsea el texto
// ============================================================
class OcrService {
  static const _visionEndpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  /// Envía la imagen a Cloud Vision y devuelve el resultado parseado
  Future<ResultadoOCR> escanearAlbaran(File imagen) async {
    final apiKey = dotenv.env['GOOGLE_CLOUD_VISION_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return ResultadoOCR(
          error: 'GOOGLE_CLOUD_VISION_KEY no configurada en .env');
    }

    try {
      // 1. Codificar imagen en base64
      final bytes = await imagen.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Llamada a la API de Cloud Vision
      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('$_visionEndpoint?key=$apiKey'));
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1}
            ],
            'imageContext': {
              'languageHints': ['es', 'en']
            }
          }
        ]
      });

      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return ResultadoOCR(
            error: 'Error Cloud Vision (${response.statusCode})');
      }

      // 3. Extraer texto completo
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final responses = json['responses'] as List?;
      if (responses == null || responses.isEmpty) {
        return ResultadoOCR(error: 'Respuesta vacía de Cloud Vision');
      }

      final fullText =
          responses[0]['fullTextAnnotation']?['text'] as String? ?? '';
      if (fullText.isEmpty) {
        return ResultadoOCR(
            error:
                'No se detectó texto en la imagen. Asegúrate de que la imagen sea nítida y bien iluminada.');
      }

      // 4. Parsear el texto extraído
      return _parsearTextoAlbaran(fullText);
    } catch (e) {
      return ResultadoOCR(error: 'Error al procesar la imagen: $e');
    }
  }

  // ----------------------------------------------------------
  // PARSER — extrae líneas de producto del texto OCR
  // ----------------------------------------------------------
  ResultadoOCR _parsearTextoAlbaran(String texto) {
    final lineas = <LineaAlbaran>[];
    final lineasTexto = texto.split('\n');

    String? proveedor;
    DateTime? fechaAlbaran;
    String? numeroAlbaran;

    // Patrones de extracción
    final regexFecha = RegExp(
        r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})');
    final regexNumAlbaran = RegExp(
        r'(?:albar[aá]n|albaran|n[uú]m\.?|ref\.?)[:\s#]*([A-Z0-9\-\/]+)',
        caseSensitive: false);
    // Patrón para líneas de producto:
    // Nombre (texto), cantidad (número), unidad (kg/L/ud...), precio (número con €/,/.)
    final regexLinea = RegExp(
        r'^(.{3,40}?)\s+([\d]+[,\.]?[\d]*)\s*(kg|g|l|lt|litro|litros|ud|uds|und|unid|caja|cajas|bote|botes|bolsa|bolsas|saco|sacos)?\s*([\d]+[,\.]?[\d]*)?',
        caseSensitive: false,
        multiLine: true);

    for (int i = 0; i < lineasTexto.length; i++) {
      final linea = lineasTexto[i].trim();
      if (linea.isEmpty) continue;

      // Detectar número de albarán
      if (numeroAlbaran == null) {
        final matchNum = regexNumAlbaran.firstMatch(linea);
        if (matchNum != null) {
          numeroAlbaran = matchNum.group(1)?.trim();
          continue;
        }
      }

      // Detectar fecha
      if (fechaAlbaran == null) {
        final matchFecha = regexFecha.firstMatch(linea);
        if (matchFecha != null) {
          try {
            int anyo = int.parse(matchFecha.group(3)!);
            if (anyo < 100) anyo += 2000;
            fechaAlbaran = DateTime(
              anyo,
              int.parse(matchFecha.group(2)!),
              int.parse(matchFecha.group(1)!),
            );
          } catch (_) {}
          continue;
        }
      }

      // Detectar proveedor (típicamente las primeras líneas de texto libre)
      if (proveedor == null && i < 5 && linea.length > 3) {
        final esNumero = RegExp(r'^[\d\s€.,]+$').hasMatch(linea);
        if (!esNumero) {
          proveedor = linea;
          continue;
        }
      }

      // Detectar líneas de producto
      final matchLinea = regexLinea.firstMatch(linea);
      if (matchLinea != null) {
        final nombreRaw = matchLinea.group(1)?.trim() ?? '';
        final cantidadStr =
            (matchLinea.group(2) ?? '0').replaceAll(',', '.');
        final unidadRaw = matchLinea.group(3)?.toLowerCase() ?? 'ud';
        final precioStr =
            (matchLinea.group(4) ?? '0').replaceAll(',', '.');

        // Filtrar líneas que claramente no son productos
        if (_esLineaDescartable(nombreRaw)) continue;

        final cantidad = double.tryParse(cantidadStr) ?? 0;
        if (cantidad <= 0) continue;

        lineas.add(LineaAlbaran(
          nombreProducto: _normalizarNombre(nombreRaw),
          cantidad: cantidad,
          unidad: _normalizarUnidad(unidadRaw),
          precioUnitario: double.tryParse(precioStr) ?? 0,
        ));
      }
    }

    return ResultadoOCR(
      textoRaw: texto,
      lineas: lineas,
      proveedor: proveedor,
      fechaAlbaran: fechaAlbaran,
      numeroAlbaran: numeroAlbaran,
    );
  }

  bool _esLineaDescartable(String texto) {
    final palabrasDescartables = [
      'total', 'subtotal', 'iva', 'base imponible', 'importe',
      'fecha', 'albarán', 'albaran', 'dirección', 'cif', 'nif',
      'página', 'pagina', 'teléfono', 'fax', 'email',
    ];
    final textoLower = texto.toLowerCase();
    return palabrasDescartables.any((p) => textoLower.contains(p));
  }

  String _normalizarNombre(String nombre) {
    // Capitaliza primera letra, elimina caracteres extraños
    if (nombre.isEmpty) return nombre;
    return nombre[0].toUpperCase() + nombre.substring(1).toLowerCase();
  }

  String _normalizarUnidad(String unidad) {
    return switch (unidad.toLowerCase()) {
      'kg' || 'kilo' || 'kilos' => 'kg',
      'g' || 'gr' || 'gramo' || 'gramos' => 'g',
      'l' || 'lt' || 'litro' || 'litros' => 'L',
      'caja' || 'cajas' => 'caja',
      'bote' || 'botes' => 'bote',
      'bolsa' || 'bolsas' => 'bolsa',
      'saco' || 'sacos' => 'saco',
      _ => 'ud',
    };
  }
}

// ============================================================
// PROVIDER
// ============================================================
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());