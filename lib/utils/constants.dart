/// Constantes de la aplicación StockGourmet
library;

class AppConstants {
  AppConstants._(); // No instanciable

  // Roles
  static const String rolAdmin = 'admin';
  static const String rolChef = 'chef';
  static const String rolStaff = 'staff';

  static const List<String> roles = [rolAdmin, rolChef, rolStaff];

  static String rolLabel(String rol) => switch (rol) {
    'admin' => 'Administrador',
    'chef'  => 'Jefe de Cocina',
    'staff' => 'Personal',
    _       => rol,
  };

  // Categorías de ingredientes
  static const Map<String, String> categoriasIngredientes = {
    'carnes': '🥩 Carnes',
    'pescados': '🐟 Pescados',
    'verduras': '🥬 Verduras',
    'frutas': '🍎 Frutas',
    'lacteos': '🧀 Lácteos',
    'cereales': '🌾 Cereales',
    'especias': '🌶️ Especias',
    'aceites': '🫒 Aceites',
    'bebidas': '🥤 Bebidas',
    'congelados': '🧊 Congelados',
    'otros': '📦 Otros',
  };

  // Categorías de platos
  static const Map<String, String> categoriasPlatos = {
    'entrante': '🥗 Entrante',
    'principal': '🍽️ Principal',
    'postre': '🍰 Postre',
    'bebida': '🍷 Bebida',
    'acompanamiento': '🥖 Acompañamiento',
    'menu': '📋 Menú',
  };

  // Unidades
  static const Map<String, String> unidades = {
    'kg': 'Kilogramos',
    'g': 'Gramos',
    'l': 'Litros',
    'ml': 'Mililitros',
    'unidad': 'Unidades',
  };

  // Días para alertas de caducidad
  static const int diasAlertaCaducidad = 7;
  static const int diasCriticoCaducidad = 3;
}
