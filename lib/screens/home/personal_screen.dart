import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/personal_service.dart';
import '../../utils/constants.dart';

class PersonalScreen extends ConsumerWidget {
  const PersonalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miembrosAsync = ref.watch(miembrosProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: SGColors.background,
      appBar: AppBar(
        backgroundColor: SGColors.surface,
        title: const Text('Gestión de Personal'),
      ),
      body: miembrosAsync.when(
        data: (miembros) => miembros.isEmpty
            ? const Center(
                child: Text('No hay miembros registrados',
                    style: TextStyle(color: SGColors.textSecondary)),
              )
            : RefreshIndicator(
                color: SGColors.primary,
                onRefresh: () async => ref.invalidate(miembrosProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: miembros.length,
                  itemBuilder: (context, i) {
                    final miembro = miembros[i];
                    final esYo = profileAsync.value?.id == miembro.id;
                    final soyAdmin = profileAsync.value?.isAdmin ?? false;

                    return _MiembroCard(
                      miembro: miembro,
                      esYo: esYo,
                      soyAdmin: soyAdmin,
                      onRolChanged: soyAdmin && !esYo
                          ? (nuevoRol) async {
                              try {
                                await ref
                                    .read(personalServiceProvider)
                                    .cambiarRol(miembro.id, nuevoRol);
                                ref.invalidate(miembrosProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Rol de ${miembro.nombreCompleto} actualizado'),
                                      backgroundColor: SGColors.primary,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: SGColors.red),
                                  );
                                }
                              }
                            }
                          : null,
                      onEliminar: soyAdmin && !esYo
                          ? () => _confirmarEliminar(context, ref, miembro)
                          : null,
                    );
                  },
                ),
              ),
        loading: () => const Center(
            child: CircularProgressIndicator(color: SGColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: SGColors.red, size: 48),
              const SizedBox(height: 12),
              Text('Error: $e',
                  style: const TextStyle(color: SGColors.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(miembrosProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: profileAsync.when(
        data: (profile) => (profile?.isAdmin ?? false)
            ? FloatingActionButton(
                onPressed: () => _mostrarDialogoInvitar(context, ref),
                backgroundColor: SGColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.person_add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Future<void> _confirmarEliminar(
      BuildContext context, WidgetRef ref, Profile miembro) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar miembro?'),
        content: Text(
            '${miembro.nombreCompleto} ya no podrá acceder a la aplicación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SGColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(personalServiceProvider)
            .eliminarMiembro(miembro.id);
        ref.invalidate(miembrosProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${miembro.nombreCompleto} eliminado del equipo'),
              backgroundColor: SGColors.primary,
            ),
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

  void _mostrarDialogoInvitar(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InvitarMiembroSheet(ref: ref),
    );
  }
}

// ============================================================
// MIEMBRO CARD — Avatar circular, nombre, rol badge,
// dropdown cambiar rol, botón eliminar (solo admin ve esto)
// ============================================================
class _MiembroCard extends StatelessWidget {
  final Profile miembro;
  final bool esYo;
  final bool soyAdmin;
  final Function(String)? onRolChanged;
  final VoidCallback? onEliminar;

  const _MiembroCard({
    required this.miembro,
    required this.esYo,
    required this.soyAdmin,
    this.onRolChanged,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: esYo
            ? Border.all(
                color: SGColors.primary.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // Fila principal: avatar + nombre + rol
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    _rolColor(miembro.rol).withValues(alpha: 0.15),
                child: Text(
                  miembro.nombreCompleto.isNotEmpty
                      ? miembro.nombreCompleto.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _rolColor(miembro.rol),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            miembro.nombreCompleto,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: SGColors.textPrimary,
                            ),
                          ),
                        ),
                        if (esYo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SGColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Tú',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: SGColors.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _rolColor(miembro.rol).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppConstants.rolLabel(miembro.rol),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _rolColor(miembro.rol),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (soyAdmin && !esYo)
                const Icon(Icons.expand_more,
                    color: SGColors.textHint, size: 22),
            ],
          ),

          // Panel de acciones admin (solo visible para admin y no para sí mismo)
          if (soyAdmin && !esYo) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SGColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Cambiar rol
                  Row(
                    children: [
                      const Text('Cambiar Rol',
                          style: TextStyle(
                              fontSize: 13,
                              color: SGColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: SGColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SGColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: miembro.rol,
                              isExpanded: true,
                              style: const TextStyle(
                                  fontSize: 14, color: SGColors.textPrimary),
                              items: AppConstants.roles
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(AppConstants.rolLabel(r)),
                                      ))
                                  .toList(),
                              onChanged: onRolChanged != null
                                  ? (v) {
                                      if (v != null && v != miembro.rol) {
                                        onRolChanged!(v);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Botones: eliminar + guardar
                  Row(
                    children: [
                      TextButton(
                        onPressed: onEliminar,
                        style: TextButton.styleFrom(
                            foregroundColor: SGColors.red),
                        child: const Text('Eliminar Miembro',
                            style: TextStyle(fontSize: 13)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // El cambio de rol ya se aplica en el onChanged del dropdown
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cambios guardados'),
                              backgroundColor: SGColors.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Guardar Cambios'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _rolColor(String rol) => switch (rol) {
        'admin' => SGColors.primary,
        'chef' => SGColors.orange,
        'staff' => SGColors.textSecondary,
        _ => SGColors.textHint,
      };
}

// ============================================================
// INVITAR MIEMBRO — Bottom Sheet con formulario completo
// ============================================================
class _InvitarMiembroSheet extends StatefulWidget {
  final WidgetRef ref;
  const _InvitarMiembroSheet({required this.ref});

  @override
  State<_InvitarMiembroSheet> createState() => _InvitarMiembroSheetState();
}

class _InvitarMiembroSheetState extends State<_InvitarMiembroSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _rol = 'staff';
  bool _loading = false;
  bool _obscure = true;

  Future<void> _invitar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await widget.ref.read(personalServiceProvider).invitarMiembro(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            nombreCompleto: _nombreCtrl.text.trim(),
            rol: _rol,
          );
      widget.ref.invalidate(miembrosProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nombreCtrl.text} añadido al equipo como ${AppConstants.rolLabel(_rol)}'),
            backgroundColor: SGColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: SGColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: SGColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Añadir miembro al equipo',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: SGColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
                'El nuevo miembro podrá acceder con estas credenciales.',
                style:
                    TextStyle(fontSize: 13, color: SGColors.textSecondary)),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon:
                    Icon(Icons.person_outlined, color: SGColors.textHint),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Nombre requerido' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon:
                    Icon(Icons.email_outlined, color: SGColors.textHint),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email requerido';
                if (!v.contains('@')) return 'Email no válido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon:
                    const Icon(Icons.lock_outlined, color: SGColors.textHint),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: SGColors.textHint),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Contraseña requerida';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _rol,
              decoration: const InputDecoration(
                labelText: 'Rol',
                prefixIcon:
                    Icon(Icons.badge_outlined, color: SGColors.textHint),
              ),
              items: AppConstants.roles
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(AppConstants.rolLabel(r)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _rol = v!),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: SGColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(color: SGColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _invitar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Añadir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}