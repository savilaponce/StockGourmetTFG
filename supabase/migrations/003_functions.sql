-- ============================================================
-- StockGourmet - Migration 003: Funciones y Vistas
-- Ejecutar DESPUÉS de 002_rls_policies.sql
-- ============================================================

-- ============================================================
-- VISTA: v_plato_costes
-- Calcula coste, beneficio y margen de cada plato
-- Toda la lógica de cálculo se ejecuta en PostgreSQL (eficiente)
-- ============================================================
CREATE OR REPLACE VIEW public.v_plato_costes AS
SELECT
    p.id AS plato_id,
    p.restaurante_id,
    p.nombre,
    p.descripcion,
    p.categoria,
    p.precio_venta,
    p.activo,
    -- Coste total = SUM(cantidad_usada * coste_por_unidad del ingrediente)
    COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0) AS coste_total,
    -- Beneficio bruto
    CASE
        WHEN p.precio_venta IS NOT NULL
        THEN p.precio_venta - COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0)
        ELSE NULL
    END AS beneficio_bruto,
    -- Margen porcentual
    CASE
        WHEN p.precio_venta IS NOT NULL AND p.precio_venta > 0
        THEN ROUND(
            ((p.precio_venta - COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0))
            / p.precio_venta) * 100,
            2
        )
        ELSE NULL
    END AS margen_porcentual,
    -- Número de ingredientes
    COUNT(pi.id) AS num_ingredientes,
    p.created_at,
    p.updated_at
FROM public.platos p
LEFT JOIN public.plato_ingredientes pi ON p.id = pi.plato_id
LEFT JOIN public.ingredientes i ON pi.ingrediente_id = i.id
GROUP BY p.id, p.restaurante_id, p.nombre, p.descripcion,
         p.categoria, p.precio_venta, p.activo, p.created_at, p.updated_at;

-- ============================================================
-- VISTA: v_ingredientes_por_caducar
-- Ingredientes que caducan en los próximos N días
-- ============================================================
CREATE OR REPLACE VIEW public.v_ingredientes_por_caducar AS
SELECT
    i.*,
    i.fecha_caducidad - CURRENT_DATE AS dias_restantes,
    CASE
        WHEN i.fecha_caducidad < CURRENT_DATE THEN 'caducado'
        WHEN i.fecha_caducidad <= CURRENT_DATE + INTERVAL '3 days' THEN 'critico'
        WHEN i.fecha_caducidad <= CURRENT_DATE + INTERVAL '7 days' THEN 'alerta'
        ELSE 'ok'
    END AS estado_caducidad
FROM public.ingredientes i
WHERE i.activo = true
  AND i.fecha_caducidad IS NOT NULL
  AND i.fecha_caducidad <= CURRENT_DATE + INTERVAL '7 days'
ORDER BY i.fecha_caducidad ASC;

-- ============================================================
-- FUNCIÓN RPC: calcular_coste_plato
-- Llamable desde Flutter: supabase.rpc('calcular_coste_plato', params: {'plato_uuid': id})
-- ============================================================
CREATE OR REPLACE FUNCTION public.calcular_coste_plato(plato_uuid UUID)
RETURNS TABLE(
    coste_total NUMERIC,
    precio_venta NUMERIC,
    beneficio_bruto NUMERIC,
    margen_porcentual NUMERIC,
    ingredientes JSON
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0) AS coste_total,
        p.precio_venta,
        CASE
            WHEN p.precio_venta IS NOT NULL
            THEN p.precio_venta - COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0)
            ELSE NULL
        END AS beneficio_bruto,
        CASE
            WHEN p.precio_venta IS NOT NULL AND p.precio_venta > 0
            THEN ROUND(
                ((p.precio_venta - COALESCE(SUM(pi.cantidad * i.coste_por_unidad), 0))
                / p.precio_venta) * 100, 2)
            ELSE NULL
        END AS margen_porcentual,
        (
            SELECT json_agg(json_build_object(
                'nombre', i2.nombre,
                'cantidad', pi2.cantidad,
                'unidad', i2.unidad,
                'coste_unitario', i2.coste_por_unidad,
                'coste_linea', pi2.cantidad * i2.coste_por_unidad
            ))
            FROM public.plato_ingredientes pi2
            JOIN public.ingredientes i2 ON pi2.ingrediente_id = i2.id
            WHERE pi2.plato_id = plato_uuid
        ) AS ingredientes
    FROM public.platos p
    LEFT JOIN public.plato_ingredientes pi ON p.id = pi.plato_id
    LEFT JOIN public.ingredientes i ON pi.ingrediente_id = i.id
    WHERE p.id = plato_uuid
    GROUP BY p.id, p.precio_venta;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCIÓN RPC: dashboard_stats
-- Estadísticas del panel principal
-- ============================================================
CREATE OR REPLACE FUNCTION public.dashboard_stats()
RETURNS JSON AS $$
DECLARE
    mi_restaurante UUID;
    resultado JSON;
BEGIN
    mi_restaurante := public.get_my_restaurante_id();

    SELECT json_build_object(
        'total_ingredientes', (
            SELECT COUNT(*) FROM public.ingredientes
            WHERE restaurante_id = mi_restaurante AND activo = true
        ),
        'total_platos', (
            SELECT COUNT(*) FROM public.platos
            WHERE restaurante_id = mi_restaurante AND activo = true
        ),
        'ingredientes_por_caducar', (
            SELECT COUNT(*) FROM public.ingredientes
            WHERE restaurante_id = mi_restaurante
              AND activo = true
              AND fecha_caducidad IS NOT NULL
              AND fecha_caducidad <= CURRENT_DATE + INTERVAL '7 days'
        ),
        'ingredientes_caducados', (
            SELECT COUNT(*) FROM public.ingredientes
            WHERE restaurante_id = mi_restaurante
              AND activo = true
              AND fecha_caducidad IS NOT NULL
              AND fecha_caducidad < CURRENT_DATE
        ),
        'valor_inventario', (
            SELECT COALESCE(SUM(stock_actual * coste_por_unidad), 0)
            FROM public.ingredientes
            WHERE restaurante_id = mi_restaurante AND activo = true
        ),
        'plato_mas_rentable', (
            SELECT json_build_object('nombre', v.nombre, 'margen', v.margen_porcentual)
            FROM public.v_plato_costes v
            WHERE v.restaurante_id = mi_restaurante
              AND v.activo = true
              AND v.margen_porcentual IS NOT NULL
            ORDER BY v.margen_porcentual DESC
            LIMIT 1
        )
    ) INTO resultado;

    RETURN resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
