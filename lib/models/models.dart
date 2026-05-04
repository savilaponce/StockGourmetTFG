/// Modelos de datos para StockGourmet
/// Cada modelo tiene fromJson/toJson para serialización con Supabase
library;

// ============================================================
// RESTAURANTE
// ============================================================
class Restaurante {
  final String id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String planSuscripcion;
  final bool suscripcionActiva;
  final int maxUsuarios;
  final DateTime createdAt;

  Restaurante({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.email,
    this.planSuscripcion = 'free',
    this.suscripcionActiva = true,
    this.maxUsuarios = 3,
    required this.createdAt,
  });

  factory Restaurante.fromJson(Map<String, dynamic> json) => Restaurante(
    id: json['id'],
    nombre: json['nombre'],
    direccion: json['direccion'],
    telefono: json['telefono'],
    email: json['email'],
    planSuscripcion: json['plan_suscripcion'] ?? 'free',
    suscripcionActiva: json['suscripcion_activa'] ?? true,
    maxUsuarios: json['max_usuarios'] ?? 3,
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'direccion': direccion,
    'telefono': telefono,
    'email': email,
    'plan_suscripcion': planSuscripcion,
  };
}

// ============================================================
// PROFILE (Usuario)
// ============================================================
class Profile {
  final String id;
  final String restauranteId;
  final String nombreCompleto;
  final String rol;
  final String? avatarUrl;
  final bool activo;

  Profile({
    required this.id,
    required this.restauranteId,
    required this.nombreCompleto,
    this.rol = 'staff',
    this.avatarUrl,
    this.activo = true,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'],
    restauranteId: json['restaurante_id'],
    nombreCompleto: json['nombre_completo'],
    rol: json['rol'] ?? 'staff',
    avatarUrl: json['avatar_url'],
    activo: json['activo'] ?? true,
  );

  bool get isAdmin => rol == 'admin';
  bool get isChef => rol == 'chef';
  bool get canEdit => rol == 'admin' || rol == 'chef';
}

// ============================================================
// INGREDIENTE
// ============================================================
class Ingrediente {
  final String? id;
  final String? restauranteId;
  final String nombre;
  final String categoria;
  final double stockActual;
  final double stockMinimo;
  final String unidad;
  final double costePorUnidad;
  final String? proveedor;
  final DateTime? fechaCaducidad;
  final String? notas;
  final bool activo;

  Ingrediente({
    this.id,
    this.restauranteId,
    required this.nombre,
    this.categoria = 'otros',
    this.stockActual = 0,
    this.stockMinimo = 0,
    this.unidad = 'kg',
    this.costePorUnidad = 0,
    this.proveedor,
    this.fechaCaducidad,
    this.notas,
    this.activo = true,
  });

  factory Ingrediente.fromJson(Map<String, dynamic> json) => Ingrediente(
    id: json['id'],
    restauranteId: json['restaurante_id'],
    nombre: json['nombre'],
    categoria: json['categoria'] ?? 'otros',
    stockActual: (json['stock_actual'] as num).toDouble(),
    stockMinimo: (json['stock_minimo'] as num?)?.toDouble() ?? 0,
    unidad: json['unidad'] ?? 'kg',
    costePorUnidad: (json['coste_por_unidad'] as num).toDouble(),
    proveedor: json['proveedor'],
    fechaCaducidad: json['fecha_caducidad'] != null
        ? DateTime.parse(json['fecha_caducidad'])
        : null,
    notas: json['notas'],
    activo: json['activo'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'categoria': categoria,
    'stock_actual': stockActual,
    'stock_minimo': stockMinimo,
    'unidad': unidad,
    'coste_por_unidad': costePorUnidad,
    'proveedor': proveedor,
    'fecha_caducidad': fechaCaducidad?.toIso8601String().split('T').first,
    'notas': notas,
    'activo': activo,
  };

  /// ¿Está próximo a caducar? (dentro de 7 días)
  bool get proximoACaducar {
    if (fechaCaducidad == null) return false;
    final dias = fechaCaducidad!.difference(DateTime.now()).inDays;
    return dias >= 0 && dias <= 7;
  }

  /// ¿Ya caducó?
  bool get caducado {
    if (fechaCaducidad == null) return false;
    return fechaCaducidad!.isBefore(DateTime.now());
  }

  /// Días restantes hasta caducidad
  int? get diasRestantes {
    if (fechaCaducidad == null) return null;
    return fechaCaducidad!.difference(DateTime.now()).inDays;
  }

  /// Stock está bajo el mínimo
  bool get stockBajo => stockActual <= stockMinimo && stockMinimo > 0;
}

// ============================================================
// PLATO
// ============================================================
class Plato {
  final String? id;
  final String? restauranteId;
  final String nombre;
  final String? descripcion;
  final String categoria;
  final double? precioVenta;
  final String? imagenUrl;
  final bool activo;

  // Campos calculados (de la vista v_plato_costes)
  final double? costeTotal;
  final double? beneficioBruto;
  final double? margenPorcentual;
  final int? numIngredientes;

  Plato({
    this.id,
    this.restauranteId,
    required this.nombre,
    this.descripcion,
    this.categoria = 'principal',
    this.precioVenta,
    this.imagenUrl,
    this.activo = true,
    this.costeTotal,
    this.beneficioBruto,
    this.margenPorcentual,
    this.numIngredientes,
  });

  factory Plato.fromJson(Map<String, dynamic> json) => Plato(
    id: json['id'] ?? json['plato_id'],
    restauranteId: json['restaurante_id'],
    nombre: json['nombre'],
    descripcion: json['descripcion'],
    categoria: json['categoria'] ?? 'principal',
    precioVenta: (json['precio_venta'] as num?)?.toDouble(),
    imagenUrl: json['imagen_url'],
    activo: json['activo'] ?? true,
    costeTotal: (json['coste_total'] as num?)?.toDouble(),
    beneficioBruto: (json['beneficio_bruto'] as num?)?.toDouble(),
    margenPorcentual: (json['margen_porcentual'] as num?)?.toDouble(),
    numIngredientes: json['num_ingredientes'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'categoria': categoria,
    'precio_venta': precioVenta,
    'imagen_url': imagenUrl,
    'activo': activo,
  };

  /// Color indicador según el margen
  bool get margenBueno => (margenPorcentual ?? 0) >= 65;
  bool get margenMedio => (margenPorcentual ?? 0) >= 40 && (margenPorcentual ?? 0) < 65;
  bool get margenBajo => (margenPorcentual ?? 0) < 40;
}

// ============================================================
// PLATO_INGREDIENTE (relación N:M)
// ============================================================
class PlatoIngrediente {
  final String? id;
  final String platoId;
  final String ingredienteId;
  final double cantidad;

  // Datos del ingrediente (join)
  final String? nombreIngrediente;
  final String? unidadIngrediente;
  final double? costeUnitario;

  PlatoIngrediente({
    this.id,
    required this.platoId,
    required this.ingredienteId,
    required this.cantidad,
    this.nombreIngrediente,
    this.unidadIngrediente,
    this.costeUnitario,
  });

  factory PlatoIngrediente.fromJson(Map<String, dynamic> json) {
    // Supabase devuelve el join como un objeto anidado
    final ingrediente = json['ingredientes'] as Map<String, dynamic>?;

    return PlatoIngrediente(
      id: json['id'],
      platoId: json['plato_id'],
      ingredienteId: json['ingrediente_id'],
      cantidad: (json['cantidad'] as num).toDouble(),
      nombreIngrediente: ingrediente?['nombre'],
      unidadIngrediente: ingrediente?['unidad'],
      costeUnitario: (ingrediente?['coste_por_unidad'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'plato_id': platoId,
    'ingrediente_id': ingredienteId,
    'cantidad': cantidad,
  };

  /// Coste de esta línea (cantidad × coste unitario)
  double get costeLinea => cantidad * (costeUnitario ?? 0);
}

// ============================================================
// PEDIDO
// ============================================================
class Pedido {
  final String? id;
  final String? restauranteId;
  final String proveedor;
  final String estado; // pendiente, enviado, recibido, cancelado
  final String? notas;
  final DateTime fechaPedido;
  final DateTime? fechaEntregaEstimada;
  final DateTime? fechaRecibido;
  final double costeTotal;
  final int? numLineas;

  Pedido({
    this.id,
    this.restauranteId,
    required this.proveedor,
    this.estado = 'pendiente',
    this.notas,
    DateTime? fechaPedido,
    this.fechaEntregaEstimada,
    this.fechaRecibido,
    this.costeTotal = 0,
    this.numLineas,
  }) : fechaPedido = fechaPedido ?? DateTime.now();

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
    id: json['id'],
    restauranteId: json['restaurante_id'],
    proveedor: json['proveedor'] ?? '',
    estado: json['estado'] ?? 'pendiente',
    notas: json['notas'],
    fechaPedido: DateTime.parse(json['fecha_pedido'] ?? json['created_at']),
    fechaEntregaEstimada: json['fecha_entrega_estimada'] != null
        ? DateTime.parse(json['fecha_entrega_estimada'])
        : null,
    fechaRecibido: json['fecha_recibido'] != null
        ? DateTime.parse(json['fecha_recibido'])
        : null,
    costeTotal: (json['coste_total'] as num?)?.toDouble() ?? 0,
    numLineas: json['num_lineas'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'proveedor': proveedor,
    'estado': estado,
    'notas': notas,
    'fecha_entrega_estimada': fechaEntregaEstimada?.toIso8601String().split('T').first,
  };

  bool get isPendiente => estado == 'pendiente';
  bool get isEnviado => estado == 'enviado';
  bool get isRecibido => estado == 'recibido';
  bool get isCancelado => estado == 'cancelado';

  String get estadoLabel => switch (estado) {
    'pendiente' => 'Pendiente',
    'enviado' => 'Enviado',
    'recibido' => 'Recibido',
    'cancelado' => 'Cancelado',
    _ => estado,
  };
}

// ============================================================
// PEDIDO LINEA
// ============================================================
class PedidoLinea {
  final String? id;
  final String? pedidoId;
  final String? ingredienteId;
  final String nombreProducto;
  final double cantidad;
  final String unidad;
  final double precioUnitario;
  final double? precioTotal;
  final bool recibido;

  PedidoLinea({
    this.id,
    this.pedidoId,
    this.ingredienteId,
    required this.nombreProducto,
    required this.cantidad,
    this.unidad = 'kg',
    this.precioUnitario = 0,
    this.precioTotal,
    this.recibido = false,
  });

  factory PedidoLinea.fromJson(Map<String, dynamic> json) => PedidoLinea(
    id: json['id'],
    pedidoId: json['pedido_id'],
    ingredienteId: json['ingrediente_id'],
    nombreProducto: json['nombre_producto'] ?? '',
    cantidad: (json['cantidad'] as num).toDouble(),
    unidad: json['unidad'] ?? 'kg',
    precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0,
    precioTotal: (json['precio_total'] as num?)?.toDouble(),
    recibido: json['recibido'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'pedido_id': pedidoId,
    'ingrediente_id': ingredienteId,
    'nombre_producto': nombreProducto,
    'cantidad': cantidad,
    'unidad': unidad,
    'precio_unitario': precioUnitario,
  };

  double get costeLinea => cantidad * precioUnitario;
}
// ============================================================
// PROVEEDOR
// Añadir al FINAL de lib/models/models.dart
// ============================================================
class Proveedor {
  final String? id;
  final String? restauranteId;
  final String nombre;
  final String? contacto;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final bool activo;

  Proveedor({
    this.id,
    this.restauranteId,
    required this.nombre,
    this.contacto,
    this.telefono,
    this.email,
    this.direccion,
    this.notas,
    this.activo = true,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) => Proveedor(
    id: json['id'],
    restauranteId: json['restaurante_id'],
    nombre: json['nombre'],
    contacto: json['contacto'],
    telefono: json['telefono'],
    email: json['email'],
    direccion: json['direccion'],
    notas: json['notas'],
    activo: json['activo'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'contacto': contacto,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'notas': notas,
    'activo': activo,
  };
}

// ============================================================
// ALERTA — fila de la vista v_alertas
// ============================================================
enum TipoAlerta {
  caducidadVencida,
  caducidadCritica,
  caducidadProxima,
  stockCritico,
  stockBajo,
  desconocido,
}

extension TipoAlertaX on TipoAlerta {
  static TipoAlerta fromString(String? raw) {
    switch (raw) {
      case 'caducidad_vencida':
        return TipoAlerta.caducidadVencida;
      case 'caducidad_critica':
        return TipoAlerta.caducidadCritica;
      case 'caducidad_proxima':
        return TipoAlerta.caducidadProxima;
      case 'stock_critico':
        return TipoAlerta.stockCritico;
      case 'stock_bajo':
        return TipoAlerta.stockBajo;
      default:
        return TipoAlerta.desconocido;
    }
  }

  bool get esCaducidad =>
      this == TipoAlerta.caducidadVencida ||
      this == TipoAlerta.caducidadCritica ||
      this == TipoAlerta.caducidadProxima;

  bool get esStock =>
      this == TipoAlerta.stockCritico || this == TipoAlerta.stockBajo;
}

class Alerta {
  final String ingredienteId;
  final String restauranteId;
  final String nombre;
  final String categoria;
  final String unidad;
  final double stockActual;
  final double stockMinimo;
  final DateTime? fechaCaducidad;
  final int? diasRestantes;
  final TipoAlerta tipo;
  final int severidad;

  Alerta({
    required this.ingredienteId,
    required this.restauranteId,
    required this.nombre,
    required this.categoria,
    required this.unidad,
    required this.stockActual,
    required this.stockMinimo,
    this.fechaCaducidad,
    this.diasRestantes,
    required this.tipo,
    required this.severidad,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) => Alerta(
        ingredienteId: json['ingrediente_id'] as String,
        restauranteId: json['restaurante_id'] as String,
        nombre: json['nombre'] as String,
        categoria: json['categoria'] ?? 'otros',
        unidad: json['unidad'] ?? 'kg',
        stockActual: (json['stock_actual'] as num?)?.toDouble() ?? 0,
        stockMinimo: (json['stock_minimo'] as num?)?.toDouble() ?? 0,
        fechaCaducidad: json['fecha_caducidad'] != null
            ? DateTime.parse(json['fecha_caducidad'])
            : null,
        diasRestantes: (json['dias_restantes'] as num?)?.toInt(),
        tipo: TipoAlertaX.fromString(json['tipo'] as String?),
        severidad: (json['severidad'] as num?)?.toInt() ?? 3,
      );

  String get titulo {
    switch (tipo) {
      case TipoAlerta.caducidadVencida:
        return 'Caducado';
      case TipoAlerta.caducidadCritica:
        return 'Caduca pronto';
      case TipoAlerta.caducidadProxima:
        return 'Próximo a caducar';
      case TipoAlerta.stockCritico:
        return 'Sin stock';
      case TipoAlerta.stockBajo:
        return 'Stock bajo';
      case TipoAlerta.desconocido:
        return 'Aviso';
    }
  }

  String get mensaje {
    switch (tipo) {
      case TipoAlerta.caducidadVencida:
        final d = (diasRestantes ?? 0).abs();
        return "'$nombre' caducó hace $d ${d == 1 ? 'día' : 'días'}";
      case TipoAlerta.caducidadCritica:
      case TipoAlerta.caducidadProxima:
        final d = diasRestantes ?? 0;
        if (d == 0) return "'$nombre' caduca hoy";
        if (d == 1) return "'$nombre' caduca mañana";
        return "'$nombre' caduca en $d días";
      case TipoAlerta.stockCritico:
        return "'$nombre' sin stock (necesita reposición)";
      case TipoAlerta.stockBajo:
        return "'$nombre': $stockActual $unidad disponibles "
            "(mínimo: $stockMinimo $unidad)";
      case TipoAlerta.desconocido:
        return nombre;
    }
  }
}

class ResumenAlertas {
  final int total;
  final int criticas;
  final int altas;

  const ResumenAlertas({
    this.total = 0,
    this.criticas = 0,
    this.altas = 0,
  });

  factory ResumenAlertas.fromJson(Map<String, dynamic> json) => ResumenAlertas(
        total: (json['total'] as num?)?.toInt() ?? 0,
        criticas: (json['criticas'] as num?)?.toInt() ?? 0,
        altas: (json['altas'] as num?)?.toInt() ?? 0,
      );

  bool get hayAlertas => total > 0;
  bool get hayCriticas => criticas > 0;
}

// ============================================================
// MOVIMIENTO DE STOCK
// ============================================================
enum TipoMovimiento {
  entrada,
  salida,
  merma,
  ajuste,
  albaran,
  produccion,
  desconocido,
}

extension TipoMovimientoX on TipoMovimiento {
  static TipoMovimiento fromString(String? raw) {
    switch (raw) {
      case 'entrada':
        return TipoMovimiento.entrada;
      case 'salida':
        return TipoMovimiento.salida;
      case 'merma':
        return TipoMovimiento.merma;
      case 'ajuste':
        return TipoMovimiento.ajuste;
      case 'albaran':
        return TipoMovimiento.albaran;
      case 'produccion':
        return TipoMovimiento.produccion;
      default:
        return TipoMovimiento.desconocido;
    }
  }

  String get raw {
    switch (this) {
      case TipoMovimiento.entrada:
        return 'entrada';
      case TipoMovimiento.salida:
        return 'salida';
      case TipoMovimiento.merma:
        return 'merma';
      case TipoMovimiento.ajuste:
        return 'ajuste';
      case TipoMovimiento.albaran:
        return 'albaran';
      case TipoMovimiento.produccion:
        return 'produccion';
      case TipoMovimiento.desconocido:
        return 'ajuste';
    }
  }

  String get label {
    switch (this) {
      case TipoMovimiento.entrada:
        return 'Entrada';
      case TipoMovimiento.salida:
        return 'Salida';
      case TipoMovimiento.merma:
        return 'Merma';
      case TipoMovimiento.ajuste:
        return 'Ajuste';
      case TipoMovimiento.albaran:
        return 'Albarán';
      case TipoMovimiento.produccion:
        return 'Producción';
      case TipoMovimiento.desconocido:
        return 'Otro';
    }
  }

  /// true si el movimiento añade stock, false si lo resta.
  /// Para 'ajuste' depende del signo, así que devolvemos null y se
  /// resuelve con stock_antes/stock_despues.
  bool? get esEntrada {
    switch (this) {
      case TipoMovimiento.entrada:
      case TipoMovimiento.albaran:
        return true;
      case TipoMovimiento.salida:
      case TipoMovimiento.merma:
      case TipoMovimiento.produccion:
        return false;
      case TipoMovimiento.ajuste:
      case TipoMovimiento.desconocido:
        return null;
    }
  }
}

class MovimientoStock {
  final String? id;
  final String? restauranteId;
  final String ingredienteId;
  final TipoMovimiento tipo;
  final double cantidad;
  final String? unidad;
  final double? stockAntes;
  final double? stockDespues;
  final double? costeUnitario;
  final String? usuarioId;
  final String? notas;
  final String? referencia;
  final DateTime createdAt;

  MovimientoStock({
    this.id,
    this.restauranteId,
    required this.ingredienteId,
    required this.tipo,
    required this.cantidad,
    this.unidad,
    this.stockAntes,
    this.stockDespues,
    this.costeUnitario,
    this.usuarioId,
    this.notas,
    this.referencia,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MovimientoStock.fromJson(Map<String, dynamic> json) =>
      MovimientoStock(
        id: json['id'] as String?,
        restauranteId: json['restaurante_id'] as String?,
        ingredienteId: json['ingrediente_id'] as String,
        tipo: TipoMovimientoX.fromString(json['tipo'] as String?),
        cantidad: (json['cantidad'] as num).toDouble(),
        unidad: json['unidad'] as String?,
        stockAntes: (json['stock_antes'] as num?)?.toDouble(),
        stockDespues: (json['stock_despues'] as num?)?.toDouble(),
        costeUnitario: (json['coste_unitario'] as num?)?.toDouble(),
        usuarioId: json['usuario_id'] as String?,
        notas: json['notas'] as String?,
        referencia: json['referencia'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'ingrediente_id': ingredienteId,
        'tipo': tipo.raw,
        'cantidad': cantidad,
        'unidad': unidad,
        'stock_antes': stockAntes,
        'stock_despues': stockDespues,
        'coste_unitario': costeUnitario,
        'usuario_id': usuarioId,
        'notas': notas,
        'referencia': referencia,
      };

  /// Delta firmado: positivo si aumentó stock, negativo si disminuyó.
  double get delta {
    if (stockAntes != null && stockDespues != null) {
      return stockDespues! - stockAntes!;
    }
    final esEntrada = tipo.esEntrada;
    if (esEntrada == null) return 0;
    return esEntrada ? cantidad : -cantidad;
  }
}

/// Punto en la curva de evolución del stock (vista v_evolucion_stock_30d)
class PuntoEvolucionStock {
  final DateTime fecha;
  final double stock;

  PuntoEvolucionStock({required this.fecha, required this.stock});

  factory PuntoEvolucionStock.fromJson(Map<String, dynamic> json) =>
      PuntoEvolucionStock(
        fecha: DateTime.parse(json['fecha'] as String),
        stock: (json['stock_estimado'] as num).toDouble(),
      );
}