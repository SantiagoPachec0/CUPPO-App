USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   12. AUTENTICACIÓN (Fase 2)

   - Contraseñas con BCrypt calculado en la API: la base ya no recibe la
     contraseña en texto plano. Los usuarios con el hash anterior (SHA-512 en
     SQL) se migran solos en su siguiente inicio de sesión.
   - Refresh tokens con rotación: solo se guarda el hash SHA-256.
   - Códigos de recuperación de contraseña: solo se guarda el hash, vencen a
     los 15 minutos y permiten 5 intentos.
   ============================================================================ */

-- ===== Security.Users: columna BCrypt y hash anterior opcional
IF COL_LENGTH('Security.Users', 'PasswordBcrypt') IS NULL
    ALTER TABLE [Security].[Users] ADD [PasswordBcrypt] VARCHAR(100) NULL;
GO
ALTER TABLE [Security].[Users] ALTER COLUMN [PasswordHash] VARBINARY(256) NULL;
ALTER TABLE [Security].[Users] ALTER COLUMN [PasswordSalt] VARBINARY(32) NULL;
GO

-- ===== Security.RefreshTokens
IF OBJECT_ID('Security.RefreshTokens') IS NULL
BEGIN
    CREATE TABLE [Security].[RefreshTokens](
        [RefreshTokenID]     INT IDENTITY(1,1) NOT NULL,
        [UserID]             INT           NOT NULL,
        [TokenHash]          BINARY(32)    NOT NULL,
        [ExpiresAt]          DATETIME2(0)  NOT NULL,
        [DeviceInfo]         VARCHAR(200)  NULL,
        [CreationDate]       DATETIME2(0)  NOT NULL CONSTRAINT [DF_RefreshTokens_CreationDate] DEFAULT (SYSUTCDATETIME()),
        [RevokedAt]          DATETIME2(0)  NULL,
        [ReplacedByTokenID]  INT           NULL,
        CONSTRAINT [PK_RefreshTokens] PRIMARY KEY CLUSTERED ([RefreshTokenID]),
        CONSTRAINT [UQ_RefreshTokens_TokenHash] UNIQUE ([TokenHash]),
        CONSTRAINT [FK_RefreshTokens_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID])
    );
    CREATE NONCLUSTERED INDEX [IX_RefreshTokens_User_Active] ON [Security].[RefreshTokens]([UserID]) WHERE [RevokedAt] IS NULL;
END
GO

-- ===== Security.PasswordResetCodes
IF OBJECT_ID('Security.PasswordResetCodes') IS NULL
BEGIN
    CREATE TABLE [Security].[PasswordResetCodes](
        [PasswordResetCodeID] INT IDENTITY(1,1) NOT NULL,
        [UserID]              INT           NOT NULL,
        [CodeHash]            BINARY(32)    NOT NULL,
        [ExpiresAt]           DATETIME2(0)  NOT NULL,
        [Attempts]            INT           NOT NULL CONSTRAINT [DF_PasswordResetCodes_Attempts] DEFAULT (0),
        [UsedAt]              DATETIME2(0)  NULL,
        [CreationDate]        DATETIME2(0)  NOT NULL CONSTRAINT [DF_PasswordResetCodes_CreationDate] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_PasswordResetCodes] PRIMARY KEY CLUSTERED ([PasswordResetCodeID]),
        CONSTRAINT [FK_PasswordResetCodes_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID])
    );
    CREATE NONCLUSTERED INDEX [IX_PasswordResetCodes_User] ON [Security].[PasswordResetCodes]([UserID], [CreationDate] DESC);
END
GO

-- ===== Security.InsertUser: acepta el hash BCrypt calculado en la API
-- @Password (texto plano) se mantiene solo para scripts de desarrollo.
CREATE OR ALTER PROCEDURE [Security].[InsertUser]
    @UserLogin VARCHAR(50),
    @Name VARCHAR(50),
    @Mail VARCHAR(50),
    @PasswordBcrypt VARCHAR(100) = NULL,
    @Password VARCHAR(100) = NULL,
    @Blocked BIT = 0,
    @FailedLoginAttempts INT = 0,
    @StatusID INT = 1,
    @CreationUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF @PasswordBcrypt IS NULL AND @Password IS NULL
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'La contraseña es obligatoria.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserLogin] = @UserLogin)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El nombre de usuario (UserLogin) ya está registrado.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE [Mail] = @Mail)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El correo electrónico ya está registrado.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @Salt VARBINARY(32) = NULL, @PasswordHash VARBINARY(256) = NULL;
            IF @PasswordBcrypt IS NULL
            BEGIN
                SET @Salt = CRYPT_GEN_RANDOM(32);
                SET @PasswordHash = [Security].[encryptHash](@Password, @Salt);
            END

            INSERT INTO [Security].[Users] (
                [UserLogin], [Name], [Mail], [PasswordHash], [PasswordSalt], [PasswordBcrypt],
                [Blocked], [FailedLoginAttempts], [StatusID], [CreationUserID], [CreationDate]
            )
            VALUES (
                @UserLogin, @Name, @Mail, @PasswordHash, @Salt, @PasswordBcrypt,
                ISNULL(@Blocked, 0), ISNULL(@FailedLoginAttempts, 0), ISNULL(@StatusID, 1), @CreationUserID, GETDATE()
            );

            DECLARE @NewUserID INT = SCOPE_IDENTITY();

            INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID], [CreationDate])
            SELECT @NewUserID, [RoleID], ISNULL(@CreationUserID, @NewUserID), GETDATE()
            FROM [Security].[Roles]
            WHERE [Code] = 'CLIENT';

            SET @CodeResult = @NewUserID;
            SET @MessageResult = 'Usuario creado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'UserLogin: ', ISNULL(@UserLogin, 'NULL'), ' | ',
            'Name: ', ISNULL(@Name, 'NULL'), ' | ',
            'Mail: ', ISNULL(@Mail, 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[InsertUser]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.GetUserForLogin
-- Datos mínimos para validar el inicio de sesión en la API.
CREATE OR ALTER PROCEDURE [Security].[GetUserForLogin]
    @Identifier VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        [UserID],
        [PasswordBcrypt],
        CAST(CASE WHEN [PasswordHash] IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS [HasLegacyPassword],
        [Blocked],
        [StatusID]
    FROM [Security].[Users]
    WHERE [UserLogin] = @Identifier OR [Mail] = @Identifier;
END;
GO

-- ===== Security.RegisterLoginAttempt
-- Éxito: reinicia el contador. Fallo: lo suma y bloquea al llegar a 5.
CREATE OR ALTER PROCEDURE [Security].[RegisterLoginAttempt]
    @UserID INT,
    @Success BIT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Success = 1
    BEGIN
        UPDATE [Security].[Users]
        SET [FailedLoginAttempts] = 0, [UpdateDate] = GETDATE()
        WHERE [UserID] = @UserID;

        SET @CodeResult = @UserID;
        SET @MessageResult = 'Autenticación exitosa.';
        RETURN;
    END

    DECLARE @Attempts INT;

    UPDATE [Security].[Users]
    SET @Attempts = [FailedLoginAttempts] = [FailedLoginAttempts] + 1,
        [Blocked] = CASE WHEN [FailedLoginAttempts] + 1 >= 5 THEN 1 ELSE [Blocked] END,
        [UpdateDate] = GETDATE()
    WHERE [UserID] = @UserID;

    IF @Attempts >= 5
    BEGIN
        SET @CodeResult = -3;
        SET @MessageResult = 'Ha superado el límite de intentos fallidos. La cuenta ha sido bloqueada; recupere su contraseña para desbloquearla.';
    END
    ELSE
    BEGIN
        SET @CodeResult = -1;
        SET @MessageResult = 'Credenciales inválidas.';
    END
END;
GO

-- ===== Security.SetUserPassword
-- Guarda el hash BCrypt y borra el hash anterior.
-- @RevokeSessions = 1 cierra todas las sesiones (refresh tokens) del usuario.
-- @Unblock = 1 desbloquea la cuenta (recuperación de contraseña por correo).
CREATE OR ALTER PROCEDURE [Security].[SetUserPassword]
    @UserID INT,
    @PasswordBcrypt VARCHAR(100),
    @RevokeSessions BIT = 0,
    @Unblock BIT = 0,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            UPDATE [Security].[Users]
            SET [PasswordBcrypt] = @PasswordBcrypt,
                [PasswordHash] = NULL,
                [PasswordSalt] = NULL,
                [Blocked] = CASE WHEN @Unblock = 1 THEN 0 ELSE [Blocked] END,
                [FailedLoginAttempts] = CASE WHEN @Unblock = 1 THEN 0 ELSE [FailedLoginAttempts] END,
                [UpdateUserID] = @UserID,
                [UpdateDate] = GETDATE()
            WHERE [UserID] = @UserID;

            IF @@ROWCOUNT = 0
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El usuario no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @RevokeSessions = 1
                UPDATE [Security].[RefreshTokens]
                SET [RevokedAt] = SYSUTCDATETIME()
                WHERE [UserID] = @UserID AND [RevokedAt] IS NULL;

            SET @CodeResult = @UserID;
            SET @MessageResult = 'Contraseña actualizada.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT('UserID: ', @UserID);
        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID, @AppModule = 'Security', @MethodName = NULL,
            @ProcedureName = '[Security].[SetUserPassword]', @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult, @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.GetUserRoles
-- Roles efectivos para el token. COMPLEX_ADMIN solo si el dueño está verificado.
CREATE OR ALTER PROCEDURE [Security].[GetUserRoles]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT R.[Code]
    FROM [Security].[UserRoles] UR
    INNER JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
    INNER JOIN [Security].[Users] U ON U.[UserID] = UR.[UserID]
    WHERE UR.[UserID] = @UserID
      AND R.[StatusID] = 1
      AND U.[Blocked] = 0
      AND U.[StatusID] = 1
      AND (R.[Code] <> 'COMPLEX_ADMIN'
           OR EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] OP
                      WHERE OP.[UserID] = UR.[UserID] AND OP.[VerificationStatusID] = 2))
    ORDER BY R.[RoleID];
END;
GO

-- ===== Security.InsertRefreshToken
CREATE OR ALTER PROCEDURE [Security].[InsertRefreshToken]
    @UserID INT,
    @TokenHash BINARY(32),
    @ExpiresAt DATETIME2(0),
    @DeviceInfo VARCHAR(200) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Security].[RefreshTokens] ([UserID], [TokenHash], [ExpiresAt], [DeviceInfo])
    VALUES (@UserID, @TokenHash, @ExpiresAt, @DeviceInfo);

    SET @CodeResult = SCOPE_IDENTITY();
    SET @MessageResult = 'Sesión creada.';
END;
GO

-- ===== Security.RotateRefreshToken
-- Cambia un refresh token válido por uno nuevo. Si alguien reusa un token ya
-- rotado (posible robo), se cierran todas las sesiones del usuario.
-- CodeResult = UserID si tiene éxito.
CREATE OR ALTER PROCEDURE [Security].[RotateRefreshToken]
    @TokenHash BINARY(32),
    @NewTokenHash BINARY(32),
    @NewExpiresAt DATETIME2(0),
    @DeviceInfo VARCHAR(200) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @TokenID INT, @UserID INT, @ExpiresAt DATETIME2(0), @RevokedAt DATETIME2(0);

            SELECT @TokenID = [RefreshTokenID], @UserID = [UserID], @ExpiresAt = [ExpiresAt], @RevokedAt = [RevokedAt]
            FROM [Security].[RefreshTokens] WITH (UPDLOCK)
            WHERE [TokenHash] = @TokenHash;

            IF @TokenID IS NULL
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'Sesión inválida. Inicia sesión de nuevo.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @RevokedAt IS NOT NULL
            BEGIN
                -- Reuso de un token ya usado: se cierran todas las sesiones
                UPDATE [Security].[RefreshTokens]
                SET [RevokedAt] = SYSUTCDATETIME()
                WHERE [UserID] = @UserID AND [RevokedAt] IS NULL;

                SET @CodeResult = -3;
                SET @MessageResult = 'Sesión inválida. Inicia sesión de nuevo.';
                COMMIT TRANSACTION;
                RETURN;
            END

            IF @ExpiresAt <= SYSUTCDATETIME()
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'La sesión expiró. Inicia sesión de nuevo.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID AND [Blocked] = 0 AND [StatusID] = 1)
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = 'La cuenta de usuario se encuentra bloqueada o inactiva.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[RefreshTokens] ([UserID], [TokenHash], [ExpiresAt], [DeviceInfo])
            VALUES (@UserID, @NewTokenHash, @NewExpiresAt, @DeviceInfo);

            UPDATE [Security].[RefreshTokens]
            SET [RevokedAt] = SYSUTCDATETIME(),
                [ReplacedByTokenID] = SCOPE_IDENTITY()
            WHERE [RefreshTokenID] = @TokenID;

            SET @CodeResult = @UserID;
            SET @MessageResult = 'Sesión renovada.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID, @AppModule = 'Security', @MethodName = NULL,
            @ProcedureName = '[Security].[RotateRefreshToken]', @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult, @InputData = NULL, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.RevokeRefreshToken (cerrar sesión en un dispositivo)
CREATE OR ALTER PROCEDURE [Security].[RevokeRefreshToken]
    @TokenHash BINARY(32),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Security].[RefreshTokens]
    SET [RevokedAt] = SYSUTCDATETIME()
    WHERE [TokenHash] = @TokenHash AND [RevokedAt] IS NULL;

    SET @CodeResult = 1;
    SET @MessageResult = 'Sesión cerrada.';
END;
GO

-- ===== Security.CreatePasswordResetCode
-- CodeResult = UserID; 0 si el correo no existe (la API responde igual para no
-- revelar qué correos están registrados); -2 si pidió demasiados códigos.
CREATE OR ALTER PROCEDURE [Security].[CreatePasswordResetCode]
    @Mail VARCHAR(50),
    @CodeHash BINARY(32),
    @ExpiresAt DATETIME2(0),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT = (SELECT [UserID] FROM [Security].[Users] WHERE [Mail] = @Mail AND [StatusID] = 1);

    IF @UserID IS NULL
    BEGIN
        SET @CodeResult = 0;
        SET @MessageResult = 'Correo no registrado.';
        RETURN;
    END

    IF (SELECT COUNT(*) FROM [Security].[PasswordResetCodes]
        WHERE [UserID] = @UserID AND [CreationDate] > DATEADD(HOUR, -1, SYSUTCDATETIME())) >= 3
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Demasiadas solicitudes. Intenta de nuevo en una hora.';
        RETURN;
    END

    BEGIN TRANSACTION;
        -- Solo el código más reciente sirve
        UPDATE [Security].[PasswordResetCodes]
        SET [UsedAt] = SYSUTCDATETIME()
        WHERE [UserID] = @UserID AND [UsedAt] IS NULL;

        INSERT INTO [Security].[PasswordResetCodes] ([UserID], [CodeHash], [ExpiresAt])
        VALUES (@UserID, @CodeHash, @ExpiresAt);
    COMMIT TRANSACTION;

    SET @CodeResult = @UserID;
    SET @MessageResult = 'Código creado.';
END;
GO

-- ===== Security.ConsumePasswordResetCode
-- Valida el código; si es correcto lo marca como usado. CodeResult = UserID.
CREATE OR ALTER PROCEDURE [Security].[ConsumePasswordResetCode]
    @Mail VARCHAR(50),
    @CodeHash BINARY(32),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

        DECLARE @CodeID INT, @UserID INT, @StoredHash BINARY(32), @Attempts INT;

        SELECT TOP (1) @CodeID = PRC.[PasswordResetCodeID], @UserID = PRC.[UserID],
                       @StoredHash = PRC.[CodeHash], @Attempts = PRC.[Attempts]
        FROM [Security].[PasswordResetCodes] PRC WITH (UPDLOCK)
        INNER JOIN [Security].[Users] U ON U.[UserID] = PRC.[UserID]
        WHERE U.[Mail] = @Mail
          AND PRC.[UsedAt] IS NULL
          AND PRC.[ExpiresAt] > SYSUTCDATETIME()
        ORDER BY PRC.[CreationDate] DESC;

        IF @CodeID IS NULL
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'El código es inválido o ya venció. Solicita uno nuevo.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @StoredHash <> @CodeHash
        BEGIN
            UPDATE [Security].[PasswordResetCodes]
            SET [Attempts] = [Attempts] + 1,
                [UsedAt] = CASE WHEN [Attempts] + 1 >= 5 THEN SYSUTCDATETIME() ELSE NULL END
            WHERE [PasswordResetCodeID] = @CodeID;

            SET @CodeResult = -2;
            SET @MessageResult = 'El código es inválido o ya venció. Solicita uno nuevo.';
            COMMIT TRANSACTION;
            RETURN;
        END

        UPDATE [Security].[PasswordResetCodes]
        SET [UsedAt] = SYSUTCDATETIME()
        WHERE [PasswordResetCodeID] = @CodeID;

    COMMIT TRANSACTION;

    SET @CodeResult = @UserID;
    SET @MessageResult = 'Código válido.';
END;
GO
