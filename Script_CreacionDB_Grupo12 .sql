create database TallerMecanico
go

use TallerMecanico
go

-- ============================================================
-- TABLA: Clientes

create table dbo.Clientes
(
idCliente int identity(1,1) primary key,
DNI varchar(20) not null unique,
Apellido varchar(50) not null,
Nombre varchar(50) not null,
Telefono varchar(20) not null,
Email varchar(100) not null,
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
nombreRepuesto varchar(50) not null,
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
Color varchar(30) not null,
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
fechaEstimadaFin date null,
descripcion varchar(400) not null,
importeTotal decimal(10,2),
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
precio decimal(10,2) not null,
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
