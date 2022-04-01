USE Chris

--Drop tablas 
IF OBJECT_ID('dbo.Fact_Day_Log') IS NOT NULL DROP TABLE dbo.Fact_Day_Log
IF OBJECT_ID('dbo.Fact_First_Log') IS NOT NULL DROP TABLE dbo.Fact_First_Log
IF OBJECT_ID('dbo.Dim_Event') IS NOT NULL DROP TABLE dbo.Dim_Event
IF OBJECT_ID('dbo.Dim_Session') IS NOT NULL DROP TABLE dbo.Dim_Session
IF OBJECT_ID('dbo.Dim_Segment') IS NOT NULL DROP TABLE dbo.Dim_Segment
IF OBJECT_ID('dbo.Dim_User') IS NOT NULL DROP TABLE dbo.Dim_User

---------------------------------------------------------------------------------------------------------------------------------------
--Crea Tabla de Usuario
CREATE TABLE dbo.Dim_User
(
	 [User_Id]				BIGINT IDENTITY (1,1) PRIMARY KEY
	,[User_First_Name]		VARCHAR(50)		-- Nombre del Usuario	
	,[User_Last_Name]		VARCHAR(50)		-- Apellido del Usuario
	,User_City				VARCHAR(50)		-- Ciudad del Usuario
	,User_Date_Create		DATETIME2		-- Fecha que se crea el usuario	
	,User_Date_Finish		DATETIME2		-- Ya que puede existir el mismo usuario con diferentes ciudades y no perder su historial.
);

--Insert de Tabla
INSERT INTO dbo.Dim_User VALUES ('Nombre_1','Apellido_1','Cordoba',GETDATE(),GETDATE()+1)
INSERT INTO dbo.Dim_User VALUES ('Nombre_1','Apellido_1','Cordoba',GETDATE()+2,NULL)
INSERT INTO dbo.Dim_User VALUES ('Nombre_2','Apellido_2','Buenos_Aires',GETDATE(),NULL)
INSERT INTO dbo.Dim_User VALUES ('Nombre_3','Apellido_3','Buenos_Aires',GETDATE()-5,GETDATE()-4)
---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------
--Crea Tabla de Segmento
CREATE TABLE dbo.Dim_Segment
(
	 Segment_Id				INT IDENTITY (1,1) PRIMARY KEY
	,Segment_Description	VARCHAR(100)	-- Descricion del Sgmento asociado el usuario
	,Segment_Active			BIT				-- Si el segmento se encuentra activo
);

--Insert de Tabla
INSERT INTO dbo.Dim_Segment VALUES('Segmento 1',1)
INSERT INTO dbo.Dim_Segment VALUES('Segmento 2',0)
INSERT INTO dbo.Dim_Segment VALUES('Segmento 3',1)
INSERT INTO dbo.Dim_Segment VALUES('Segmento 4',1)
---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------
--Crea Tabla de Sesion
CREATE TABLE dbo.Dim_Session
(
	 Session_Id				BIGINT IDENTITY (1,1) PRIMARY KEY
	,Session_Device_Browser VARCHAR(10)		-- Explorador desde donde se inicia session	
	,Session_Device_Os		VARCHAR(5)		-- Sistema operativo utilizado del dispositivo
	,Session_Device_Mobile  VARCHAR(10)		-- Dispositivo movil
	,Session_First			BIT				-- Detecta si es la primera inicio de session
	,Session_Date_Start		DATETIME2	 	-- Fecha inicio de session
	,Session_Date_Finish	DATETIME2		-- fecha fin de session
	,[User_Id]				BIGINT FOREIGN KEY REFERENCES dbo.Dim_User ([User_Id])
	,Segment_Id				INT	FOREIGN KEY REFERENCES dbo.Dim_Segment (Segment_Id)	
);

CREATE NONCLUSTERED INDEX [User_Id] ON dbo.Dim_Session ([User_Id])
CREATE NONCLUSTERED INDEX Segment_Id ON dbo.Dim_Session (Segment_Id)

--Insert de Tabla
INSERT INTO dbo.Dim_Session VALUES('Explorer','Mac','Apple',1,GETDATE(),GETDATE()+'19000101 00:08:00.000',2,4)  -- La sesion duró 8 minutos
INSERT INTO dbo.Dim_Session VALUES('Explorer','Mac','Apple',0,GETDATE(),GETDATE()+'19000101 00:04:00.000',2,4)  -- La sesion duro 4 minutos
INSERT INTO dbo.Dim_Session VALUES('Chrome','Win','Pc',1,GETDATE(),GETDATE()+'19000101 00:05:00.000',3,1)  -- La sesion duro 5 minutos
INSERT INTO dbo.Dim_Session VALUES('Explorer','Mac','Apple',0,GETDATE()+1,GETDATE()+1+'19000101 00:06:00.000',2,4)  -- La sesion duro 6 minutos
---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------
--Crea Tabla de Evento
CREATE TABLE dbo.Dim_Event
(
	 Event_Id				BIGINT IDENTITY (1,1) PRIMARY KEY
	,Event_Description		VARCHAR(50)		-- Descripcion del Evento
	,Event_Crash_Detection	VARCHAR(100)	-- Mensaje de Error
	,Event_Server_Time      DATETIME2		-- Dia y hora del Evento 
	,Session_Id				BIGINT FOREIGN KEY REFERENCES dbo.Dim_Session (Session_Id)	-- Id Session, entiendo que el evento se dispara al loguearse y puede dar su descripcion y/o Error.	
);

CREATE NONCLUSTERED INDEX Session_Id ON dbo.Dim_Session (Session_Id)

--Insert de Tabla
INSERT INTO dbo.Dim_Event VALUES('Consulta_Saldo','Ok',GETDATE(),1)
INSERT INTO dbo.Dim_Event VALUES('Consulta_Saldo','Ok',GETDATE(),2)
INSERT INTO dbo.Dim_Event VALUES('Solicita_Prestamo','Error_Conexion',GETDATE(),3)
INSERT INTO dbo.Dim_Event VALUES('Consulta_CajaAhorro','Ok',GETDATE()+1,4)

---------------------------------------------------------------------------------------------------------------------------------------
-- Select de las tablas y armar las Fact
SELECT 

	 ROW_NUMBER() OVER(Order by ss.Session_Id)				AS Id--Recomiendo siempre colocar identity a la tabla, lo simulo con un Row_number
	,ev.Event_Id											AS Event_Id
	,ss.Session_Id											AS Session_Id
	,us.[User_Id]											AS [User_Id]		
	,us.User_First_Name + ', ' + us.User_Last_Name			AS [User_Name] --Para optimizar la tabla se puede quitar este campo y dejar unicamente el UserId
	,ev.Event_Description									AS Event_Description
	,ev.Event_Crash_Detection								AS Event_Crash_Detection
	
INTO dbo.Fact_First_Log --Realizo esto ya que la tabla no esta creada, pero al tener la tabla creada en Base no se va a realizar un drop sino una ingesta incremental de aquellos id faltantes.
FROM	   dbo.Dim_Event   ev
INNER JOIN dbo.Dim_Session ss ON (ev.Session_Id = ss.Session_Id) 
INNER JOIN dbo.Dim_User    us ON (ss.[User_Id] = us.[User_Id])	 -- Doy por entendido que las Dim son excluyentes entre si. No aplico LEFT por perfomance en alto volumen de registros.

WHERE ss.Session_First = 1 
  AND us.User_Date_Finish IS NULL --Clientes activos


SELECT 

	 ROW_NUMBER() OVER(Order by ss.Session_Id)					 AS Id--Recomiendo siempre colocar identity a la tabla, lo simulo con un Row_number
	,CAST(CAST(ss.Session_Date_Start AS DATE) AS DATETIME)		 AS Day_Date
	,ev.Event_Id												 AS Event_Id
	,ss.Session_Id												 AS Session_Id
	,us.[User_Id]												 AS [User_Id]		
	,ev.Event_Description										 AS Event_Description
	,ev.Event_Crash_Detection									 AS Event_Crash_Detection
	,se.Segment_Description										 AS Segment_Description		
	,ss.Session_Device_Mobile									 AS Session_Device_Mobile
	,DATEDIFF(ss, ss.Session_Date_Start, ss.Session_Date_Finish) AS Time_Spent

INTO dbo.Fact_Day_Log --Realizo esto ya que la tabla no esta creada, pero al tener la tabla creada en Base no se va a realizar un drop sino una ingesta incremental de aquellos id faltantes.
FROM	   dbo.Dim_Event   ev
INNER JOIN dbo.Dim_Session ss ON (ev.Session_Id = ss.Session_Id) 
INNER JOIN dbo.Dim_User    us ON (ss.[User_Id] = us.[User_Id])	 -- Doy por entendido que las Dim son excluyentes entre si. No aplico LEFT por perfomance en alto volumen de registros.
INNER JOIN dbo.Dim_Segment se ON (ss.Segment_Id = se.Segment_Id)

WHERE us.User_Date_Finish IS NULL --Clientes activos
  AND se.Segment_Active = 1       --Segmentos activos
---------------------------------------------------------------------------------------------------------------------------------------
--Query de Retencion (Punto3) 
--Traemos en tabla temporal para procesar mas rapido los registros (si bien son pocos en esta demo a grandes escalas es recomendable)
IF OBJECT_ID('tempdb..#Sesiones_mas5minutos') IS NOT NULL DROP TABLE #Sesiones_mas5minutos --Recomiendo declarar la tabla con todos sus campos para que sea más transparente el código

DECLARE @Session_Abierta AS INT SET @Session_Abierta = 60 * 5 

--Traigo las sesiones mas de cinco minutos
SELECT *
INTO #Sesiones_mas5minutos
FROM dbo.Fact_Day_Log 

WHERE Time_Spent >= @Session_Abierta
ORDER BY [User_Id], Session_Id

--Consulto por la fecha + 1 si existen.
SELECT 'Punto3' Ejercicio, COUNT(DISTINCT sa.[User_Id]) Q_Usuario
FROM #Sesiones_mas5minutos       sa
INNER JOIN #Sesiones_mas5minutos sb ON (
										    sa.User_Id = sb.User_Id 
										AND sa.Event_Id <> sb.Event_Id
										AND sa.Day_Date = sb.Day_Date + 1
									   )
---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------
--Ejercicio 3
DECLARE @Ultima_Fecha AS DATETIME SET @Ultima_Fecha = (SELECT MAX(Day_Date) FROM dbo.Fact_Day_Log) --En billones de registros termina siendo performante y no realizar subconsultas.

SELECT TOP 10 'Ejercicio 3' Ejercicio, [User_Id], COUNT(1) Q_Usuario

FROM dbo.Fact_Day_Log
WHERE DATEPART(MM,Day_Date) = DATEPART(MM,@Ultima_Fecha)

GROUP BY [User_Id]
ORDER BY 2 DESC 

--SELECT * FROM dbo.Dim_User
--SELECT * FROM dbo.Dim_Segment
--SELECT * FROM dbo.Dim_Session
--SELECT * FROM dbo.Dim_Event
--SELECT * FROM dbo.Fact_First_Log
--SELECT * FROM #Sesiones_mas5minutos
--SELECT * FROM dbo.Fact_Day_Log