import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreRestCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).registrarRestaurante(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text,
        nombreRestaurante: _nombreRestCtrl.text.trim(), nombreCompleto: _nombreCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Cuenta creada! Revisa tu email si tienes confirmación activada.'), backgroundColor: SGColors.primary));
        context.go('/login');
      }
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: SGColors.textPrimary, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Crear cuenta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SGColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Registra tu restaurante y empieza a gestionar.', style: TextStyle(color: SGColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: SGColors.redLight, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: const TextStyle(color: SGColors.red, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _nombreRestCtrl, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre del restaurante', prefixIcon: Icon(Icons.storefront_outlined, color: SGColors.textHint)),
                validator: (v) => v == null || v.isEmpty ? 'Nombre del restaurante requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nombreCtrl, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Tu nombre completo', prefixIcon: Icon(Icons.person_outlined, color: SGColors.textHint)),
                validator: (v) => v == null || v.isEmpty ? 'Tu nombre es requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: SGColors.textHint)),
                validator: (v) { if (v == null || v.isEmpty) return 'Email requerido'; if (!v.contains('@')) return 'Email no válido'; return null; },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl, obscureText: _obscure, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outlined, color: SGColors.textHint),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: SGColors.textHint), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
                validator: (v) { if (v == null || v.isEmpty) return 'Contraseña requerida'; if (v.length < 6) return 'Mínimo 6 caracteres'; return null; },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Crear Restaurante'),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _nombreRestCtrl.dispose(); _nombreCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }
}
