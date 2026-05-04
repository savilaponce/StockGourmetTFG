import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/alertas_service.dart';

class AlertasScreen extends ConsumerStatefulWidget {
  const AlertasScreen({super.key});

  @override
  ConsumerState<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends ConsumerState<AlertasScreen> {
  // null = todas
  TipoAlerta? _filtro;

  @override
  Widget build(BuildContext context) {
    final alertasAsync = ref.watch(alertasProvider(_filtro));

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Alertas y Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(alertasProvider);
              ref.invalidate(resumenAlertasProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _ChipFiltro(
                  label: 'Todas',
                  selected: _filtro == null,
                  onTap: () => setState(() => _filtro = null),
                ),
                _ChipFiltro(
                  label: 'Caducadas',
                  selected: _filtro == TipoAlerta.caducidadVencida,
                  onTap: () =>
                      setState(() => _filtro = TipoAlerta.caducidadVencida),
                  color: SGColors.red,
                ),
                _ChipFiltro(
                  label: 'Caducan pronto',
                  selected: _filtro == TipoAlerta.caducidadCritica,
                  onTap: () =>
                      setState(() => _filtro = TipoAlerta.caducidadCritica),
                  color: SGColors.orange,
                ),
                _ChipFiltro(
                  label: 'Próximos a caducar',
                  selected: _filtro == TipoAlerta.caducidadProxima,
                  onTap: () =>
                      setState(() => _filtro = TipoAlerta.caducidadProxima),
                ),
                _ChipFiltro(
                  label: 'Sin stock',
                  selected: _filtro == TipoAlerta.stockCritico,
                  onTap: () =>
                      setState(() => _filtro = TipoAlerta.stockCritico),
                  color: SGColors.red,
                ),
                _ChipFiltro(
                  label: 'Stock bajo',
                  selected: _filtro == TipoAlerta.stockBajo,
                  onTap: () => setState(() => _filtro = TipoAlerta.stockBajo),
                  color: SGColors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: SGColors.primary,
        onRefresh: () async {
          ref.invalidate(alertasProvider);
          ref.invalidate(resumenAlertasProvider);
        },
        child: alertasAsync.when(
          data: (items) => items.isEmpty
              ? _VistaSinAlertas(filtroActivo: _filtro != null)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _AlertaTile(alerta: items[i]),
                ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: SGColors.primary)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error cargando alertas: $e',
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHIP DE FILTRO
// ============================================================
class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _ChipFiltro({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? SGColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? c : SGColors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? c : Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ============================================================
// VISTA SIN ALERTAS
// ============================================================
class _VistaSinAlertas extends StatelessWidget {
  final bool filtroActivo;
  const _VistaSinAlertas({required this.filtroActivo});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.notifications_off_outlined,
            size: 64, color: SGColors.textHint),
        const SizedBox(height: 16),
        Center(
          child: Text(
            filtroActivo ? 'Sin alertas de este tipo' : 'Sin alertas',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SGColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Todo tu inventario está en orden',
            style: TextStyle(color: SGColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TARJETA DE ALERTA
// ============================================================
class _AlertaTile extends StatelessWidget {
  final Alerta alerta;
  const _AlertaTile({required this.alerta});

  Color _color() {
    switch (alerta.severidad) {
      case 1:
        return SGColors.red;
      case 2:
        return SGColors.orange;
      default:
        return const Color(0xFFEAB308);
    }
  }

  IconData _icono() {
    switch (alerta.tipo) {
      case TipoAlerta.caducidadVencida:
        return Icons.error_outline;
      case TipoAlerta.caducidadCritica:
        return Icons.warning_amber_rounded;
      case TipoAlerta.caducidadProxima:
        return Icons.schedule;
      case TipoAlerta.stockCritico:
        return Icons.remove_shopping_cart_outlined;
      case TipoAlerta.stockBajo:
        return Icons.inventory_2_outlined;
      case TipoAlerta.desconocido:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icono(), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alerta.mensaje,
                  style: const TextStyle(
                      fontSize: 14, color: SGColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right,
              color: SGColors.textHint, size: 20),
        ],
      ),
    );
  }
}