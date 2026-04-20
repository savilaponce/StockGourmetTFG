import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'auth_service.dart';

// ============================================================
// PERSONAL SERVICE — Gestión de miembros del equipo
// ============================================================
class PersonalService {
  final Ref _ref;

  PersonalService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// Obtener todos los miembros activos del restaurante actual
  /// Usa la función RPC que ordena por rol (admin > chef > staff)
  Future<List<Profile>> getMiembros() async {
    try {
      // Intentar con la función RPC (más eficiente)
      final data = await _supabase.rpc('get_miembros_restaurante');
      return (data as List)
          .map((json) => Profile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: query directa (funciona sin la migración 004)
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('activo', true)
          .order('nombre_completo');
      return (data as List)
          .map((json) => Profile.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  /// Cambiar el rol de un miembro
  /// Solo el admin puede hacer esto (controlado por RLS)
  Future<void> cambiarRol(String userId, String nuevoRol) async {
    if (!['admin', 'chef', 'staff'].contains(nuevoRol)) {
      throw Exception('Rol no válido: $nuevoRol');
    }
    await _supabase
        .from('profiles')
        .update({'rol': nuevoRol})
        .eq('id', userId);
  }

  /// Eliminar un miembro completamente (profile + auth.users)
  /// Usa la función RPC que tiene permisos SECURITY DEFINER
  Future<void> eliminarMiembro(String userId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser?.id == userId) {
      throw Exception('No puedes eliminarte a ti mismo');
    }
    await _supabase.rpc('eliminar_miembro', params: {'user_id': userId});
  }

  /// Invitar nuevo miembro al restaurante
  /// Crea el usuario en auth + el trigger crea el profile automáticamente
  ///
  /// IMPORTANTE: En producción esto debería ser una Edge Function
  /// con service_role key para no perder la sesión del admin actual.
  /// Para el MVP, usamos signUp directo (el admin mantiene su sesión
  /// porque Supabase no cambia la sesión al crear otro usuario).
  Future<void> invitarMiembro({
    required String email,
    required String password,
    required String nombreCompleto,
    required String rol,
  }) async {
    final profile = await _ref.read(currentProfileProvider.future);
    if (profile == null) throw Exception('No hay sesión activa');
    if (!profile.isAdmin) throw Exception('Solo el administrador puede invitar miembros');

    // Verificar límite de usuarios del plan
    try {
      final count = await _supabase.rpc('count_miembros_activos');
      final restaurante = await _supabase
          .from('restaurantes')
          .select('max_usuarios')
          .eq('id', profile.restauranteId)
          .single();
      final maxUsuarios = restaurante['max_usuarios'] as int;
      if ((count as int) >= maxUsuarios) {
        throw Exception(
            'Has alcanzado el límite de $maxUsuarios usuarios de tu plan. '
            'Actualiza tu suscripción para añadir más miembros.');
      }
    } catch (e) {
      // Si falla la verificación del límite, continuar igualmente
      if (e.toString().contains('límite')) rethrow;
    }

    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'restaurante_id': profile.restauranteId,
        'nombre_completo': nombreCompleto,
        'rol': rol,
      },
    );
  }
}

// ============================================================
// PROVIDERS
// ============================================================
final personalServiceProvider = Provider<PersonalService>((ref) {
  return PersonalService(ref);
});

/// Lista de miembros del restaurante (se invalida al hacer cambios)
final miembrosProvider = FutureProvider<List<Profile>>((ref) async {
  final service = ref.read(personalServiceProvider);
  return service.getMiembros();
});