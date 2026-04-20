import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/pedido_service.dart';
import '../../utils/formatters.dart';

class PedidoDetailScreen extends ConsumerWidget {
  final String pedidoId;
  const PedidoDetailScreen({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidoFuture = ref.watch(
      FutureProvider<Pedido>((ref) => ref.read(pedidoServiceProvider).getById(pedidoId)),
    );
    final lineasAsync = ref.watch(pedidoLineasProvider(pedidoId));

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Detalle del Pedido'),
        actions: [
          pedidoFuture.when(
            data: (pedido) => pedido.isPendiente
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: SGColors.red),
                    onPressed: () => _eliminar(context, ref),
                  )
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: pedidoFuture.when(
        data: (pedido) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info del pedido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SGColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(pedido.proveedor,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SGColors.textPrimary)),
                      ),
                      _EstadoBadge(estado: pedido.estado),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.calendar_today, label: 'Fecha pedido', value: Formatters.date(pedido.fechaPedido)),
                  if (pedido.fechaEntregaEstimada != null)
                    _InfoRow(icon: Icons.schedule, label: 'Entrega estimada', value: Formatters.date(pedido.fechaEntregaEstimada)),
                  if (pedido.fechaRecibido != null)
                    _InfoRow(icon: Icons.check_circle_outline, label: 'Recibido', value: Formatters.dateTime(pedido.fechaRecibido)),
                  _InfoRow(icon: Icons.euro, label: 'Coste total', value: Formatters.currency(pedido.costeTotal)),
                  if (pedido.notas != null && pedido.notas!.isNotEmpty)
                    _InfoRow(icon: Icons.notes, label: 'Notas', value: pedido.notas!),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Líneas del pedido
            const Text('Productos del pedido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
            const SizedBox(height: 12),

            lineasAsync.when(
              data: (lineas) => lineas.isEmpty
                  ? const Center(child: Text('No hay productos', style: TextStyle(color: SGColors.textSecondary)))
                  : Column(
                      children: [
                        ...lineas.map((l) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SGColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: l.recibido ? SGColors.greenLight : SGColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  l.recibido ? Icons.check : Icons.inventory_2_outlined,
                                  color: l.recibido ? SGColors.green : SGColors.textHint,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.nombreProducto,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: SGColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${Formatters.cantidad(l.cantidad, l.unidad)} × ${Formatters.currency(l.precioUnitario)}',
                                      style: const TextStyle(fontSize: 12, color: SGColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(Formatters.currency(l.costeLinea),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: SGColors.textPrimary)),
                            ],
                          ),
                        )),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
                            Text(Formatters.currency(pedido.costeTotal),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SGColors.primary)),
                          ],
                        ),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: SGColors.primary)),
              error: (e, _) => Text('Error: $e'),
            ),

            // Botones de acción
            if (pedido.isPendiente || pedido.isEnviado) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _recibir(context, ref),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como Recibido'),
                  style: ElevatedButton.styleFrom(backgroundColor: SGColors.green),
                ),
              ),
              if (pedido.isPendiente) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _cancelar(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SGColors.red,
                      side: const BorderSide(color: SGColors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar Pedido'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: SGColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _recibir(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Confirmar recepción?'),
        content: const Text('El stock de los ingredientes vinculados se actualizará automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SGColors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(pedidoServiceProvider).recibirPedido(pedidoId);
        ref.invalidate(pedidosProvider);
        ref.invalidate(pedidoLineasProvider(pedidoId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido recibido. Stock actualizado.'), backgroundColor: SGColors.green),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: SGColors.red));
        }
      }
    }
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    await ref.read(pedidoServiceProvider).cambiarEstado(pedidoId, 'cancelado');
    ref.invalidate(pedidosProvider);
    if (context.mounted) context.pop();
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar pedido?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: SGColors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pedidoServiceProvider).delete(pedidoId);
      ref.invalidate(pedidosProvider);
      if (context.mounted) context.pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SGColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: SGColors.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: SGColors.textPrimary))),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'pendiente' => SGColors.orange,
      'enviado' => const Color(0xFF3B82F6),
      'recibido' => SGColors.green,
      'cancelado' => SGColors.red,
      _ => SGColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(Pedido(proveedor: '').estadoLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}