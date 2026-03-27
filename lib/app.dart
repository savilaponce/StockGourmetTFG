import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/alertas_screen.dart';
import 'screens/home/ajustes_screen.dart';
import 'screens/inventario/inventario_screen.dart';
import 'screens/inventario/ingrediente_form_screen.dart';
import 'screens/platos/platos_screen.dart';
import 'screens/platos/plato_form_screen.dart';
import 'screens/platos/plato_detail_screen.dart';
import 'services/auth_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ============================================================
// COLORES — Paleta mockups StockGourmet
// ============================================================
class SGColors {
  SGColors._();
  static const Color primary = Color(0xFF2EC4B6);
  static const Color primaryDark = Color(0xFF1FA898);
  static const Color primaryLight = Color(0xFFE8F8F5);
  static const Color orange = Color(0xFFFF8C42);
  static const Color red = Color(0xFFE8453C);
  static const Color redLight = Color(0xFFFEECEB);
  static const Color green = Color(0xFF4CAF50);
  static const Color greenLight = Color(0xFFE8F5E9);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
}

// ============================================================
// ROUTER
// ============================================================
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // authState.value es el AuthState (siempre existe), comprobamos la SESSION
      final session = authState.value?.session;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      ShellRoute(
        builder: (c, s, child) => HomeScreen(child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (c, s) => const NoTransitionPage(child: DashboardTab())),
          GoRoute(path: '/inventario', pageBuilder: (c, s) => const NoTransitionPage(child: InventarioScreen())),
          GoRoute(path: '/alertas', pageBuilder: (c, s) => const NoTransitionPage(child: AlertasScreen())),
          GoRoute(path: '/ajustes', pageBuilder: (c, s) => const NoTransitionPage(child: AjustesScreen())),
        ],
      ),
      GoRoute(path: '/ingrediente/nuevo', builder: (c, s) => const IngredienteFormScreen()),
      GoRoute(path: '/ingrediente/editar/:id', builder: (c, s) => IngredienteFormScreen(ingredienteId: s.pathParameters['id'])),
      GoRoute(path: '/plato/nuevo', builder: (c, s) => const PlatoFormScreen()),
      GoRoute(path: '/plato/editar/:id', builder: (c, s) => PlatoFormScreen(platoId: s.pathParameters['id'])),
      GoRoute(path: '/plato/:id', builder: (c, s) => PlatoDetailScreen(platoId: s.pathParameters['id']!)),
      GoRoute(path: '/platos', builder: (c, s) => const PlatosScreen()),
    ],
  );
});

// ============================================================
// TEMA
// ============================================================
class StockGourmetApp extends ConsumerWidget {
  const StockGourmetApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'StockGourmet',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
        localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SGColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SGColors.primary,
          brightness: Brightness.light,
          primary: SGColors.primary,
          secondary: SGColors.orange,
          surface: SGColors.surface,
          error: SGColors.red,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
          backgroundColor: SGColors.surface,
          foregroundColor: SGColors.textPrimary,
          titleTextStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: SGColors.textPrimary),
        ),
        cardTheme: CardThemeData(elevation: 0, color: SGColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: SGColors.surface, elevation: 8,
          indicatorColor: SGColors.primaryLight,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final sel = states.contains(WidgetState.selected);
            return GoogleFonts.poppins(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? SGColors.primary : SGColors.textHint);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final sel = states.contains(WidgetState.selected);
            return IconThemeData(color: sel ? SGColors.primary : SGColors.textHint, size: 24);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SGColors.primary, foregroundColor: Colors.white, elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: SGColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SGColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SGColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SGColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: GoogleFonts.poppins(color: SGColors.textHint, fontSize: 14),
        ),
      ),
    );
  }
}