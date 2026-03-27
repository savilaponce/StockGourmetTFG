import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Perfil
          profileAsync.when(
            data: (profile) => Container(
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SGColors.primaryLight,
                    child: Text(
                      (profile?.nombreCompleto ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: SGColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.nombreCompleto ?? 'Usuario',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: SGColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: SGColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            AppConstants.rolLabel(profile?.rol ?? 'staff'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SGColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 24),

          // Opciones
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.restaurant_menu,
                label: 'Gestionar platos',
                onTap: () => context.push('/platos'),
              ),
              _SettingsTile(
                icon: Icons.people_outline,
                label: 'Gestión de personal',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gestión de personal próximamente'),
                      backgroundColor: SGColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                label: 'Ayuda y soporte',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                label: 'Acerca de StockGourmet',
                subtitle: 'Versión 1.0.0 — MVP',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cerrar sesión
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                isDestructive: true,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: SGColors.red),
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(authServiceProvider).logout();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? SGColors.red : SGColors.textPrimary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  const TextStyle(fontSize: 12, color: SGColors.textSecondary))
          : null,
      trailing:
          const Icon(Icons.chevron_right, color: SGColors.textHint, size: 20),
      onTap: onTap,
    );
  }
}
