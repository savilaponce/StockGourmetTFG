import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/pedido_service.dart';
import '../../utils/formatters.dart';

final pedidoFiltroProvider = StateProvider<String?>((ref) => null);

class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(pedidoFiltroProvider);
    final pedidosAsync = ref.watch(pedidosProvider(filtro));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Pedidos'),
      ),
      body: Column(
        children: [
          // Filtros por estado
          Container(
            color: SGColors.surface,
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterPill(label: 'Todos', selected: filtro == null,
                    onTap: () => ref.read(pedidoFiltroProvider.notifier).state = null),
                _FilterPill(label: 'Pendientes', selected: filtro == 'pendiente',
                    onTap: () => ref.read(pedidoFiltroProvider.notifier).state = 'pendiente'),
                _FilterPill(label: 'Enviados', selected: filtro == 'enviado',
                    onTap: () => ref.read(pedidoFiltroProvider.notifier).state = 'enviado'),
                _FilterPill(label: 'Recibidos', selected: filtro == 'recibido',
                    onTap: () => ref.read(pedidoFiltroProvider.notifier).state = 'recibido'),
                _FilterPill(label: 'Cancelados', selected: filtro == 'cancelado',
                    onTap: () => ref.read(pedidoFiltroProvider.notifier).state = 'cancelado'),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: SGColors.primary,
              onRefresh: () async => ref.invalidate(pedidosProvider(filtro)),
              child: pedidosAsync.when(
                data: (pedidos) => pedidos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 64, color: SGColors.textHint),
                            const SizedBox(height: 16),
                            const Text('No hay pedidos',
                                style: TextStyle(color: SGColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => context.push('/pedido/nuevo'),
                              icon: const Icon(Icons.add, color: SGColors.primary),
                              label: const Text('Crear el primero', style: TextStyle(color: SGColors.primary)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: pedidos.length,
                        itemBuilder: (context, i) => _PedidoCard(pedido: pedidos[i]),
                      ),
                loading: () => const Center(child: CircularProgressIndicator(color: SGColors.primary)),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: profileAsync.when(
        data: (profile) => (profile?.canEdit ?? false)
            ? FloatingActionButton(
                onPressed: () => context.push('/pedido/nuevo'),
                backgroundColor: SGColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? SGColors.primary : SGColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? SGColors.primary : SGColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : SGColors.textSecondary,
              )),
        ),
      ),
    );
  }
}

class _PedidoCard extends ConsumerWidget {
  final Pedido pedido;
  const _PedidoCard({required this.pedido});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/pedido/${pedido.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: proveedor + estado badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _estadoColor(pedido.estado).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_shipping_outlined,
                        color: _estadoColor(pedido.estado), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido.proveedor,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SGColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(Formatters.date(pedido.fechaPedido),
                            style: const TextStyle(fontSize: 12, color: SGColors.textSecondary)),
                      ],
                    ),
                  ),
                  _EstadoBadge(estado: pedido.estado),
                ],
              ),

              const SizedBox(height: 12),

              // Info: coste + fecha entrega
              Row(
                children: [
                  Icon(Icons.euro, size: 14, color: SGColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(Formatters.currency(pedido.costeTotal),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SGColors.textPrimary)),
                  const SizedBox(width: 16),
                  if (pedido.fechaEntregaEstimada != null) ...[
                    Icon(Icons.calendar_today, size: 14, color: SGColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Entrega: ${Formatters.date(pedido.fechaEntregaEstimada)}',
                        style: const TextStyle(fontSize: 12, color: SGColors.textSecondary)),
                  ],
                ],
              ),

              // Acciones rápidas para pendientes
              if (pedido.isPendiente) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _cancelar(context, ref),
                      style: TextButton.styleFrom(foregroundColor: SGColors.red),
                      child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _recibir(context, ref),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Recibir', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: SGColors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recibir(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Marcar como recibido?'),
        content: const Text('Se actualizará el stock de los ingredientes vinculados automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SGColors.green),
            child: const Text('Confirmar recepción'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(pedidoServiceProvider).recibirPedido(pedido.id!);
        ref.invalidate(pedidosProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido recibido. Stock actualizado.'), backgroundColor: SGColors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: SGColors.red),
          );
        }
      }
    }
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    await ref.read(pedidoServiceProvider).cambiarEstado(pedido.id!, 'cancelado');
    ref.invalidate(pedidosProvider);
  }

  Color _estadoColor(String estado) => switch (estado) {
    'pendiente' => SGColors.orange,
    'enviado' => const Color(0xFF3B82F6),
    'recibido' => SGColors.green,
    'cancelado' => SGColors.red,
    _ => SGColors.textSecondary,
  };
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
    final label = switch (estado) {
      'pendiente' => 'Pendiente',
      'enviado' => 'Enviado',
      'recibido' => 'Recibido',
      'cancelado' => 'Cancelado',
      _ => estado,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}