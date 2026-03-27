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
