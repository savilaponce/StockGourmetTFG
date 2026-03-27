-- ============================================================
-- StockGourmet - Migration 001: Schema
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLA: restaurantes
-- Cada restaurante es un "tenant" aislado
-- ============================================================
CREATE TABLE public.restaurantes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre TEXT NOT NULL,
    direccion TEXT,
    telefono TEXT,
    email TEXT,
    plan_suscripcion TEXT NOT NULL DEFAULT 'free' CHECK (plan_suscripcion IN ('free', 'basic', 'premium')),
    suscripcion_activa BOOLEAN NOT NULL DEFAULT true,
    max_usuarios INTEGER NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: profiles
-- Extiende auth.users con datos de la app
-- ============================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes(id) ON DELETE CASCADE,
    nombre_completo TEXT NOT NULL,
    rol TEXT NOT NULL DEFAULT 'staff' CHECK (rol IN ('admin', 'chef', 'staff')),
    avatar_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para búsquedas frecuentes por restaurante
CREATE INDEX idx_profiles_restaurante ON public.profiles(restaurante_id);

-- ============================================================
-- TABLA: ingredientes
-- Inventario de ingredientes por restaurante
-- ============================================================
CREATE TABLE public.ingredientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    categoria TEXT DEFAULT 'otros' CHECK (categoria IN (
        'carnes', 'pescados', 'verduras', 'frutas', 'lacteos',
        'cereales', 'especias', 'aceites', 'bebidas', 'congelados', 'otros'
    )),
    stock_actual NUMERIC(10, 3) NOT NULL DEFAULT 0,
    stock_minimo NUMERIC(10, 3) DEFAULT 0,
    unidad TEXT NOT NULL DEFAULT 'kg' CHECK (unidad IN ('kg', 'g', 'l', 'ml', 'unidad')),
    coste_por_unidad NUMERIC(10, 4) NOT NULL DEFAULT 0, -- Coste en claro (simplificado para MVP)
    proveedor TEXT,
    fecha_caducidad DATE,
    notas TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ingredientes_restaurante ON public.ingredientes(restaurante_id);
CREATE INDEX idx_ingredientes_caducidad ON public.ingredientes(fecha_caducidad)
    WHERE fecha_caducidad IS NOT NULL AND activo = true;
CREATE INDEX idx_ingredientes_nombre ON public.ingredientes(restaurante_id, nombre);

-- ============================================================
-- TABLA: platos
-- Platos/recetas del restaurante
-- ============================================================
CREATE TABLE public.platos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    categoria TEXT DEFAULT 'principal' CHECK (categoria IN (
        'entrante', 'principal', 'postre', 'bebida', 'acompanamiento', 'menu'
    )),
    precio_venta NUMERIC(10, 2),
    imagen_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_platos_restaurante ON public.platos(restaurante_id);

-- ============================================================
-- TABLA: plato_ingredientes
-- Tabla intermedia: qué ingredientes lleva cada plato
-- ============================================================
CREATE TABLE public.plato_ingredientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plato_id UUID NOT NULL REFERENCES public.platos(id) ON DELETE CASCADE,
    ingrediente_id UUID NOT NULL REFERENCES public.ingredientes(id) ON DELETE CASCADE,
    cantidad NUMERIC(10, 3) NOT NULL,
    -- La unidad se hereda del ingrediente
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Un ingrediente solo puede aparecer una vez por plato
    UNIQUE(plato_id, ingrediente_id)
);

CREATE INDEX idx_plato_ingredientes_plato ON public.plato_ingredientes(plato_id);
CREATE INDEX idx_plato_ingredientes_ingrediente ON public.plato_ingredientes(ingrediente_id);

-- ============================================================
-- TRIGGER: Actualizar updated_at automáticamente
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_restaurantes
    BEFORE UPDATE ON public.restaurantes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_profiles
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_ingredientes
    BEFORE UPDATE ON public.ingredientes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_platos
    BEFORE UPDATE ON public.platos
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- TRIGGER: Crear perfil automáticamente al registrar usuario
-- Se activa desde el registro en la app (ver auth_service.dart)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, restaurante_id, nombre_completo, rol)
    VALUES (
        NEW.id,
        (NEW.raw_user_meta_data->>'restaurante_id')::UUID,
        COALESCE(NEW.raw_user_meta_data->>'nombre_completo', 'Usuario'),
        COALESCE(NEW.raw_user_meta_data->>'rol', 'staff')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
