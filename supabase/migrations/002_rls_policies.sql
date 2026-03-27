-- ============================================================
-- StockGourmet - Migration 002: Row Level Security (RLS)
-- Ejecutar DESPUÉS de 001_schema.sql
-- ============================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE public.restaurantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plato_ingredientes ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- FUNCIÓN AUXILIAR: Obtener restaurante_id del usuario actual
-- Usada en todas las políticas RLS
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_restaurante_id()
RETURNS UUID AS $$
    SELECT restaurante_id
    FROM public.profiles
    WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- FUNCIÓN AUXILIAR: Obtener rol del usuario actual
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_rol()
RETURNS TEXT AS $$
    SELECT rol
    FROM public.profiles
    WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- POLÍTICAS: restaurantes
-- Solo el admin puede ver/editar su propio restaurante
-- ============================================================
CREATE POLICY "Usuarios ven su restaurante"
    ON public.restaurantes FOR SELECT
    USING (id = public.get_my_restaurante_id());

CREATE POLICY "Admin edita su restaurante"
    ON public.restaurantes FOR UPDATE
    USING (id = public.get_my_restaurante_id() AND public.get_my_rol() = 'admin');

-- ============================================================
-- POLÍTICAS: profiles
-- Admin gestiona perfiles de su restaurante
-- Todos ven los perfiles de su restaurante
-- ============================================================
CREATE POLICY "Usuarios ven perfiles de su restaurante"
    ON public.profiles FOR SELECT
    USING (restaurante_id = public.get_my_restaurante_id());

CREATE POLICY "Admin inserta perfiles"
    ON public.profiles FOR INSERT
    WITH CHECK (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() = 'admin'
    );

CREATE POLICY "Admin actualiza perfiles de su restaurante"
    ON public.profiles FOR UPDATE
    USING (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() = 'admin'
    );

-- Un usuario puede actualizar su propio perfil (nombre, avatar)
CREATE POLICY "Usuario actualiza su propio perfil"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        -- No puede cambiar su propio rol ni restaurante
        AND rol = (SELECT rol FROM public.profiles WHERE id = auth.uid())
        AND restaurante_id = public.get_my_restaurante_id()
    );

-- ============================================================
-- POLÍTICAS: ingredientes
-- Todos ven ingredientes de su restaurante
-- Admin y Chef pueden crear/editar/borrar
-- Staff solo lectura
-- ============================================================
CREATE POLICY "Usuarios ven ingredientes de su restaurante"
    ON public.ingredientes FOR SELECT
    USING (restaurante_id = public.get_my_restaurante_id());

CREATE POLICY "Admin y Chef crean ingredientes"
    ON public.ingredientes FOR INSERT
    WITH CHECK (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

CREATE POLICY "Admin y Chef editan ingredientes"
    ON public.ingredientes FOR UPDATE
    USING (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

CREATE POLICY "Admin y Chef eliminan ingredientes"
    ON public.ingredientes FOR DELETE
    USING (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

-- ============================================================
-- POLÍTICAS: platos
-- Misma lógica que ingredientes
-- ============================================================
CREATE POLICY "Usuarios ven platos de su restaurante"
    ON public.platos FOR SELECT
    USING (restaurante_id = public.get_my_restaurante_id());

CREATE POLICY "Admin y Chef crean platos"
    ON public.platos FOR INSERT
    WITH CHECK (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

CREATE POLICY "Admin y Chef editan platos"
    ON public.platos FOR UPDATE
    USING (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

CREATE POLICY "Admin y Chef eliminan platos"
    ON public.platos FOR DELETE
    USING (
        restaurante_id = public.get_my_restaurante_id()
        AND public.get_my_rol() IN ('admin', 'chef')
    );

-- ============================================================
-- POLÍTICAS: plato_ingredientes
-- Acceso basado en si el plato pertenece al restaurante
-- ============================================================
CREATE POLICY "Usuarios ven composición de platos de su restaurante"
    ON public.plato_ingredientes FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.platos
            WHERE platos.id = plato_ingredientes.plato_id
            AND platos.restaurante_id = public.get_my_restaurante_id()
        )
    );

CREATE POLICY "Admin y Chef gestionan composición de platos"
    ON public.plato_ingredientes FOR INSERT
    WITH CHECK (
        public.get_my_rol() IN ('admin', 'chef')
        AND EXISTS (
            SELECT 1 FROM public.platos
            WHERE platos.id = plato_ingredientes.plato_id
            AND platos.restaurante_id = public.get_my_restaurante_id()
        )
    );

CREATE POLICY "Admin y Chef editan composición de platos"
    ON public.plato_ingredientes FOR UPDATE
    USING (
        public.get_my_rol() IN ('admin', 'chef')
        AND EXISTS (
            SELECT 1 FROM public.platos
            WHERE platos.id = plato_ingredientes.plato_id
            AND platos.restaurante_id = public.get_my_restaurante_id()
        )
    );

CREATE POLICY "Admin y Chef eliminan ingredientes de platos"
    ON public.plato_ingredientes FOR DELETE
    USING (
        public.get_my_rol() IN ('admin', 'chef')
        AND EXISTS (
            SELECT 1 FROM public.platos
            WHERE platos.id = plato_ingredientes.plato_id
            AND platos.restaurante_id = public.get_my_restaurante_id()
        )
    );
