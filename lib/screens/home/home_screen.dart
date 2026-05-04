import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/plato_service.dart';
import '../../services/ingrediente_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/badge_alertas.dart';

// ============================================================
// HOME SCREEN — Shell con 5 tabs: Inicio, Inventario, Pedidos, Alertas, Ajustes
// ============================================================
class HomeScreen extends ConsumerWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = switch (location) {
      '/inventario' => 1,
      '/pedidos' => 2,
      '/alertas' => 3,
      '/mas' => 4,
      '/ajustes' => 4,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          final route = switch (i) {
            1 => '/inventario',
            2 => '/pedidos',
            3 => '/alertas',
            4 => '/mas',
            _ => '/',
          };
          context.go(route);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: BadgeAlertas(child: Icon(Icons.notifications_outlined)),
            selectedIcon: BadgeAlertas(child: Icon(Icons.notifications)),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}


// ============================================================
// DASHBOARD TAB — Diseño mockup: KPI cards + alertas + botón escanear
// ============================================================
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final caducidadAsync = ref.watch(ingredientesPorCaducarProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SGColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: SGColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('StockGourmet'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: SGColors.textSecondary),
            onPressed: () => context.go('/ajustes'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: SGColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(ingredientesPorCaducarProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // === BARRA DE BÚSQUEDA ===
            _SearchBar(onTap: () => context.push('/buscar')),
            const SizedBox(height: 20),

            // === KPI CARDS (como mockup: Stock Actual, Próximos a Caducar, Stock Mínimo) ===
            statsAsync.when(
              data: (stats) => Column(
                children: [
                  // Stock Actual — card grande con valor €
                  _DashboardCard(
                    label: 'STOCK ACTUAL',
                    value: Formatters.currency(stats['valor_inventario'] ?? 0),
                    subtitle: 'Valor total del inventario',
                    icon: Icons.euro,
                    iconColor: SGColors.primary,
                    iconBg: SGColors.primaryLight,
                  ),
                  const SizedBox(height: 12),

                  // Dos cards en fila
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardCardCompact(
                          label: 'PRÓXIMOS A CADUCAR',
                          value: '${stats['ingredientes_por_caducar'] ?? 0}',
                          subtitle: 'En los próximos 3 días',
                          icon: Icons.warning_amber_rounded,
                          iconColor: SGColors.orange,
                          iconBg: const Color(0xFFFFF3E0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardCardCompact(
                          label: 'STOCK MÍNIMO',
                          value: '${stats['total_ingredientes'] ?? 0}',
                          subtitle: 'Ingredientes bajo mínimo',
                          icon: Icons.inventory_outlined,
                          iconColor: SGColors.textSecondary,
                          iconBg: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: SGColors.primary),
                  )),
              error: (e, _) => _ErrorCard(error: e.toString()),
            ),
            const SizedBox(height: 24),

            // === BOTÓN ESCANEAR ALBARÁN (como mockup) ===
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/albaran/scanner'),
                icon: const Icon(Icons.document_scanner_outlined, size: 22),
                label: const Text('Escanear Albarán'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SGColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // === SECCIÓN: GESTIÓN ===
            const _SectionHeader(title: 'Gestión'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ManagementCard(
                    icon: Icons.restaurant_menu,
                    label: 'Platos',
                    color: SGColors.primary,
                    onTap: () => context.push('/platos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManagementCard(
                    icon: Icons.business_outlined,
                    label: 'Proveedores',
                    color: SGColors.orange,
                    onTap: () => context.push('/proveedores'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManagementCard(
                    icon: Icons.people_outline,
                    label: 'Personal',
                    color: const Color(0xFF6366F1),
                    onTap: () => context.push('/personal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // === ACCIONES RÁPIDAS ===
            const _SectionHeader(title: 'Acciones rápidas'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.restaurant_menu,
                    label: 'Nuevo plato',
                    color: SGColors.primary,
                    onTap: () => context.push('/plato/nuevo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.add_box_outlined,
                    label: 'Nuevo ingrediente',
                    color: SGColors.orange,
                    onTap: () => context.push('/ingrediente/nuevo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // === ALERTAS DE CADUCIDAD ===
            _SectionHeader(
              title: 'Alertas de caducidad',
              trailing: TextButton(
                onPressed: () => context.go('/alertas'),
                child: const Text('Ver todas',
                    style: TextStyle(color: SGColors.primary)),
              ),
            ),
            const SizedBox(height: 8),
            caducidadAsync.when(
              data: (items) => items.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: SGColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          const Text('¡Todo en orden!',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: SGColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('No hay ingredientes próximos a caducar',
                              style: TextStyle(
                                  color: SGColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : Column(
                      children: items
                          .take(3)
                          .map((i) => _CaducidadItem(ingrediente: i))
                          .toList(),
                    ),
              loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: SGColors.primary),
                  )),
              error: (e, _) => _ErrorCard(error: e.toString()),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS — Dashboard Cards (estilo mockup)
// ============================================================

class _DashboardCard extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color iconColor, iconBg;

  const _DashboardCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SGColors.textHint,
                letterSpacing: 1,
              )),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: SGColors.textPrimary,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: SGColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DashboardCardCompact extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color iconColor, iconBg;

  const _DashboardCardCompact({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: SGColors.textHint,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: SGColors.textPrimary,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: SGColors.textSecondary)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SGColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SGColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SGColors.textPrimary,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _ManagementCard — tarjeta cuadrada para acceso a las áreas
// principales de gestión (Platos, Proveedores, Personal)
// ============================================================
class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SGColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SGColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SGColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SGColors.textPrimary,
            )),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CaducidadItem extends StatelessWidget {
  final Ingrediente ingrediente;
  const _CaducidadItem({required this.ingrediente});

  @override
  Widget build(BuildContext context) {
    final dias = ingrediente.diasRestantes ?? 0;
    final caducado = dias < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SGColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: caducado
              ? SGColors.red.withValues(alpha: 0.3)
              : SGColors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: caducado ? SGColors.redLight : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${dias.abs()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: caducado ? SGColors.red : SGColors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingrediente.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: SGColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  caducado
                      ? 'Caducado hace ${dias.abs()} días'
                      : 'Caduca en $dias días',
                  style: TextStyle(
                    fontSize: 12,
                    color: caducado ? SGColors.red : SGColors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.cantidad(ingrediente.stockActual, ingrediente.unidad),
            style: const TextStyle(
                fontSize: 12, color: SGColors.textSecondary),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: SGColors.textHint, size: 20),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SGColors.redLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SGColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Error: $error',
                style: const TextStyle(color: SGColors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BARRA DE BÚSQUEDA (cabecera del dashboard)
// No tiene foco propio; al pulsarla navega a /buscar
// ============================================================
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SGColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SGColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search,
                  size: 20, color: SGColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Buscar ingredientes, platos, proveedores...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}