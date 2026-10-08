USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   10. STORED PROCEDURES: SEGURIDAD Y VERIFICACIÓN DE DUEÑOS

   - InsertUser ahora asigna el rol CLIENT a todo usuario nuevo.
   - El rol COMPLEX_ADMIN (Panel de dueño) solo da permisos si el perfil de
     dueño está APROBADO. Así, aunque alguien asigne el rol a mano, el módulo
     no aparece hasta que CUPPO verifique al dueño.
   ============================================================================ */

-- ===== Security.InsertUser (agrega asignación del rol CLIENT)
CREATE OR ALTER PROCEDURE [Security].[InsertUser]
    @UserLogin VARCHAR(50),
    @Name VARCHAR(50),
    @Mail VARCHAR(50),
    @Password VARCHAR(100),
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

            DECLARE @Salt VARBINARY(32) = CRYPT_GEN_RANDOM(32);
            DECLARE @PasswordHash VARBINARY(256) = [Security].[encryptHash](@Password, @Salt);

            INSERT INTO [Security].[Users] (
                [UserLogin], [Name], [Mail], [PasswordHash], [PasswordSalt],
                [Blocked], [FailedLoginAttempts], [StatusID], [CreationUserID], [CreationDate]
            )
            VALUES (
                @UserLogin, @Name, @Mail, @PasswordHash, @Salt,
                ISNULL(@Blocked, 0), ISNULL(@FailedLoginAttempts, 0), ISNULL(@StatusID, 1), @CreationUserID, GETDATE()
            );

            DECLARE @NewUserID INT = SCOPE_IDENTITY();

            -- Todo usuario nuevo es jugador (rol CLIENT)
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
            'Mail: ', ISNULL(@Mail, 'NULL'), ' | ',
            'StatusID: ', ISNULL(CAST(@StatusID AS VARCHAR), 'NULL')
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

-- ===== Security.GetUserPermissions (COMPLEX_ADMIN solo cuenta si el dueño está verificado)
CREATE OR ALTER PROCEDURE [Security].[GetUserPermissions]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        M.[ModuleID],
        M.[Code] AS [ModuleCode],
        M.[Name] AS [ModuleName],
        M.[ParentModuleID],
        M.[Icon],
        M.[Route],
        M.[DisplayOrder],
        A.[ActionID],
        A.[Code] AS [ActionCode],
        A.[Name] AS [ActionName]
    FROM [Security].[UserRoles] UR
    INNER JOIN [Security].[Users] U ON UR.[UserID] = U.[UserID]
    INNER JOIN [Security].[Roles] R ON UR.[RoleID] = R.[RoleID]
    INNER JOIN [Security].[RolePermissions] RP ON R.[RoleID] = RP.[RoleID]
    INNER JOIN [Security].[ModuleActions] MA ON RP.[ModuleActionID] = MA.[ModuleActionID]
    INNER JOIN [Security].[Modules] M ON MA.[ModuleID] = M.[ModuleID]
    INNER JOIN [Security].[Actions] A ON MA.[ActionID] = A.[ActionID]
    WHERE UR.[UserID] = @UserID
      AND U.[Blocked] = 0
      AND U.[StatusID] = 1
      AND R.[StatusID] = 1
      AND M.[StatusID] = 1
      AND A.[StatusID] = 1
      AND MA.[StatusID] = 1
      AND (R.[Code] <> 'COMPLEX_ADMIN'
           OR EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] OP
                      WHERE OP.[UserID] = UR.[UserID] AND OP.[VerificationStatusID] = 2))
    ORDER BY M.[DisplayOrder], M.[ModuleID];
END;
GO

-- ===== Security.ValidateUserPermission (misma regla de dueño verificado)
CREATE OR ALTER PROCEDURE [Security].[ValidateUserPermission]
    @UserID INT,
    @ModuleCode VARCHAR(20),
    @ActionCode VARCHAR(20),
    @HasPermission BIT OUTPUT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID AND [Blocked] = 0 AND [StatusID] = 1)
        BEGIN
            SET @HasPermission = 0;
            SET @CodeResult = -1;
            SET @MessageResult = 'Usuario inactivo o bloqueado.';
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM [Security].[UserRoles] UR
            INNER JOIN [Security].[Roles] R ON UR.[RoleID] = R.[RoleID]
            INNER JOIN [Security].[RolePermissions] RP ON R.[RoleID] = RP.[RoleID]
            INNER JOIN [Security].[ModuleActions] MA ON RP.[ModuleActionID] = MA.[ModuleActionID]
            INNER JOIN [Security].[Modules] M ON MA.[ModuleID] = M.[ModuleID]
            INNER JOIN [Security].[Actions] A ON MA.[ActionID] = A.[ActionID]
            WHERE UR.[UserID] = @UserID
              AND R.[StatusID] = 1
              AND M.[Code] = @ModuleCode AND M.[StatusID] = 1
              AND A.[Code] = @ActionCode AND A.[StatusID] = 1
              AND MA.[StatusID] = 1
              AND (R.[Code] <> 'COMPLEX_ADMIN'
                   OR EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] OP
                              WHERE OP.[UserID] = UR.[UserID] AND OP.[VerificationStatusID] = 2))
        )
        BEGIN
            SET @HasPermission = 1;
            SET @CodeResult = 1;
            SET @MessageResult = 'Acceso concedido.';
        END
        ELSE
        BEGIN
            SET @HasPermission = 0;
            SET @CodeResult = 0;
            SET @MessageResult = 'Acceso denegado. Permisos insuficientes.';
        END
    END TRY
    BEGIN CATCH
        SET @HasPermission = 0;
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputDataParam VARCHAR(250) = CONCAT('Module:', @ModuleCode, ' | Action:', @ActionCode);

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[ValidateUserPermission]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputDataParam,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.RequestOwnerVerification
-- El jugador solicita ser dueño. Queda PENDIENTE hasta que CUPPO lo revise.
-- Si fue rechazado puede volver a solicitar; si está pendiente puede corregir datos.
CREATE OR ALTER PROCEDURE [Venue].[RequestOwnerVerification]
    @UserID INT,
    @DocumentType CHAR(1),
    @DocumentNumber VARCHAR(20),
    @LegalName NVARCHAR(150),
    @Phone VARCHAR(20),
    @DocumentUrl VARCHAR(500) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID AND [Blocked] = 0 AND [StatusID] = 1)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El usuario no existe o se encuentra inactivo.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @DocumentType NOT IN ('V', 'E', 'J', 'G', 'P')
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'Tipo de documento inválido. Use V, E, J, G o P.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles]
                       WHERE [DocumentType] = @DocumentType AND [DocumentNumber] = @DocumentNumber AND [UserID] <> @UserID)
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'El documento ya está registrado por otro usuario.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @CurrentStatusID INT;
            SELECT @CurrentStatusID = [VerificationStatusID]
            FROM [Venue].[OwnerProfiles] WITH (UPDLOCK)
            WHERE [UserID] = @UserID;

            IF @CurrentStatusID = 2
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = 'Tu cuenta de dueño ya está verificada.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @CurrentStatusID = 4
            BEGIN
                SET @CodeResult = -6;
                SET @MessageResult = 'Tu cuenta de dueño está suspendida. Comunícate con soporte de CUPPO.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @CurrentStatusID IS NULL
            BEGIN
                INSERT INTO [Venue].[OwnerProfiles] ([UserID], [DocumentType], [DocumentNumber], [LegalName], [Phone], [DocumentUrl], [VerificationStatusID])
                VALUES (@UserID, @DocumentType, @DocumentNumber, @LegalName, @Phone, @DocumentUrl, 1);
            END
            ELSE
            BEGIN
                -- Pendiente (corrige datos) o rechazado (nueva solicitud)
                UPDATE [Venue].[OwnerProfiles]
                SET [DocumentType] = @DocumentType,
                    [DocumentNumber] = @DocumentNumber,
                    [LegalName] = @LegalName,
                    [Phone] = @Phone,
                    [DocumentUrl] = ISNULL(@DocumentUrl, [DocumentUrl]),
                    [VerificationStatusID] = 1,
                    [UpdateDate] = SYSUTCDATETIME()
                WHERE [UserID] = @UserID;
            END

            SET @CodeResult = @UserID;
            SET @MessageResult = 'Solicitud enviada. CUPPO revisará tus datos y te notificará.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'UserID: ', ISNULL(CAST(@UserID AS VARCHAR(20)), 'NULL'), ' | ',
            'Document: ', ISNULL(@DocumentType, '?'), '-', ISNULL(@DocumentNumber, 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID,
            @AppModule = 'Venue',
            @MethodName = NULL,
            @ProcedureName = '[Venue].[RequestOwnerVerification]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.ReviewOwnerVerification
-- Un SUPERADMIN aprueba (2), rechaza (3) o suspende (4) a un dueño.
-- Aprobar asigna el rol COMPLEX_ADMIN; rechazar o suspender lo quita.
CREATE OR ALTER PROCEDURE [Venue].[ReviewOwnerVerification]
    @UserID INT,
    @VerificationStatusID INT,
    @ReviewNotes NVARCHAR(500) = NULL,
    @ReviewerUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (
                SELECT 1
                FROM [Security].[UserRoles] UR
                INNER JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
                WHERE UR.[UserID] = @ReviewerUserID AND R.[Code] = 'SUPERADMIN' AND R.[StatusID] = 1
            )
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'Solo un administrador de CUPPO puede verificar dueños.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @CurrentStatusID INT;
            SELECT @CurrentStatusID = [VerificationStatusID]
            FROM [Venue].[OwnerProfiles] WITH (UPDLOCK)
            WHERE [UserID] = @UserID;

            IF @CurrentStatusID IS NULL
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El usuario no tiene una solicitud de dueño.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Transiciones válidas: 1→2, 1→3, 3→2, 2→4, 4→2
            IF NOT (   (@VerificationStatusID = 2 AND @CurrentStatusID IN (1, 3, 4))
                    OR (@VerificationStatusID = 3 AND @CurrentStatusID = 1)
                    OR (@VerificationStatusID = 4 AND @CurrentStatusID = 2))
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'Cambio de estado de verificación no permitido.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @VerificationStatusID IN (3, 4) AND NULLIF(LTRIM(RTRIM(@ReviewNotes)), N'') IS NULL
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = 'Debe indicar el motivo del rechazo o la suspensión.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Venue].[OwnerProfiles]
            SET [VerificationStatusID] = @VerificationStatusID,
                [ReviewedByUserID] = @ReviewerUserID,
                [ReviewedDate] = SYSUTCDATETIME(),
                [ReviewNotes] = @ReviewNotes,
                [UpdateDate] = SYSUTCDATETIME()
            WHERE [UserID] = @UserID;

            DECLARE @OwnerRoleID INT = (SELECT [RoleID] FROM [Security].[Roles] WHERE [Code] = 'COMPLEX_ADMIN');

            IF @VerificationStatusID = 2
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM [Security].[UserRoles] WHERE [UserID] = @UserID AND [RoleID] = @OwnerRoleID)
                    INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID], [CreationDate])
                    VALUES (@UserID, @OwnerRoleID, @ReviewerUserID, GETDATE());

                SET @MessageResult = 'Dueño verificado. Ya puede ver el Panel de dueño.';
            END
            ELSE
            BEGIN
                DELETE FROM [Security].[UserRoles] WHERE [UserID] = @UserID AND [RoleID] = @OwnerRoleID;

                SET @MessageResult = CASE @VerificationStatusID
                                         WHEN 3 THEN 'Solicitud de dueño rechazada.'
                                         ELSE 'Dueño suspendido. Ya no tiene acceso al Panel de dueño.'
                                     END;
            END

            SET @CodeResult = @UserID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'UserID: ', ISNULL(CAST(@UserID AS VARCHAR(20)), 'NULL'), ' | ',
            'VerificationStatusID: ', ISNULL(CAST(@VerificationStatusID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @ReviewerUserID,
            @AppModule = 'Venue',
            @MethodName = NULL,
            @ProcedureName = '[Venue].[ReviewOwnerVerification]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO
