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



--TRIGGER 3: TR_DescontarStock
--Al insertar un detalle de presupuesto, descuenta automáticamente la cantidad del stock del repuesto.
--Si el stock es insuficiente, cancela la operación.
go
create trigger TR_DescontarStock
on dbo.DetallePresupuesto
after insert
as
begin
    -- verificar que haya stock suficiente
    if exists (
        select 1
        from dbo.Repuestos r
        inner join inserted i on i.idRepuesto = r.idRepuesto
        where r.stock < i.cantidad
    )
    begin
        raiserror('Stock insuficiente para uno o más repuestos del detalle.', 16, 1)
        rollback transaction
        return
    end
 
    -- descontar el stock
    update dbo.Repuestos
    set stock = stock - i.cantidad
    from dbo.Repuestos r
    inner join inserted i on i.idRepuesto = r.idRepuesto
end
go
 
-- TRIGGER 4: TR_FinalizarPresupuesto
-- Cuando una reparación pasa a estado 'Completada', actualiza automáticamente el estado del presupuesto
-- asociado a 'Finalizado'.
go
create trigger TR_FinalizarPresupuesto
on dbo.Reparaciones
after update
as
begin
    if update(estado)
    begin
        update dbo.Presupuestos
        set estado = 'Finalizado'
        from dbo.Presupuestos p
        inner join inserted i on i.idPresupuesto = p.idPresupuesto
        where i.estado = 'Completada'
    end
end
go
