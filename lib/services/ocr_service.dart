import 'dart:convert';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class LineaAlbaran {
  final String nombreProducto;
  final double cantidad;
  final String unidad;
  final double precioUnitario;

  LineaAlbaran({
    required this.nombreProducto,
    required this.cantidad,
    this.unidad = 'kg',
    this.precioUnitario = 0,
  });

  LineaAlbaran copyWith({
    String? nombreProducto,
    double? cantidad,
    String? unidad,
    double? precioUnitario,
  }) {
    return LineaAlbaran(
      nombreProducto: nombreProducto ?? this.nombreProducto,
      cantidad: cantidad ?? this.cantidad,
      unidad: unidad ?? this.unidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }
}

class ResultadoOCR {
  final List<LineaAlbaran> lineas;
  final String error;
  final String textoRaw;

  ResultadoOCR({this.lineas = const [], this.error = '', this.textoRaw = ''});
  bool get tieneError => error.isNotEmpty;
}

class OcrService {
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';

  Future<ResultadoOCR> escanearAlbaran(XFile imagen) async {
    final apiKey = dotenv.env['GOOGLE_CLOUD_VISION_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return ResultadoOCR(error: 'Falta GOOGLE_CLOUD_VISION_KEY en .env');
    }

    try {
      final bytes = await imagen.readAsBytes();
      developer.log('OCR: ${bytes.lengthInBytes} bytes', name: 'OCR');

      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'DOCUMENT_TEXT_DETECTION'}
              ],
              'imageContext': {
                'languageHints': ['es']
              }
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        developer.log('OCR HTTP ${response.statusCode}: ${response.body}',
            name: 'OCR');
        return ResultadoOCR(
          error: 'Error API ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = json['responses'] as List?;
      if (responses == null || responses.isEmpty) {
        return ResultadoOCR(error: 'Respuesta sin "responses"');
      }

      final primera = responses[0] as Map<String, dynamic>;
      if (primera.containsKey('error')) {
        return ResultadoOCR(error: 'Vision error: ${primera['error']}');
      }

      final annotation = primera['fullTextAnnotation'];
      if (annotation == null) {
        return ResultadoOCR(error: 'Sin texto detectado en la imagen');
      }

      final fullText = (annotation['text'] ?? '').toString();
      developer.log('OCR raw text:\n$fullText', name: 'OCR');

      if (fullText.isEmpty) {
        return ResultadoOCR(error: 'Texto vacío');
      }

      // Intentar primero el parser de Banco de Alimentos (formato conocido)
      var lineas = _parserBancoAlimentos(fullText);

      // Si no encuentra nada, fallback al parser genérico
      if (lineas.isEmpty) {
        developer.log('OCR: parser BdA no encontró líneas, probando genérico',
            name: 'OCR');
        lineas = _parserGenerico(fullText);
      }

      developer.log('OCR: ${lineas.length} líneas extraídas', name: 'OCR');

      return ResultadoOCR(
        lineas: lineas,
        textoRaw: fullText,
        error: lineas.isEmpty
            ? 'OCR funcionó pero no se reconoció ninguna línea de producto. Revisa el formato.'
            : '',
      );
    } catch (e, st) {
      developer.log('OCR excepción: $e\n$st', name: 'OCR');
      return ResultadoOCR(error: 'Excepción: $e');
    }
  }

  // ==========================================================================
  // PARSER POR BLOQUES (Banco de Alimentos)
  //
  // Vision devuelve cada celda de la tabla en su propia línea. Cada fila de
  // producto tiene este patrón:
  //
  //   [CÓDIGO 4 dígitos]      <- 1101, 0201, 1102, ...
  //   [NOMBRE PRODUCTO]       <- una o varias líneas (puede haber comas, ...)
  //   [UDS]                   <- entero
  //   [KG/L]                  <- decimal con coma (puede ser 0)
  //   [TOTAL]                 <- decimal con coma
  //
  // Estrategia: detectar códigos de 4 dígitos como "anclas" de fila, y
  // recoger las siguientes líneas hasta encontrar la siguiente ancla.
  // ==========================================================================
  List<LineaAlbaran> _parserBancoAlimentos(String texto) {
    final List<LineaAlbaran> resultado = [];
    final lineas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Un código de fila es exactamente 4 dígitos (1101, 0201, etc.)
    final regexCodigo = RegExp(r'^\d{4}$');
    // Un decimal con coma típico del albarán (18,000 / 0,800 / 10,500)
    final regexDecimal = RegExp(r'^\d{1,4},\d{1,3}$');
    // Un entero corto típico de "Uds" (1, 2, 14, 100)
    final regexEntero = RegExp(r'^\d{1,4}$');

    // Encontrar índices de todos los códigos de fila
    final indicesCodigos = <int>[];
    for (var i = 0; i < lineas.length; i++) {
      if (regexCodigo.hasMatch(lineas[i])) {
        indicesCodigos.add(i);
      }
    }

    if (indicesCodigos.isEmpty) return [];

    // Localizar el final de la tabla: la línea "Total:" o "Total" suelta
    int finTabla = lineas.length;
    for (var i = indicesCodigos.last; i < lineas.length; i++) {
      if (RegExp(r'^total\s*:?$', caseSensitive: false)
          .hasMatch(lineas[i])) {
        finTabla = i;
        break;
      }
    }

    // Para cada código, el bloque va desde su índice hasta el siguiente código
    // (o hasta el final de la tabla si es la última fila)
    for (var i = 0; i < indicesCodigos.length; i++) {
      final inicio = indicesCodigos[i];
      final fin = (i + 1 < indicesCodigos.length)
          ? indicesCodigos[i + 1]
          : finTabla;

      final bloque = lineas.sublist(inicio, fin);
      if (bloque.length < 4) continue; // no hay datos suficientes

      // Localizar líneas del bloque que son números
      final numeros = <int>[];
      for (var j = 1; j < bloque.length; j++) {
        if (regexDecimal.hasMatch(bloque[j]) ||
            regexEntero.hasMatch(bloque[j])) {
          numeros.add(j);
        }
      }

      if (numeros.length < 3) continue; // formato inesperado, saltar

      // Los 3 últimos números del bloque son: uds, kgs, total (en ese orden)
      final idxUds = numeros[numeros.length - 3];
      final idxKgs = numeros[numeros.length - 2];

      // El nombre es todas las líneas entre el código y idxUds
      final nombrePartes = bloque.sublist(1, idxUds);
      final nombre = _limpiarNombre(nombrePartes.join(' '));

      final uds = _aDouble(bloque[idxUds]);
      final kgs = _aDouble(bloque[idxKgs]);

      if (nombre.length < 2) continue;

      resultado.add(LineaAlbaran(
        nombreProducto: nombre,
        // Si hay kgs > 0 lo usamos, si no, la cantidad son unidades
        cantidad: kgs > 0 ? kgs : uds,
        unidad: kgs > 0 ? 'kg' : 'ud',
      ));
    }

    return resultado;
  }

  // ==========================================================================
  // PARSER GENÉRICO (fallback para otros formatos)
  // ==========================================================================
  List<LineaAlbaran> _parserGenerico(String texto) {
    final List<LineaAlbaran> resultado = [];
    final regexFila = RegExp(
      r'^(.+?)\s+(\d{1,4}(?:[.,]\d{1,3})?)\s*(kg|l|ud|uds)?$',
      caseSensitive: false,
    );

    for (var raw in texto.split('\n')) {
      final l = raw.trim();
      if (l.isEmpty || _esBasura(l)) continue;

      final m = regexFila.firstMatch(l);
      if (m == null) continue;

      final nombre = _limpiarNombre(m.group(1)!);
      final cant = _aDouble(m.group(2)!);
      final unidad = (m.group(3) ?? 'ud').toLowerCase();

      if (nombre.length > 2 && cant > 0 && cant < 100000) {
        resultado.add(LineaAlbaran(
          nombreProducto: nombre,
          cantidad: cant,
          unidad: unidad.startsWith('u') ? 'ud' : unidad,
        ));
      }
    }
    return resultado;
  }

  bool _esBasura(String t) {
    final low = t.toLowerCase();
    if (low.length < 4) return true;
    const palabrasBasura = [
      'total', 'fecha', 'almacén', 'almacen', 'origen', 'proyecto',
      'código', 'codigo', 'alimento', 'banco de alimentos', 'cif',
      'tlf', 'tel:', 'albarán', 'albaran', 'entrada', 'polígono',
      'poligono', 'industrial',
    ];
    for (final p in palabrasBasura) {
      if (low.contains(p)) return true;
    }
    return false;
  }

  String _limpiarNombre(String n) {
    return n
        .replaceFirst(RegExp(r'^\d{2,}\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.…]+$'), '')
        .trim()
        .toUpperCase();
  }

  double _aDouble(String s) {
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());