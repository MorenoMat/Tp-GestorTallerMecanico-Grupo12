create database TallerMecanico
go

use TallerMecanico
go

-- ============================================================
-- TABLA: Clientes
-- ============================================================
create table dbo.Clientes
(
idCliente int identity(1,1) primary key,
DNI varchar(20) not null unique,
Apellido varchar(50) not null,
Nombre varchar(50) not null,
Telefono varchar(20) not null,
Email varchar(100) not null unique,
Direccion varchar(150) not null,
FechaAlta date not null default getdate()
)

-- ============================================================
-- TABLA: Mecanicos
-- Responsable: Mateo Nahuel Moreno
-- ============================================================
create table dbo.Mecanicos
(
idMecanico int identity(1,1) primary key,
nombreMecanico varchar(50) not null,
ApellidoMecanico varchar(50) not null
)

-- ============================================================
-- TABLA: Repuestos
-- Responsable: Mateo Nahuel Moreno
-- ============================================================
create table dbo.Repuestos
(
idRepuesto int identity(1,1) primary key,
nombreRepuesto varchar(50) not null unique,
descripcionRepuesto varchar(60) not null,
precio decimal(10,2) not null default 0 check(precio >= 0),
stock int not null check(stock >= 0)
)

-- ============================================================
-- TABLA: Vehiculos
-- Responsable: Mauro Sinopoli
-- ============================================================
create table dbo.Vehiculos
(
idVehiculo int identity(1,1) primary key,
idCliente int not null,
Patente varchar(10) not null unique,
Marca varchar(50) not null,
Modelo varchar(50) not null,
Anio int not null check(anio >= 1990),
Color varchar(30)  null,
FechaAlta date not null default getdate(),
foreign key (idCliente) references dbo.Clientes (idCliente)
)

-- ============================================================
-- TABLA: Presupuestos
-- ============================================================
create table dbo.Presupuestos
(
idPresupuesto int identity(1,1) primary key,
idVehiculo int not null,
idMecanico int not null,
fechaPresupuesto date not null default getdate(),
fechaEstimadaFin date not null,
descripcion varchar(400) not null,
importeTotal decimal(10,2)null,
estado varchar(20) not null check (estado in ('Pendiente','Aprobado','Rechazado','Finalizado'))
default 'Pendiente',
foreign key (idVehiculo) references dbo.Vehiculos (idVehiculo),
foreign key (idMecanico) references dbo.Mecanicos (idMecanico),
constraint CK_Presupuestos_Fechas
check (fechaEstimadaFin is null or fechaEstimadaFin >= fechaPresupuesto)
)

-- ============================================================
-- TABLA: Reparaciones
-- ============================================================
create table dbo.Reparaciones
(
idReparacion int identity(1,1) primary key,
idPresupuesto int not null,
fechaInicio date not null default getdate(),
fechaFin date null,
estado varchar(20) not null
check (estado in ('En Progreso','Completada','Cancelada'))
default 'En Progreso',
descripcionTrabajo varchar(300) not null,
foreign key (idPresupuesto) references dbo.Presupuestos (idPresupuesto),
constraint CK_Reparaciones_Fechas
check (fechaFin is null or fechaFin >= fechaInicio)
)

-- ============================================================
-- TABLA: DetallePresupuesto
-- ============================================================
create table dbo.DetallePresupuesto
(
idDetalle int identity(1,1) primary key,
idPresupuesto int not null,
descripcionTrabajo varchar(300) not null,
idRepuesto int not null,
cantidad int not null check(cantidad > 0),
precio decimal(10,2) not null check(precio> 0),
foreign key (idRepuesto) references dbo.Repuestos (idRepuesto),
foreign key (idPresupuesto) references dbo.Presupuestos (idPresupuesto),
constraint UQ_DetallePresupuesto
unique(idPresupuesto,idRepuesto)
)

create table dbo.ReparacionMecanicos
(
    idReparacion int not null,
    idMecanico int not null,

    primary key(idReparacion,idMecanico),

    foreign key(idReparacion)
        references dbo.Reparaciones(idReparacion),

    foreign key(idMecanico)
        references dbo.Mecanicos(idMecanico)
)

create table dbo.TareasReparacion
(
    idTarea int identity(1,1) primary key,
    idReparacion int not null,
    idMecanico int not null,

    descripcion varchar(300) not null,
    fechaInicio date,
    fechaFin date,

foreign key(idReparacion, idMecanico)
    references dbo.ReparacionMecanicos(idReparacion, idMecanico),
constraint CK_TareasReparacion_Fechas
    check (fechaFin is null or fechaInicio is null or fechaFin >= fechaInicio)
)
go
--TRIGGER 1
-- luego de cambiar  estado de reparaciones a completada, 
--te pone en fechaFin getdate()
-- recuerden q inserted es para q solo modifique lo q el usuario acaba de update
Create Trigger TR_ReparacionCompletaGuardaFechaFin 
ON dbo.Reparaciones
AFTER UPDATE 
AS BEGIN
IF UPDATE(estado)
BEGIN
UPDATE R
SET R.fechaFin = GETDATE()
FROM dbo.Reparaciones R
INNER JOIN inserted i On R.idReparacion = i.idReparacion 
WHERE i.estado = 'Completada';
end
end;
go
--TRIGGER 2
--Acumula importe de presupuesto.
CREATE TRIGGER TR_DetallePresupuesto_AcumularImporte
ON dbo.DetallePresupuesto
AFTER INSERT
AS
BEGIN
    UPDATE P
    SET P.importeTotal = ISNULL(P.importeTotal, 0) + (i.cantidad * i.precio)
    FROM dbo.Presupuestos P
    INNER JOIN inserted i ON P.idPresupuesto = i.idPresupuesto;
END;



-- TRIGGER 3: se dispara al aprobar el presupuesto!
-- Descuenta stock de todos los detalles ya cargados!
CREATE TRIGGER TR_DescontarStock_AlAprobar
ON dbo.Presupuestos
AFTER UPDATE
AS
BEGIN
    IF UPDATE(estado)
    BEGIN
        -- Verificar stock solo cuando el estado pasa a Aprobado
        IF EXISTS (
            SELECT 1
            FROM dbo.DetallePresupuesto dp
            INNER JOIN dbo.Repuestos r
                ON r.idRepuesto = dp.idRepuesto
            INNER JOIN inserted i
                ON i.idPresupuesto = dp.idPresupuesto
            INNER JOIN deleted d
                ON d.idPresupuesto = i.idPresupuesto
            WHERE d.estado <> 'Aprobado'
              AND i.estado = 'Aprobado'
              AND r.stock < dp.cantidad
        )
        BEGIN
            RAISERROR('Stock insuficiente para uno o más repuestos del presupuesto.',16,1)
            ROLLBACK TRANSACTION
            RETURN
        END

        -- Descontar stock
        UPDATE r
        SET r.stock = r.stock - dp.cantidad
        FROM dbo.Repuestos r
        INNER JOIN dbo.DetallePresupuesto dp
            ON dp.idRepuesto = r.idRepuesto
        INNER JOIN inserted i
            ON i.idPresupuesto = dp.idPresupuesto
        INNER JOIN deleted d
            ON d.idPresupuesto = i.idPresupuesto
        WHERE d.estado <> 'Aprobado'
          AND i.estado = 'Aprobado';
    END
END;
GO
 
-- TRIGGER 4: se dispara al insertar un detalle nuevo a un presupuesto que ya esta aprobado desde antes.
-- Solo descuenta si el presupuesto ya está 'Aprobado'!
go
create trigger TR_DescontarStock_AlAgregarDetalle
on dbo.DetallePresupuesto
after insert
as
begin
    -- verificar stock suficiente solo si el presupuesto está aprobado
    if exists (
        select 1
        from dbo.Repuestos r
        inner join inserted i on i.idRepuesto = r.idRepuesto
        inner join dbo.Presupuestos p on p.idPresupuesto = i.idPresupuesto
        where p.estado = 'Aprobado'
        and r.stock < i.cantidad
    )
    begin
        raiserror('Stock insuficiente para el repuesto ingresado.', 16, 1)
        rollback transaction
        return
    end
 
    -- descontar stock solo si el presupuesto está aprobado
    update dbo.Repuestos
    set stock = stock - i.cantidad
    from dbo.Repuestos r
    inner join inserted i on i.idRepuesto = r.idRepuesto
    inner join dbo.Presupuestos p on p.idPresupuesto = i.idPresupuesto
    where p.estado = 'Aprobado'
end
go


-- STORE PROCEDURE REGISTAR PRESUPUESTO
-- SI NO EXISTE EL CLIENTE LO CREA Y LE ASIGAN EL VEHICULO, ADEMAS CREA EL PRESUPUESTO
CREATE PROCEDURE SP_RegistrarPresupuesto
(
    @DNI VARCHAR(20),
    @Apellido VARCHAR(50),
    @Nombre VARCHAR(50),
    @Telefono VARCHAR(20),
    @Email VARCHAR(100),
    @Direccion VARCHAR(150),

    @Patente VARCHAR(10),
    @Marca VARCHAR(50),
    @Modelo VARCHAR(50),
    @Anio INT,
    @Color VARCHAR(30),

    @IdMecanico INT,
    @FechaEstimadaFin DATE = NULL,
    @Descripcion VARCHAR(400)
)
AS
BEGIN
SET NOCOUNT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @idCliente INT;
DECLARE @idVehiculo INT;

SELECT @idCliente = idCliente
FROM dbo.Clientes
WHERE DNI = @DNI;

IF @idCliente IS NULL
BEGIN
INSERT INTO dbo.Clientes
(DNI, Apellido, Nombre, Telefono, Email, Direccion)
VALUES
(@DNI, @Apellido, @Nombre, @Telefono, @Email, @Direccion);

SET @idCliente = SCOPE_IDENTITY();
END;

SELECT @idVehiculo = idVehiculo
FROM dbo.Vehiculos
WHERE Patente = @Patente;

 IF @idVehiculo IS NULL
BEGIN
INSERT INTO dbo.Vehiculos
(idCliente, Patente, Marca, Modelo, Anio, Color)
VALUES
 (@idCliente, @Patente, @Marca, @Modelo, @Anio, @Color);

SET @idVehiculo = SCOPE_IDENTITY();
END;

INSERT INTO dbo.Presupuestos
(idVehiculo, idMecanico, FechaEstimadaFin, descripcion)
VALUES
(@idVehiculo, @IdMecanico, @FechaEstimadaFin, @Descripcion);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
ROLLBACK TRANSACTION;
THROW;
END CATCH;
END;
GO

-- STORE PROCEDURE AGREGAR DETALLE PRESUPUESTO
-- AGREGA LOS DETALLES AL PRESUPUESTO DE LOS REPUESTOS CON SUS PRECIO Y CANTIDADES

CREATE PROCEDURE SP_AgregarDetallePresupuesto
(
@idPresupuesto INT,
@idRepuesto INT,
@descripcionTrabajo VARCHAR(300),
@cantidad INT,
@precio DECIMAL(10,2)
)
AS 
BEGIN

BEGIN TRY

IF NOT EXISTS
(
SELECT 1
FROM dbo.Presupuestos
WHERE idPresupuesto = @idPresupuesto
)
BEGIN
RAISERROR('El presupuesto no existe.',16,1);
RETURN;
END

IF NOT EXISTS
(
SELECT 1
FROM dbo.Repuestos
WHERE idRepuesto = @idRepuesto
)
BEGIN
RAISERROR('El repuesto no existe.',16,1);
RETURN;
END

INSERT INTO dbo.DetallePresupuesto
(idPresupuesto, descripcionTrabajo, idRepuesto, cantidad, precio)
VALUES (@idPresupuesto, @descripcionTrabajo, @idRepuesto, @cantidad, @precio);

END TRY
BEGIN CATCH
THROW;
END CATCH   

END
GO
