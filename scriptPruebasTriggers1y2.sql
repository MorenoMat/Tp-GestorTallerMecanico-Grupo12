-- =====================================================================
-- SCRIPT DE PRUEBAS PARA LOS TRIGGERS
-- Prueba del Trigger 1: TR_ReparacionCompletaGuardaFechaFin
-- Prueba del Trigger 2: TR_DetallePresupuesto_AcumularImporte
-- =====================================================================

USE TallerMecanico
GO

-- =====================================================================
-- PRUEBAS DEL TRIGGER 2
-- TR_DetallePresupuesto_AcumularImporte
-- Verifica que el importeTotal se acumule automáticamente
-- =====================================================================
GO

PRINT ''
PRINT '--- Paso 1: Verificar presupuestos pendientes antes de agregar detalles ---'

SELECT  idPresupuesto, importeTotal, estado FROM dbo.Presupuestos 
--select * from dbo.Presupuestos
--WHERE idPresupuesto IN (1, 2, 3)

GO

SELECT * from dbo.DetallePresupuesto -- ningun detalle esta en presupuesto 1 ni en otro

PRINT ''
PRINT '--- Paso 2: Insertar primer detalle en Presupuesto 1 (importeTotal NULL → 150.00) ---'
INSERT INTO dbo.DetallePresupuesto (idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (1, 'Cambio de pastillas delanteras', 1, 1, 150.00)

PRINT 'Detalle insertado. Verificando importeTotal...'
SELECT 
    'Presupuesto 1' AS [Caso], 
    idPresupuesto, 
    importeTotal AS [Importe Total Esperado: 150.00]
FROM dbo.Presupuestos 
WHERE idPresupuesto = 1
GO

PRINT ''
PRINT '--- Paso 3: Insertar segundo detalle en Presupuesto 2 ---'
INSERT INTO dbo.DetallePresupuesto (idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (2, 'Cambio de filtro de aire', 3, 1, 50.00)

PRINT 'Primer detalle insertado. Verificando importeTotal...'
SELECT 
    'Presupuesto 2 (Detalle 1)' AS [Caso], 
    idPresupuesto, 
    importeTotal AS [Importe Total Esperado: 50.00]
FROM dbo.Presupuestos 
WHERE idPresupuesto = 2
GO

PRINT ''  -- sumo OTRO detalle al presupuesto 2
PRINT '--- Paso 4: Agregar SEGUNDO detalle al mismo Presupuesto 2 (acumulación) ---'
INSERT INTO dbo.DetallePresupuesto (idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (2, 'Cambio de bujías', 6, 1, 80.00)

PRINT 'Segundo detalle insertado. Verificando acumulación...'
SELECT 
    'Presupuesto 2 (Detalle 1 + 2)' AS [Caso], 
    idPresupuesto, 
    importeTotal AS [Importe Total Esperado: 130.00 (50+80)]
FROM dbo.Presupuestos 
WHERE idPresupuesto = 2
GO
-- tuvo que haber SUMADO EL IMPORTE


PRINT ''
PRINT '--- Paso 5: Agregar TERCER detalle al Presupuesto 2 (más acumulación) ---'
INSERT INTO dbo.DetallePresupuesto (idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (2, 'Cambio de disco de freno', 2, 2, 250.00)

PRINT 'Tercer detalle insertado. Verificando acumulación...'
SELECT 'Presupuesto 2 (Detalle 1 + 2 + 3)' AS [Caso], -- concatenacion de texto
    idPresupuesto, 
    importeTotal AS [Importe Total Esperado: 630.00 (50+80+2*250)]
FROM dbo.Presupuestos 
WHERE idPresupuesto = 2
GO

PRINT '' -- agrego mas de 1 mismo tipo de repuesto
PRINT '--- Paso 6: Insertar detalle en Presupuesto 3 con cantidades múltiples ---'
INSERT INTO dbo.DetallePresupuesto (idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (3, 'Cambio de aceite motor 5W-30', 7, 3, 200.00) -- 200 vale cada uno

PRINT 'Detalle con cantidad=3 insertado. Verificando...'
SELECT 
    'Presupuesto 3' AS [Caso], 
    idPresupuesto, 
    importeTotal AS [Importe Total Esperado: 600.00 (3*200)]
FROM dbo.Presupuestos 
WHERE idPresupuesto = 3
GO

PRINT ''
PRINT '═══ RESUMEN TRIGGER 2: Importes Acumulados por Presupuesto ═══'
SELECT 
    idPresupuesto,
    descripcion,
    importeTotal AS [Importe Total Acumulado],
    estado,
    (SELECT COUNT(*) FROM dbo.DetallePresupuesto dp WHERE dp.idPresupuesto = p.idPresupuesto) AS [Cantidad de Detalles]
FROM dbo.Presupuestos p
WHERE idPresupuesto IN (1, 2, 3)
ORDER BY idPresupuesto
GO

-- =====================================================================
-- SECCIÓN 2: PRUEBAS DEL TRIGGER 1
-- TR_ReparacionCompletaGuardaFechaFin
-- Verifica que fechaFin se asigne automáticamente al marcar como Completada
-- =====================================================================


GO

PRINT ''
PRINT '--- Paso 1: Crear un presupuesto APROBADO para la reparación ---'

-- Primero asegurarse de que existe un PRESUPUESTO aprobado

UPDATE dbo.Presupuestos 
SET estado = 'Aprobado'
WHERE idPresupuesto = 4

PRINT 'Presupuesto 4 marcado como Aprobado'
SELECT idPresupuesto, estado FROM dbo.Presupuestos WHERE idPresupuesto = 4
GO

PRINT ''
PRINT '--- Paso 2: Insertar una REPARACIÓN en estado "En Progreso" ---'

--Chequeo que no existan reparaciones
SELECT idReparacion,estado,idPresupuesto from dbo.reparaciones


INSERT INTO dbo.Reparaciones (idPresupuesto, descripcionTrabajo)
VALUES (4, 'Reparación del sistema completo')

 --guardo el idReparacion para utilizarlo  en el select

PRINT 'Reparación creada. Verificando estado inicial...'
SELECT 
    idReparacion,
    idPresupuesto,
    fechaInicio,
    fechaFin AS [fechaFin ANTES (debe ser NULL)],
    estado
FROM dbo.Reparaciones
WHERE idReparacion = 1
GO

PRINT ''
PRINT '--- Paso 3: Cambiar estado de Reparación a "Completada" (DISPARA TRIGGER 1) ---'



-- Actualizar estado a Completada
UPDATE dbo.Reparaciones
SET estado = 'Completada'
WHERE idReparacion = 1

PRINT 'Reparación marcada como "Completada". Verificando que fechaFin fue asignada...'
GO

PRINT ''
PRINT '--- Paso 4: VERIFICAR RESULTADO DEL TRIGGER 1 ---'

SELECT 
    'DESPUÉS de marcar Completada' AS Estado,
    idReparacion,
    idPresupuesto,
    fechaInicio,
    fechaFin AS fechaFin_DESPUÉS,
    estado,
    CASE 
        WHEN fechaFin IS NOT NULL THEN ' TRIGGER FUNCIONÓ CORRECTAMENTE'
        ELSE ' ERROR: fechaFin sigue siendo NULL'
    END AS [Resultado]
FROM dbo.Reparaciones
WHERE idReparacion =  1;
GO

PRINT ''
PRINT '═══ RESUMEN TRIGGER 1: Reparaciones con fechaFin Asignada ═══'
SELECT 
    idReparacion,
    idPresupuesto,
    descripcionTrabajo,
    fechaInicio,
    fechaFin,
    estado,
    CASE 
        WHEN estado = 'Completada' AND fechaFin IS NOT NULL THEN 'Correcto'
        WHEN estado = 'En Progreso' AND fechaFin IS NULL THEN 'Normal (aún en progreso)'
        ELSE 'Verificar'
    END AS [Validación]
FROM dbo.Reparaciones
ORDER BY idReparacion DESC
GO

-- =====================================================================
-- SECCIÓN 3: PRUEBA ADICIONAL - MÚLTIPLES ACTUALIZACIONES
-- =====================================================================

PRINT ''
PRINT '╔════════════════════════════════════════════════════════════════╗'
PRINT '║        PRUEBA ADICIONAL: Cambios de Estado Múltiples          ║'
PRINT '╚════════════════════════════════════════════════════════════════╝'
GO

PRINT ''
PRINT '--- Crear una reparación adicional para pruebas múltiples ---'

-- Crear otro presupuesto aprobado si es necesario
INSERT INTO dbo.Presupuestos (idVehiculo, idMecanico, fechaEstimadaFin, descripcion, estado)
VALUES (1, 2, DATEADD(DAY, 5, GETDATE()), 'Revisión general', 'Aprobado')

DECLARE @idPresupuesto_Adicional INT = SCOPE_IDENTITY()

INSERT INTO dbo.Reparaciones (idPresupuesto, descripcionTrabajo)
VALUES (@idPresupuesto_Adicional, 'Revisión completa del motor')

DECLARE @idReparacion_Adicional INT = SCOPE_IDENTITY()

PRINT 'Nueva reparación creada. Estado inicial:'
SELECT 
    idReparacion,
    estado,
    fechaFin,
    'Antes de actualizar' AS [Fase]
FROM dbo.Reparaciones
WHERE idReparacion = @idReparacion_Adicional
GO

PRINT ''
PRINT '--- Cambiar a "Cancelada" (NO debería activar el trigger de fechaFin) ---'

UPDATE dbo.Reparaciones
SET estado = 'Cancelada'
WHERE idReparacion = (SELECT MAX(idReparacion) FROM dbo.Reparaciones)

PRINT 'Después de cambiar a Cancelada:'
SELECT 
    idReparacion,
    estado,
    fechaFin,
    'Cancelada (sin fechaFin)' AS [Resultado]
FROM dbo.Reparaciones
WHERE idReparacion = (SELECT MAX(idReparacion) FROM dbo.Reparaciones)
GO

-- =====================================================================
-- SECCIÓN 4: REPORTE FINAL
-- =====================================================================

PRINT ''
PRINT '╔════════════════════════════════════════════════════════════════╗'
PRINT '║              REPORTE FINAL DE VALIDACIÓN                      ║'
PRINT '╚════════════════════════════════════════════════════════════════╝'
GO

PRINT ''
PRINT 'TRIGGER 2 - Estado de Presupuestos con Detalles:'
SELECT 
    p.idPresupuesto,
    p.descripcion,
    COUNT(dp.idDetalle) AS [Cantidad Detalles],
    p.importeTotal AS [Importe Total (Acumulado)],
    CASE 
        WHEN p.importeTotal > 0 THEN '✓ Acumulación correcta'
        WHEN p.importeTotal IS NULL AND COUNT(dp.idDetalle) = 0 THEN 'Sin detalles'
        ELSE 'Revisar'
    END AS [Validación Trigger 2]
FROM dbo.Presupuestos p
LEFT JOIN dbo.DetallePresupuesto dp ON p.idPresupuesto = dp.idPresupuesto
WHERE p.idPresupuesto IN (1, 2, 3, 4, 5)
GROUP BY p.idPresupuesto, p.descripcion, p.importeTotal
ORDER BY p.idPresupuesto
GO

PRINT ''
PRINT 'TRIGGER 1 - Estado de Reparaciones con fechaFin:'
SELECT 
    r.idReparacion,
    r.descripcionTrabajo,
    r.estado,
    r.fechaInicio,
    r.fechaFin,
    CASE 
        WHEN r.estado = 'Completada' AND r.fechaFin IS NOT NULL THEN '✓ Trigger 1 funcionó'
        WHEN r.estado = 'Completada' AND r.fechaFin IS NULL THEN '✗ Trigger 1 NO funcionó'
        WHEN r.estado = 'En Progreso' AND r.fechaFin IS NULL THEN '✓ Normal (en progreso)'
        WHEN r.estado = 'Cancelada' AND r.fechaFin IS NULL THEN '✓ Normal (cancelada)'
        ELSE 'Revisar'
    END AS [Validación Trigger 1]
FROM dbo.Reparaciones r
ORDER BY r.idReparacion DESC
GO

PRINT ''
PRINT '════════════════════════════════════════════════════════════════'
PRINT '                 PRUEBAS COMPLETADAS'
PRINT '════════════════════════════════════════════════════════════════'
