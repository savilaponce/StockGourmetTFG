# StockGourmet

> **Gestión inteligente de inventario y costes para restaurantes**
> TFG DAM 2025–2026 · Ilerna Albor Croft (Jerez de la Frontera)

StockGourmet es una aplicación móvil multiplataforma diseñada para que pequeños y medianos restaurantes digitalicen y automaticen la gestión de su inventario, el control de costes y el cumplimiento de la trazabilidad alimentaria. Reduce el desperdicio, calcula automáticamente el margen real de cada plato y proporciona alertas proactivas de caducidad y stock crítico, todo desde una interfaz pensada para el contexto real de una cocina profesional.

---

## Tabla de contenidos

1. [Características principales](#características-principales)
2. [Capturas y demo](#capturas-y-demo)
3. [Stack tecnológico](#stack-tecnológico)
4. [Requisitos previos](#requisitos-previos)
5. [Instalación rápida](#instalación-rápida)
6. [Configuración de Supabase](#configuración-de-supabase)
7. [Variables de entorno](#variables-de-entorno)
8. [Ejecutar la aplicación](#ejecutar-la-aplicación)
9. [Estructura del proyecto](#estructura-del-proyecto)
10. [Cómo probar la app](#cómo-probar-la-app)
11. [Pruebas y validación](#pruebas-y-validación)
12. [Solución de problemas](#solución-de-problemas)
13. [Roadmap](#roadmap)
14. [Equipo y contacto](#equipo-y-contacto)

---

## Características principales

- **Inventario en tiempo real** con stock por unidad, coste, proveedor, fecha de caducidad y categoría.
- **Gestión de platos con cálculo automático de costes**: el margen porcentual se actualiza en vivo a medida que se editan ingredientes, con codificación por color (verde / naranja / rojo).
- **Escáner de albaranes con OCR** (Google Cloud Vision) en tres pasos: capturar foto → revisar líneas extraídas → confirmar fusión o creación de ingredientes.
- **Histórico inmutable de movimientos de stock** (entrada, salida, merma, ajuste, albarán, producción) con trazabilidad completa: usuario, fecha, snapshot antes/después y coste.
- **Alertas proactivas** de caducidad y stock crítico, con badge numérico en la barra de navegación que se refresca cada 60 segundos.
- **Búsqueda global unificada** desde el dashboard, con resultados agrupados por tipo (ingredientes, platos, proveedores) y ejecución en paralelo.
- **Acciones por deslizamiento (swipe)** en el inventario: ajustar stock o ver platos donde se utiliza un ingrediente.
- **Multi-tenant seguro por diseño** mediante Row Level Security (RLS) nativa de PostgreSQL. Cada restaurante solo ve sus datos.
- **Multi-rol**: administrador, chef y staff, con permisos diferenciados sobre cada operación.
- **UI optimizada para cocina**: botones de 56 px, tipografía legible, fondo claro y modales tipo bottom sheet para que las acciones más frecuentes se completen en un solo toque.

---

## Capturas y demo

Próximamente incluiremos capturas reales en `docs/screenshots/`. Mientras tanto, el prototipo interactivo en Figma muestra los flujos completos:

🎨 **Prototipo Figma:** [Ver diseño completo](https://www.figma.com/design/8Ul0kyTF5vXwasrlJpv4IE/StockGourmet)

---

## Stack tecnológico

| Capa | Tecnología | Por qué |
|---|---|---|
| **Frontend** | Flutter 3.22 + Dart 3.4 | Compilación nativa para iOS y Android desde un único código base, rendimiento de 60/120 fps |
| **Estado** | Riverpod 2.x | Gestión reactiva con tipado fuerte, sin dependencia de `BuildContext` |
| **Navegación** | go_router 14 | Navegación declarativa con `ShellRoute`, deep linking y redirección por estado de auth |
| **Backend** | Supabase (PostgreSQL 15) | BaaS open-source con consultas SQL completas y RLS nativa |
| **Autenticación** | Supabase Auth (JWT) | Sesión persistente con `email/password` y soporte para roles personalizados |
| **OCR** | Google Cloud Vision API | Extracción de texto de albaranes con precisión > 95% |
| **Notificaciones push** | Firebase Cloud Messaging | (Pendiente, ver [Roadmap](#roadmap)) |
| **Pruebas de carga** | Apache JMeter 5.6 | Validado: 0% errores con 1.000 usuarios concurrentes |

---

## Requisitos previos

Antes de empezar, asegúrate de tener:

- **Flutter SDK 3.22+** ([instalación oficial](https://docs.flutter.dev/get-started/install))
- **Dart 3.4+** (incluido con Flutter)
- **Android Studio** con Android SDK API 34 (Android 14) y al menos un emulador configurado
- **Xcode 15+** si vas a compilar para iOS (solo macOS)
- **Git** 2.30+
- **Cuenta gratuita de Supabase** ([registro en supabase.com](https://supabase.com))
- **(Opcional) Cuenta de Google Cloud** con la API de Vision habilitada para probar el OCR

Verifica tu instalación con:

```bash
flutter doctor
```

Resuelve cualquier advertencia antes de continuar (las más habituales: aceptar licencias del SDK de Android con `flutter doctor --android-licenses` y configurar un emulador).

---

## Instalación rápida

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-organizacion/stockgourmet.git
cd stockgourmet

# 2. Cambiar a la rama de integración
git checkout develop

# 3. Descargar dependencias
flutter pub get

# 4. Verificar que compila sin errores
flutter analyze
```

---

## Configuración de Supabase

StockGourmet necesita un proyecto Supabase con su esquema, políticas RLS y vistas. El proceso es **una sola vez** por entorno.

### 1. Crear el proyecto

1. Accede a [app.supabase.com](https://app.supabase.com) y pulsa **New project**.
2. Indica el nombre (ej. `stockgourmet-dev`), región (`eu-west-1` para España) y una contraseña robusta para el usuario `postgres`.
3. Espera 2-3 minutos a que se aprovisione.
4. Anota desde **Settings → API** los siguientes valores (los necesitarás en el siguiente paso):
   - **Project URL** (formato `https://xxxxxxxxxxxx.supabase.co`)
   - **anon public** (clave pública del cliente)

### 2. Aplicar las migraciones SQL

> ⚠️ **Importante:** ejecuta las migraciones en el orden indicado. Cada una depende de la anterior.

Abre el **SQL Editor** del Dashboard de Supabase y ejecuta secuencialmente:

| Orden | Archivo | Crea |
|---|---|---|
| 1 | `supabase/migrations/001_schema.sql` | 5 tablas base (`restaurantes`, `profiles`, `ingredientes`, `platos`, `plato_ingredientes`) |
| 2 | `supabase/migrations/002_rls_policies.sql` | Políticas Row Level Security multi-tenant |
| 3 | `supabase/migrations/003_functions.sql` | Vistas y funciones RPC originales (`v_plato_costes`, `dashboard_stats`, etc.) |
| 4 | `supabase/migrations/004_alertas.sql` | Vista `v_alertas` y función `contar_alertas` |
| 5 | `supabase/migrations/005_albaranes.sql` | Soporte para datos OCR procesados |
| 6 | `supabase/migrations/006_movimientos.sql` | Tabla `movimientos_stock` y vista `v_evolucion_stock_30d` |

### 3. Verificar la instalación

Tras aplicar las 6 migraciones, ejecuta esta consulta en el SQL Editor para verificar que todo está correcto:

```sql
SELECT 'TABLE' AS tipo, table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'VIEW', table_name FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY tipo, table_name;
```

Debe devolver al menos **6 tablas** y **3 vistas**.

---

## Variables de entorno

Crea un archivo `.env` en la raíz del proyecto (ya está incluido en `.gitignore`, no se versionará):

```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
GOOGLE_VISION_API_KEY=AIzaSy...
APP_ENV=development
```

| Variable | Obligatoria | Descripción |
|---|---|---|
| `SUPABASE_URL` | ✅ | URL del proyecto Supabase |
| `SUPABASE_ANON_KEY` | ✅ | Clave anónima pública. Es pública por diseño; la seguridad recae en RLS |
| `GOOGLE_VISION_API_KEY` | ⚠️ Solo OCR | Clave de Google Cloud Vision para escanear albaranes |
| `APP_ENV` | ✅ | `development`, `staging` o `production` |

> **Nota:** la `anon key` es pública por diseño en Supabase. La seguridad real está en las políticas RLS, que se aplican a nivel de base de datos y son inmunes a manipulaciones del cliente.

---

## Ejecutar la aplicación

### En emulador Android

```bash
# Asegúrate de que el emulador está iniciado
flutter devices

# Ejecutar en modo debug
flutter run --dart-define-from-file=.env
```

La primera compilación tarda 5-10 minutos. Las posteriores son incrementales y mucho más rápidas (segundos).

### En dispositivo físico Android

1. Activa **Opciones de desarrollador** (Ajustes → Acerca del teléfono → pulsa 7 veces el número de compilación).
2. Activa **Depuración USB**.
3. Conecta el dispositivo al ordenador y acepta la solicitud de confianza.
4. Ejecuta `flutter run --dart-define-from-file=.env`.

### En navegador (modo desarrollo rápido)

```bash
flutter run -d chrome --web-port=3000 --dart-define-from-file=.env
```

> ⚠️ El modo web no soporta la cámara para OCR ni las notificaciones push. Útil para depurar lógica y UI rápidamente.

### En iOS (solo macOS)

```bash
cd ios && pod install && cd ..
flutter run -d "iPhone 15" --dart-define-from-file=.env
```

---

## Estructura del proyecto

```
stockgourmet/
├── lib/
│   ├── main.dart                          # Punto de entrada, inicialización de Supabase
│   ├── app.dart                           # MaterialApp, tema corporativo, GoRouter
│   ├── models/
│   │   └── models.dart                    # Restaurante, Profile, Ingrediente, Plato, etc.
│   ├── services/
│   │   ├── auth_service.dart              # Login, registro, gestión de sesión
│   │   ├── ingrediente_service.dart       # CRUD inventario + ajuste de stock
│   │   ├── plato_service.dart             # CRUD platos + cálculo de costes
│   │   ├── proveedor_service.dart         # Gestión de proveedores
│   │   ├── movimiento_stock_service.dart  # Histórico inmutable de movimientos
│   │   ├── notificacion_service.dart      # Alertas in-app y FCM
│   │   └── ocr_service.dart               # Escaneo de albaranes
│   ├── screens/
│   │   ├── auth/                          # login_screen, register_screen
│   │   ├── home/                          # home_screen, alertas_screen, mas_screen
│   │   ├── inventario/                    # inventario_screen, ingrediente_form_screen, platos_por_ingrediente_screen
│   │   ├── platos/                        # platos_screen, plato_form_screen, plato_detail_screen
│   │   ├── albaranes/                     # scan_screen, review_lines_screen, decisions_screen
│   │   └── buscar/                        # buscar_screen (búsqueda global)
│   └── widgets/
│       ├── empty_state.dart               # Estados vacíos reutilizables
│       ├── loading_skeleton.dart          # Skeletons con shimmer
│       └── badge_alertas.dart             # Badge numérico de alertas
├── supabase/
│   └── migrations/                        # 6 archivos SQL (ver tabla anterior)
├── test/                                  # Pruebas unitarias y de widget
├── android/                               # Configuración nativa Android
├── ios/                                   # Configuración nativa iOS
├── pubspec.yaml                           # Dependencias Flutter
├── .env.example                           # Plantilla de variables de entorno
└── README.md                              # Este archivo
```

---

## Cómo probar la app

### Flujo recomendado para evaluar la aplicación

1. **Registro de un restaurante.** Pulsa "Crear cuenta" en la pantalla de bienvenida e introduce nombre del restaurante, tu nombre, email y contraseña. Quedas creado automáticamente como administrador.

2. **Alta de tu primer ingrediente.** Ve a la pestaña **Inventario** y pulsa el botón flotante **+**. Crea, por ejemplo:
   - Nombre: `Tomate Pera`
   - Categoría: `Verduras`
   - Stock actual: `5` kg
   - Coste por unidad: `1.80` €/kg
   - Stock mínimo: `2` kg
   - Caducidad: 5 días desde hoy

3. **Crear un plato.** Ve a **Más → Platos → Nuevo plato**. Crea uno simple:
   - Nombre: `Ensalada de tomate`
   - PVP: `8.00` €
   - Añade el ingrediente que has creado, con cantidad `0.250` kg.
   - Observa cómo el coste, beneficio y margen se calculan en vivo en la parte inferior.

4. **Probar swipe actions.** Vuelve a Inventario y desliza el ingrediente:
   - **A la izquierda** → botón "Ajustar". Prueba a registrar una **merma** de `1` kg.
   - **A la derecha** → botón "Platos". Verás la ensalada que acabas de crear.

5. **Probar alertas.** Ve a la pestaña **Alertas**. Verás aviso de caducidad próxima.

6. **Probar búsqueda global.** Pulsa la barra de búsqueda del dashboard y escribe `tom`. Verás resultados agrupados por tipo.

7. **Verificar el histórico.** Cada cambio de stock que hayas hecho queda registrado en la tabla `movimientos_stock`. Puedes consultarlo desde el SQL Editor de Supabase:

```sql
SELECT tipo, cantidad, stock_antes, stock_despues, created_at
FROM movimientos_stock
ORDER BY created_at DESC;
```

### Cuentas de prueba

Si has aplicado las migraciones a un proyecto Supabase nuevo, no hay cuentas precargadas. Usa el flujo de registro normal.

> 💡 **Tip:** para probar la separación multi-tenant, crea dos restaurantes con cuentas distintas y verifica que cada uno solo ve sus propios datos.

---

## Pruebas y validación

### Pruebas funcionales

```bash
flutter test
```

El proyecto incluye 17 casos de prueba documentados (PT-01 a PT-17) que validan los flujos críticos: autenticación, CRUD, cálculo de costes, RLS multi-tenant, validaciones de entrada, etc. Detalle completo en la **memoria del TFG**, sección 12.2.

### Pruebas de carga (JMeter)

Los planes de prueba están en `tests/jmeter/` y validan 5 escenarios (100, 250, 500, 750 y 1.000 usuarios concurrentes). Resultados reales: **0% errores** y P95 < 2.000 ms en todos los escenarios. Detalle en la sección 12bis de la memoria.

### Análisis estático

```bash
flutter analyze       # Lint del código Dart
dart format .         # Formateo automático
```

---

## Solución de problemas

<details>
<summary><strong>flutter pub get falla con error de versión de Dart</strong></summary>

El proyecto requiere Dart 3.4+. Verifica con `flutter --version`. Si tu versión es anterior, actualiza Flutter con `flutter upgrade`.
</details>

<details>
<summary><strong>"Permission denied" al ejecutar la app y consultar la base de datos</strong></summary>

Es síntoma típico de Row Level Security activa pero sin las políticas correctas. Verifica que has ejecutado `002_rls_policies.sql` completo y que tu usuario tiene un perfil en la tabla `profiles` con `restaurante_id` válido.
</details>

<details>
<summary><strong>El escáner de albaranes devuelve resultados vacíos</strong></summary>

Causas habituales:
- La variable `GOOGLE_VISION_API_KEY` no está configurada o es incorrecta.
- La API de Cloud Vision no está habilitada en tu proyecto de Google Cloud.
- La imagen es demasiado pequeña o tiene mucho reflejo. Prueba con un albarán bien iluminado y enfocado.
</details>

<details>
<summary><strong>"new row violates row-level security policy"</strong></summary>

Significa que el usuario actual no tiene permisos para insertar en esa tabla con su rol. Comprueba en la tabla `profiles` que el `rol` es correcto (`admin`, `chef` o `staff`) y que el `restaurante_id` coincide con el de los datos que intentas insertar.
</details>

<details>
<summary><strong>El emulador Android no aparece al ejecutar flutter devices</strong></summary>

1. Abre Android Studio → AVD Manager.
2. Inicia el emulador desde ahí.
3. Vuelve a ejecutar `flutter devices`. Debería aparecer ahora.
</details>

<details>
<summary><strong>Build de iOS falla con "No signing identity found"</strong></summary>

Necesitas configurar tu cuenta de Apple Developer en Xcode (Preferences → Accounts) y seleccionar tu equipo de desarrollo en `ios/Runner.xcworkspace → Signing & Capabilities`.
</details>

---

## Roadmap

**Implementado** ✅
- MVP completo: autenticación, CRUD inventario y platos, dashboard, alertas, RLS multi-tenant
- OCR de albaranes con Google Cloud Vision
- Sistema de alertas in-app con badge numérico
- Iteración 2: búsqueda global, histórico de movimientos, mejoras UX (swipe, skeletons, pestaña Más)

**Próximamente** 🔜
- Pantalla analítica de detalle de ingrediente con gráfico de evolución de stock a 30 días
- Notificaciones push reales con Firebase Cloud Messaging
- Papelera y restauración de elementos borrados
- Exportación de informes a PDF y Excel

**Largo plazo** 🌱
- Sugerencias de platos generadas por IA (Google Gemini) basadas en ingredientes próximos a caducar
- Integración con software TPV (Revo, Lightspeed, Agora)
- Modo offline con sincronización
- Internacionalización (i18n) a inglés, francés y portugués

---

## Equipo y contacto

Proyecto desarrollado como Trabajo Final de Ciclo del Grado Superior de Desarrollo de Aplicaciones Multiplataforma (DAM) en **Ilerna Albor Croft** (Jerez de la Frontera), curso 2025-2026.

| | |
|---|---|
| **Autores** | Samuel Ávila Ponce · Gonzalo Alfaro Tirado |
| **Tutor** | D. José Manuel Ruiz González |
| **Centro** | Ilerna Albor Croft — Jerez de la Frontera |

Para más información técnica, consulta la **memoria completa del TFG** (75 páginas) incluida en el repositorio.

---

## Licencia

Este proyecto se distribuye bajo licencia académica para evaluación en el contexto del Trabajo Final de Ciclo. Cualquier uso comercial requiere autorización expresa de los autores.

---
