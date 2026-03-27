import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

// ============================================================
// CLIENTE SUPABASE — Accesible globalmente
// ============================================================
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ============================================================
// AUTH STATE — Stream reactivo del estado de autenticación
// Escucha cambios en login/logout automáticamente
// ============================================================
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(supabaseProvider).auth.onAuthStateChange;
});

// ============================================================
// PERFIL DEL USUARIO ACTUAL
// Se recarga cuando cambia el auth state
// ============================================================
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final session = authState.value?.session;
  if (session == null) return null;

  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('profiles')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromJson(data);
});

// ============================================================
// AUTH SERVICE — Lógica de autenticación
// ============================================================
class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Registro de un nuevo restaurante + usuario admin
  /// 1. Crea el restaurante
  /// 2. Registra el usuario en auth con metadata
  /// 3. El trigger handle_new_user() crea el profile automáticamente
  Future<AuthResponse> registrarRestaurante({
    required String email,
    required String password,
    required String nombreRestaurante,
    required String nombreCompleto,
  }) async {
    // 1. Crear el restaurante primero (como service_role o con RLS abierto para insert)
    // NOTA: En producción, esto debería ser una Edge Function
    // Por ahora, necesitas una política RLS que permita INSERT en restaurantes
    // para usuarios autenticados, o usar una Edge Function
    final restauranteData = await _supabase
        .from('restaurantes')
        .insert({'nombre': nombreRestaurante})
        .select()
        .single();

    final restauranteId = restauranteData['id'];

    // 2. Registrar usuario con metadata
    // El trigger on_auth_user_created crea el profile automáticamente
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'restaurante_id': restauranteId,
        'nombre_completo': nombreCompleto,
        'rol': 'admin', // El primer usuario siempre es admin
      },
    );

    return response;
  }

  /// Login con email y contraseña
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Invitar a un nuevo miembro al restaurante
  /// Solo accesible para admin (protegido por RLS)
  Future<void> invitarMiembro({
    required String email,
    required String password,
    required String nombreCompleto,
    required String rol,
    required String restauranteId,
  }) async {
    // En producción: usar una Edge Function con service_role
    // que invite por email y gestione el onboarding
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'restaurante_id': restauranteId,
        'nombre_completo': nombreCompleto,
        'rol': rol,
      },
    );
  }
}

// Provider del servicio
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(supabaseProvider));
});
