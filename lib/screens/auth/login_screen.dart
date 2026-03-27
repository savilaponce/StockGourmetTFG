import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      setState(() => _error = msg.contains('invalid login') ? 'Email o contraseña incorrectos'
          : msg.contains('email not confirmed') ? 'Confirma tu email primero'
          : 'Error inesperado. Inténtalo de nuevo.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Logo SG
                Container(
                  width: 90, height: 90,
                  decoration: const BoxDecoration(color: Color(0xFF1A1A2E), shape: BoxShape.circle),
                  child: const Center(child: Text('SG', style: TextStyle(color: Color(0xFFD4A843), fontSize: 30, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(height: 16),
                const Text('StockGourmet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SGColors.textPrimary)),
                const SizedBox(height: 4),
                const Text('Gestión inteligente de tu cocina', style: TextStyle(color: SGColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 40),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: SGColors.redLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: SGColors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: SGColors.red, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: SGColors.textHint)),
                  validator: (v) => v == null || v.isEmpty ? 'Introduce tu email' : !v.contains('@') ? 'Email no válido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl, obscureText: _obscure, textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outlined, color: SGColors.textHint),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: SGColors.textHint), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Introduce tu contraseña' : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Iniciar Sesión'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('¿No tienes cuenta? ', style: TextStyle(color: SGColors.textSecondary)),
                  GestureDetector(onTap: () => context.go('/register'), child: const Text('Regístrate', style: TextStyle(color: SGColors.primary, fontWeight: FontWeight.w600))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }
}
