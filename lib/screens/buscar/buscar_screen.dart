import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/ingrediente_service.dart';
import '../../services/plato_service.dart';
import '../../services/proveedor_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';

// ============================================================
// BÚSQUEDA GLOBAL
// Una sola caja, resultados agrupados por tipo (Ingredientes,
// Platos, Proveedores). Debounce de 300 ms.
// ============================================================

class _ResultadoBusqueda {
  final List<Ingrediente> ingredientes;
  final List<Plato> platos;
  final List<Proveedor> proveedores;

  const _ResultadoBusqueda({
    this.ingredientes = const [],
    this.platos = const [],
    this.proveedores = const [],
  });

  bool get isEmpty =>
      ingredientes.isEmpty && platos.isEmpty && proveedores.isEmpty;

  int get total =>
      ingredientes.length + platos.length + proveedores.length;
}

class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _cargando = false;
  String? _error;
  _ResultadoBusqueda _resultado = const _ResultadoBusqueda();

  @override
  void initState() {
    super.initState();
    // Auto-focus al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final trimmed = value.trim();
    setState(() => _query = trimmed);

    _debounce?.cancel();

    if (trimmed.length < 2) {
      // Limpiar resultados si el usuario borra texto
      setState(() {
        _resultado = const _ResultadoBusqueda();
        _cargando = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _buscar(trimmed);
    });
  }

  Future<void> _buscar(String query) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final ingService = ref.read(ingredienteServiceProvider);
    final platoService = ref.read(platoServiceProvider);
    final provService = ref.read(proveedorServiceProvider);

    try {
      // En paralelo para que sea rápido
      final results = await Future.wait([
        ingService.search(query),
        platoService.search(query),
        provService.search(query),
      ]);

      // Si el usuario siguió escribiendo y la query cambió, descartar
      if (_query != query || !mounted) return;

      setState(() {
        _resultado = _ResultadoBusqueda(
          ingredientes: results[0] as List<Ingrediente>,
          platos: results[1] as List<Plato>,
          proveedores: results[2] as List<Proveedor>,
        );
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar ingredientes, platos, proveedores...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                      _focus.requestFocus();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Estado inicial: aún no se buscó nada
    if (_query.length < 2) {
      return const _EstadoInicial();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SGColors.red)),
        ),
      );
    }

    if (_cargando) {
      return const SkeletonList(count: 5);
    }

    if (_resultado.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Sin resultados',
        message: 'No encontramos nada para "$_query".\n'
            'Prueba con menos caracteres o revisa la ortografía.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Text(
          '${_resultado.total} resultado${_resultado.total == 1 ? "" : "s"}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SGColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (_resultado.ingredientes.isNotEmpty) ...[
          const _SectionLabel(
              icon: Icons.inventory_2_outlined,
              label: 'Ingredientes',
              color: SGColors.primary),
          for (final ing in _resultado.ingredientes)
            _IngredienteResultTile(ingrediente: ing),
          const SizedBox(height: 16),
        ],
        if (_resultado.platos.isNotEmpty) ...[
          _SectionLabel(
              icon: Icons.restaurant_menu,
              label: 'Platos',
              color: SGColors.primary),
          for (final p in _resultado.platos) _PlatoResultTile(plato: p),
          const SizedBox(height: 16),
        ],
        if (_resultado.proveedores.isNotEmpty) ...[
          _SectionLabel(
              icon: Icons.business_outlined,
              label: 'Proveedores',
              color: SGColors.orange),
          for (final p in _resultado.proveedores)
            _ProveedorResultTile(proveedor: p),
        ],
      ],
    );
  }
}

// ============================================================
// ESTADO INICIAL (sugerencias / mensaje)
// ============================================================
class _EstadoInicial extends StatelessWidget {
  const _EstadoInicial();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search,
            size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Empieza a escribir para buscar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SGColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Mínimo 2 caracteres',
            style: TextStyle(fontSize: 12, color: SGColors.textHint),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CABECERA DE SECCIÓN
// ============================================================
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TILES POR TIPO
// ============================================================
class _IngredienteResultTile extends StatelessWidget {
  final Ingrediente ingrediente;
  const _IngredienteResultTile({required this.ingrediente});

  @override
  Widget build(BuildContext context) {
    return _BaseResultTile(
      icon: Icons.inventory_2_outlined,
      iconColor: SGColors.primary,
      title: ingrediente.nombre,
      subtitle:
          'Stock: ${Formatters.cantidad(ingrediente.stockActual, ingrediente.unidad)}',
      onTap: () => context.push('/ingrediente/editar/${ingrediente.id}'),
    );
  }
}

class _PlatoResultTile extends StatelessWidget {
  final Plato plato;
  const _PlatoResultTile({required this.plato});

  @override
  Widget build(BuildContext context) {
    return _BaseResultTile(
      icon: Icons.restaurant_menu,
      iconColor: SGColors.primary,
      title: plato.nombre,
      subtitle: plato.precioVenta != null && plato.precioVenta! > 0
          ? Formatters.currency(plato.precioVenta!)
          : 'Sin precio',
      onTap: () => context.push('/plato/${plato.id}'),
    );
  }
}

class _ProveedorResultTile extends StatelessWidget {
  final Proveedor proveedor;
  const _ProveedorResultTile({required this.proveedor});

  @override
  Widget build(BuildContext context) {
    return _BaseResultTile(
      icon: Icons.business_outlined,
      iconColor: SGColors.orange,
      title: proveedor.nombre,
      subtitle: proveedor.telefono ?? proveedor.email ?? 'Proveedor',
      // Vamos al listado: la app no tiene pantalla de detalle individual
      onTap: () => context.push('/proveedores'),
    );
  }
}

// ============================================================
// TILE BASE
// ============================================================
class _BaseResultTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BaseResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
              fontSize: 12, color: SGColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: SGColors.textHint, size: 20),
        onTap: onTap,
      ),
    );
  }
}