import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';

// ============================================================
// PANTALLA "MÁS"
// Índice principal con accesos a las áreas grandes de la app:
// Platos, Proveedores, Personal, Ajustes.
// ============================================================
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Más opciones'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader('Gestión'),
          const SizedBox(height: 8),
          _BigCard(
            icon: Icons.restaurant_menu,
            title: 'Platos',
            subtitle: 'Crea, edita y consulta tu carta',
            color: SGColors.primary,
            onTap: () => context.push('/platos'),
          ),
          const SizedBox(height: 10),
          _BigCard(
            icon: Icons.business_outlined,
            title: 'Proveedores',
            subtitle: 'Gestiona contactos y datos de tus proveedores',
            color: SGColors.orange,
            onTap: () => context.push('/proveedores'),
          ),
          const SizedBox(height: 10),
          _BigCard(
            icon: Icons.people_outline,
            title: 'Personal',
            subtitle: 'Equipo, roles y permisos',
            color: const Color(0xFF6366F1),
            onTap: () => context.push('/personal'),
          ),
          const SizedBox(height: 28),
          const _SectionHeader('Configuración'),
          const SizedBox(height: 8),
          _BigCard(
            icon: Icons.settings_outlined,
            title: 'Ajustes',
            subtitle: 'Cuenta, preferencias y suscripción',
            color: SGColors.textSecondary,
            onTap: () => context.push('/ajustes'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: SGColors.textHint,
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SGColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SGColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SGColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: SGColors.textHint, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}