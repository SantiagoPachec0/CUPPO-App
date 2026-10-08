USE [CUPPO];
GO

-- ===== Log.InsertLogError
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 3. STORED PROCEDURE PARA REGISTRAR LOGS DE ERROR
CREATE   PROCEDURE [Log].[InsertLogError]
    @UserId INT = NULL,
    @AppModule VARCHAR(100) = NULL,
    @MethodName VARCHAR(100) = NULL,
    @ProcedureName VARCHAR(100),
    @ErrorCode INT,
    @ErrorMessage VARCHAR(MAX),
    @InputData VARCHAR(MAX) = NULL,
    @ClientIP VARCHAR(45) = NULL,
    @Param8 VARCHAR(100) = NULL,
    @Param9 VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Log].[ErrorLog] (
        [UserId],
        [AppModule],
        [MethodName],
        [ProcedureName],
        [ErrorCode],
        [ErrorMessage],
        [InputData],
        [ClientIP]
    )
    VALUES (
        @UserId,
        @AppModule,
        @MethodName,
        @ProcedureName,
        @ErrorCode,
        @ErrorMessage,
        @InputData,
        @ClientIP
    );
END;
GO

-- ===== Security.AssignRolePermission
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   5. ASIGNACIONES ([RolePermissions] y [UserRoles])
   ============================================================================ */

-- 5.1 ASIGNAR / RECOCAR PERMISOS A UN ROL (RolePermissions)
CREATE   PROCEDURE [Security].[AssignRolePermission]
    @RoleID INT,
    @ModuleActionID INT,
    @CreationUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Roles] WHERE [RoleID] = @RoleID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El rol especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM [Security].[ModuleActions] WHERE [ModuleActionID] = @ModuleActionID)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'La acción de módulo especificada no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE [RoleID] = @RoleID AND [ModuleActionID] = @ModuleActionID)
            BEGIN
                SET @CodeResult = 1;
                SET @MessageResult = 'El permiso ya se encuentra asignado al rol.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[RolePermissions] ([RoleID], [ModuleActionID], [CreationUserID], [CreationDate])
            VALUES (@RoleID, @ModuleActionID, @CreationUserID, GETDATE());

            SET @CodeResult = 1;
            SET @MessageResult = 'Permiso asignado al rol exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'RoleID: ', ISNULL(CAST(@RoleID AS VARCHAR(20)), 'NULL'), ' | ',
            'ModuleActionID: ', ISNULL(CAST(@ModuleActionID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[AssignRolePermission]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.AssignUserRole
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 5.2 ASIGNAR ROL A UN USUARIO (UserRoles)
CREATE   PROCEDURE [Security].[AssignUserRole]
    @UserID INT,
    @RoleID INT,
    @CreationUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El usuario especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM [Security].[Roles] WHERE [RoleID] = @RoleID)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El rol especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Security].[UserRoles] WHERE [UserID] = @UserID AND [RoleID] = @RoleID)
            BEGIN
                SET @CodeResult = 1;
                SET @MessageResult = 'El rol ya está asignado al usuario.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID], [CreationDate])
            VALUES (@UserID, @RoleID, @CreationUserID, GETDATE());

            SET @CodeResult = 1;
            SET @MessageResult = 'Rol asignado al usuario exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'UserID: ', ISNULL(CAST(@UserID AS VARCHAR(20)), 'NULL'), ' | ',
            'RoleID: ', ISNULL(CAST(@RoleID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[AssignUserRole]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.GetUserPermissions
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- SP 2: OBTENER TODOS LOS MÓDULOS Y ACCIONES PERMITIDAS DE UN USUARIO (Para Menú de la App / JWT)
CREATE   PROCEDURE [Security].[GetUserPermissions]
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
    INNER JOIN [Security].[Roles] R ON UR.[RoleID] = R.[RoleID]
    INNER JOIN [Security].[RolePermissions] RP ON R.[RoleID] = RP.[RoleID]
    INNER JOIN [Security].[ModuleActions] MA ON RP.[ModuleActionID] = MA.[ModuleActionID]
    INNER JOIN [Security].[Modules] M ON MA.[ModuleID] = M.[ModuleID]
    INNER JOIN [Security].[Actions] A ON MA.[ActionID] = A.[ActionID]
    WHERE UR.[UserID] = @UserID
      AND R.[StatusID] = 1
      AND M.[StatusID] = 1
      AND A.[StatusID] = 1
      AND MA.[StatusID] = 1
    ORDER BY M.[DisplayOrder], M.[ModuleID];
END;
GO

-- ===== Security.InsertAction
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   3. GESTIÓN DE ACCIONES ([Security].[Actions])
   ============================================================================ */

-- 3.1 INSERT ACTION
CREATE   PROCEDURE [Security].[InsertAction]
    @Code VARCHAR(20),
    @Name VARCHAR(50),
    @Description VARCHAR(500) = NULL,
    @StatusID INT = 1,
    @CreationUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM [Security].[Actions] WHERE [Code] = @Code)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de acción especificado ya existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[Actions] (
                [Code],
                [Name],
                [Description],
                [StatusID],
                [CreationUserID],
                [CreationDate]
            )
            VALUES (
                @Code,
                @Name,
                @Description,
                ISNULL(@StatusID, 1),
                @CreationUserID,
                GETDATE()
            );

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Acción registrada exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'Name: ', ISNULL(@Name, 'NULL'), ' | ',
            'CreationUserID: ', ISNULL(CAST(@CreationUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[InsertAction]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.InsertModule
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   2. GESTIÓN DE MÓDULOS ([Security].[Modules])
   ============================================================================ */

-- 2.1 INSERT MODULE
CREATE   PROCEDURE [Security].[InsertModule]
    @Code VARCHAR(20),
    @Name VARCHAR(50),
    @Description VARCHAR(500) = NULL,
    @ParentModuleID INT = NULL,
    @Icon VARCHAR(50) = NULL,
    @Route VARCHAR(100) = NULL,
    @DisplayOrder INT = 0,
    @StatusID INT = 1,
    @CreationUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM [Security].[Modules] WHERE [Code] = @Code)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de módulo especificado ya existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @ParentModuleID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Security].[Modules] WHERE [ModuleID] = @ParentModuleID)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El módulo padre especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[Modules] (
                [Code],
                [Name],
                [Description],
                [ParentModuleID],
                [Icon],
                [Route],
                [DisplayOrder],
                [StatusID],
                [CreationUserID],
                [CreationDate]
            )
            VALUES (
                @Code,
                @Name,
                @Description,
                @ParentModuleID,
                @Icon,
                @Route,
                ISNULL(@DisplayOrder, 0),
                ISNULL(@StatusID, 1),
                @CreationUserID,
                GETDATE()
            );

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Módulo registrado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'Name: ', ISNULL(@Name, 'NULL'), ' | ',
            'ParentModuleID: ', ISNULL(CAST(@ParentModuleID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[InsertModule]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.InsertModuleAction
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   4. GESTIÓN MATRIZ MÓDULO - ACCIÓN ([Security].[ModuleActions])
   ============================================================================ */

-- 4.1 INSERT MODULE ACTION
CREATE   PROCEDURE [Security].[InsertModuleAction]
    @ModuleID INT,
    @ActionID INT,
    @StatusID INT = 1,
    @CreationUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Modules] WHERE [ModuleID] = @ModuleID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El módulo especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF NOT EXISTS (SELECT 1 FROM [Security].[Actions] WHERE [ActionID] = @ActionID)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'La acción especificada no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM [Security].[ModuleActions] WHERE [ModuleID] = @ModuleID AND [ActionID] = @ActionID)
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'La combinación Módulo-Acción ya se encuentra registrada.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[ModuleActions] (
                [ModuleID],
                [ActionID],
                [StatusID]
            )
            VALUES (
                @ModuleID,
                @ActionID,
                ISNULL(@StatusID, 1)
            );

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Acción de módulo habilitada exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'ModuleID: ', ISNULL(CAST(@ModuleID AS VARCHAR(20)), 'NULL'), ' | ',
            'ActionID: ', ISNULL(CAST(@ActionID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[InsertModuleAction]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.InsertRole
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   1. GESTIÓN DE ROLES ([Security].[Roles])
   ============================================================================ */

-- 1.1 INSERT ROLE
CREATE   PROCEDURE [Security].[InsertRole]
    @Code VARCHAR(20),
    @Name VARCHAR(50),
    @Description VARCHAR(250) = NULL,
    @StatusID INT = 1,
    @CreationUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM [Security].[Roles] WHERE [Code] = @Code)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de rol especificado ya existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO [Security].[Roles] (
                [Code],
                [Name],
                [Description],
                [StatusID],
                [CreationUserID],
                [CreationDate]
            )
            VALUES (
                @Code,
                @Name,
                @Description,
                ISNULL(@StatusID, 1),
                @CreationUserID,
                GETDATE()
            );

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Rol registrado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'Name: ', ISNULL(@Name, 'NULL'), ' | ',
            'CreationUserID: ', ISNULL(CAST(@CreationUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @CreationUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[InsertRole]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.InsertUser
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 6. STORED PROCEDURE: AGREGAR USUARIO (InsertUser)
CREATE   PROCEDURE [Security].[InsertUser]
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

            -- Validación de usuario duplicado
            IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserLogin] = @UserLogin)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El nombre de usuario (UserLogin) ya está registrado.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Validación de correo duplicado
            IF EXISTS (SELECT 1 FROM [Security].[Users] WHERE [Mail] = @Mail)
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El correo electrónico ya está registrado.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Generación de Salt de 32 bytes acorde al tipo varbinary(32) de la tabla
            DECLARE @Salt VARBINARY(32) = CRYPT_GEN_RANDOM(32);

            -- Cálculo del Hash de la contraseña
            DECLARE @PasswordHash VARBINARY(256) = [Security].[encryptHash](@Password, @Salt);

            INSERT INTO [Security].[Users] (
                [UserLogin],
                [Name],
                [Mail],
                [PasswordHash],
                [PasswordSalt],
                [Blocked],
                [FailedLoginAttempts],
                [StatusID],
                [CreationUserID],
                [CreationDate]
            )
            VALUES (
                @UserLogin,
                @Name,
                @Mail,
                @PasswordHash,
                @Salt,
                ISNULL(@Blocked, 0),
                ISNULL(@FailedLoginAttempts, 0),
                ISNULL(@StatusID, 1),
                @CreationUserID,
                GETDATE()
            );

            SET @CodeResult = SCOPE_IDENTITY();
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

-- ===== Security.UpdateAction
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 3.2 UPDATE ACTION
CREATE   PROCEDURE [Security].[UpdateAction]
    @ActionID INT,
    @Code VARCHAR(20) = NULL,
    @Name VARCHAR(50) = NULL,
    @Description VARCHAR(500) = NULL,
    @StatusID INT = NULL,
    @UpdateUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Actions] WHERE [ActionID] = @ActionID)
            BEGIN
                SET @CodeResult = 0;
                SET @MessageResult = 'La acción especificada no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @Code IS NOT NULL AND EXISTS (SELECT 1 FROM [Security].[Actions] WHERE [Code] = @Code AND [ActionID] <> @ActionID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de acción ya pertenece a otro registro.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Security].[Actions]
            SET 
                [Code] = ISNULL(@Code, [Code]),
                [Name] = ISNULL(@Name, [Name]),
                [Description] = ISNULL(@Description, [Description]),
                [StatusID] = ISNULL(@StatusID, [StatusID]),
                [UpdateUserID] = ISNULL(@UpdateUserID, [UpdateUserID]),
                [UpdateDate] = GETDATE()
            WHERE [ActionID] = @ActionID;

            SET @CodeResult = 1;
            SET @MessageResult = 'Acción actualizada exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'ActionID: ', ISNULL(CAST(@ActionID AS VARCHAR(20)), 'NULL'), ' | ',
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'UpdateUserID: ', ISNULL(CAST(@UpdateUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @UpdateUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[UpdateAction]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.UpdateModule
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 2.2 UPDATE MODULE
CREATE   PROCEDURE [Security].[UpdateModule]
    @ModuleID INT,
    @Code VARCHAR(20) = NULL,
    @Name VARCHAR(50) = NULL,
    @Description VARCHAR(500) = NULL,
    @ParentModuleID INT = NULL,
    @Icon VARCHAR(50) = NULL,
    @Route VARCHAR(100) = NULL,
    @DisplayOrder INT = NULL,
    @StatusID INT = NULL,
    @UpdateUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Modules] WHERE [ModuleID] = @ModuleID)
            BEGIN
                SET @CodeResult = 0;
                SET @MessageResult = 'El módulo especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @Code IS NOT NULL AND EXISTS (SELECT 1 FROM [Security].[Modules] WHERE [Code] = @Code AND [ModuleID] <> @ModuleID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de módulo ya pertenece a otro registro.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @ParentModuleID IS NOT NULL AND @ParentModuleID = @ModuleID
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'Un módulo no puede asignarse a sí mismo como módulo padre.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Security].[Modules]
            SET 
                [Code] = ISNULL(@Code, [Code]),
                [Name] = ISNULL(@Name, [Name]),
                [Description] = ISNULL(@Description, [Description]),
                [ParentModuleID] = ISNULL(@ParentModuleID, [ParentModuleID]),
                [Icon] = ISNULL(@Icon, [Icon]),
                [Route] = ISNULL(@Route, [Route]),
                [DisplayOrder] = ISNULL(@DisplayOrder, [DisplayOrder]),
                [StatusID] = ISNULL(@StatusID, [StatusID]),
                [UpdateUserID] = ISNULL(@UpdateUserID, [UpdateUserID]),
                [UpdateDate] = GETDATE()
            WHERE [ModuleID] = @ModuleID;

            SET @CodeResult = 1;
            SET @MessageResult = 'Módulo actualizado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'ModuleID: ', ISNULL(CAST(@ModuleID AS VARCHAR(20)), 'NULL'), ' | ',
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'UpdateUserID: ', ISNULL(CAST(@UpdateUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @UpdateUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[UpdateModule]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.UpdateModuleAction
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 4.2 UPDATE MODULE ACTION STATUS
CREATE   PROCEDURE [Security].[UpdateModuleAction]
    @ModuleActionID INT,
    @StatusID INT,
    @UpdateUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[ModuleActions] WHERE [ModuleActionID] = @ModuleActionID)
            BEGIN
                SET @CodeResult = 0;
                SET @MessageResult = 'La combinación Módulo-Acción especificada no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Security].[ModuleActions]
            SET [StatusID] = @StatusID
            WHERE [ModuleActionID] = @ModuleActionID;

            SET @CodeResult = 1;
            SET @MessageResult = 'Estado de Módulo-Acción actualizado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'ModuleActionID: ', ISNULL(CAST(@ModuleActionID AS VARCHAR(20)), 'NULL'), ' | ',
            'StatusID: ', ISNULL(CAST(@StatusID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @UpdateUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[UpdateModuleAction]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.UpdateRole
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 1.2 UPDATE ROLE
CREATE   PROCEDURE [Security].[UpdateRole]
    @RoleID INT,
    @Code VARCHAR(20) = NULL,
    @Name VARCHAR(50) = NULL,
    @Description VARCHAR(250) = NULL,
    @StatusID INT = NULL,
    @UpdateUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM [Security].[Roles] WHERE [RoleID] = @RoleID)
            BEGIN
                SET @CodeResult = 0;
                SET @MessageResult = 'El rol especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @Code IS NOT NULL AND EXISTS (SELECT 1 FROM [Security].[Roles] WHERE [Code] = @Code AND [RoleID] <> @RoleID)
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El código de rol ya pertenece a otro registro.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Security].[Roles]
            SET 
                [Code] = ISNULL(@Code, [Code]),
                [Name] = ISNULL(@Name, [Name]),
                [Description] = ISNULL(@Description, [Description]),
                [StatusID] = ISNULL(@StatusID, [StatusID]),
                [UpdateUserID] = ISNULL(@UpdateUserID, [UpdateUserID]),
                [UpdateDate] = GETDATE()
            WHERE [RoleID] = @RoleID;

            SET @CodeResult = 1;
            SET @MessageResult = 'Rol actualizado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'RoleID: ', ISNULL(CAST(@RoleID AS VARCHAR(20)), 'NULL'), ' | ',
            'Code: ', ISNULL(@Code, 'NULL'), ' | ',
            'UpdateUserID: ', ISNULL(CAST(@UpdateUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @UpdateUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[UpdateRole]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.UpdateUser
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [Security].[UpdateUser]
    @UserID INT,
    @UserLogin VARCHAR(50) = NULL,
    @Name VARCHAR(50) = NULL,
    @Mail VARCHAR(50) = NULL,
    @Blocked BIT = NULL,
    @FailedLoginAttempts INT = NULL,
    @StatusID INT = NULL,
    @UpdateUserID INT = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            -- 1. Verificación de existencia del usuario
            IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID)
            BEGIN
                SET @CodeResult = 0;
                SET @MessageResult = 'El usuario especificado no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- 2. Verificación de duplicidad de UserLogin (si se está actualizando)
            IF @UserLogin IS NOT NULL AND EXISTS (
                SELECT 1 FROM [Security].[Users] 
                WHERE [UserLogin] = @UserLogin AND [UserID] <> @UserID
            )
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El nombre de usuario (UserLogin) ya pertenece a otro registro.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- 3. Verificación de duplicidad de Mail (si se está actualizando)
            IF @Mail IS NOT NULL AND EXISTS (
                SELECT 1 FROM [Security].[Users] 
                WHERE [Mail] = @Mail AND [UserID] <> @UserID
            )
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'El correo electrónico ya pertenece a otro registro.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- 4. Actualización de campos y registro de auditoría
            UPDATE [Security].[Users]
            SET 
                [UserLogin] = ISNULL(@UserLogin, [UserLogin]),
                [Name] = ISNULL(@Name, [Name]),
                [Mail] = ISNULL(@Mail, [Mail]),
                [Blocked] = ISNULL(@Blocked, [Blocked]),
                [FailedLoginAttempts] = ISNULL(@FailedLoginAttempts, [FailedLoginAttempts]),
                [StatusID] = ISNULL(@StatusID, [StatusID]),
                [UpdateUserID] = ISNULL(@UpdateUserID, [UpdateUserID]),
                [UpdateDate] = GETDATE()
            WHERE [UserID] = @UserID;

            -- 5. Confirmación de éxito
            SET @CodeResult = 1;
            SET @MessageResult = 'Usuario actualizado exitosamente.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'UserID: ', ISNULL(CAST(@UserID AS VARCHAR(20)), 'NULL'), ' | ',
            'UserLogin: ', ISNULL(@UserLogin, 'NULL'), ' | ',
            'Mail: ', ISNULL(@Mail, 'NULL'), ' | ',
            'UpdateUserID: ', ISNULL(CAST(@UpdateUserID AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError] 
            @UserId = @UpdateUserID,
            @AppModule = 'Security',
            @MethodName = NULL,
            @ProcedureName = '[Security].[UpdateUser]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Security.ValidateUserLogin
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 7. STORED PROCEDURE: VALIDAR AUTENTICACIÓN (ValidateUserLogin)
CREATE   PROCEDURE [Security].[ValidateUserLogin]
    @Identifier VARCHAR(50), -- Puede ser UserLogin o Mail
    @Password VARCHAR(100),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT;
    DECLARE @StoredHash VARBINARY(256);
    DECLARE @StoredSalt VARBINARY(32);
    DECLARE @Blocked BIT;
    DECLARE @StatusID INT;
    DECLARE @FailedLoginAttempts INT;

    SELECT 
        @UserID = [UserID],
        @StoredHash = [PasswordHash],
        @StoredSalt = [PasswordSalt],
        @Blocked = [Blocked],
        @StatusID = [StatusID],
        @FailedLoginAttempts = [FailedLoginAttempts]
    FROM [Security].[Users]
    WHERE [UserLogin] = @Identifier OR [Mail] = @Identifier;

    -- Caso 1: El usuario no existe
    IF @UserID IS NULL
    BEGIN
        SET @CodeResult = -1;
        SET @MessageResult = 'Credenciales inválidas.';
        RETURN;
    END

    -- Caso 2: El usuario se encuentra bloqueado o inactivo
    IF @Blocked = 1 OR @StatusID <> 1
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'La cuenta de usuario se encuentra bloqueada o inactiva.';
        RETURN;
    END

    -- Calcular Hash con la contraseña en texto plano recibida y el Salt almacenado
    DECLARE @ComputedHash VARBINARY(256) = [Security].[encryptHash](@Password, @StoredSalt);

    -- Caso 3: Contraseña correcta
    IF @ComputedHash = @StoredHash
    BEGIN
        UPDATE [Security].[Users]
        SET [FailedLoginAttempts] = 0,
            [UpdateDate] = GETDATE()
        WHERE [UserID] = @UserID;

        SET @CodeResult = @UserID;
        SET @MessageResult = 'Autenticación exitosa.';
    END
    ELSE
    -- Caso 4: Contraseña incorrecta (Suma intento fallido)
    BEGIN
        SET @FailedLoginAttempts = @FailedLoginAttempts + 1;

        UPDATE [Security].[Users]
        SET [FailedLoginAttempts] = @FailedLoginAttempts,
            [Blocked] = CASE WHEN @FailedLoginAttempts >= 5 THEN 1 ELSE [Blocked] END,
            [UpdateDate] = GETDATE()
        WHERE [UserID] = @UserID;

        IF @FailedLoginAttempts >= 5
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Ha superado el límite de intentos fallidos. La cuenta ha sido bloqueada.';
        END
        ELSE
        BEGIN
            SET @CodeResult = -1;
            SET @MessageResult = 'Credenciales inválidas.';
        END
    END
END;
GO

-- ===== Security.ValidateUserPermission
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==========================================================
-- 3. STORED PROCEDURES DE VALIDACIÓN Y GESTIÓN
-- ==========================================================

-- SP 1: VALIDAR SI UN USUARIO TIENE PERMISO SOBRE UN MÓDULO Y ACCIÓN ESPECÍFICA
CREATE   PROCEDURE [Security].[ValidateUserPermission]
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
        -- Verificar si el usuario está activo y no bloqueado
        IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID AND [Blocked] = 0 AND [StatusID] = 1)
        BEGIN
            SET @HasPermission = 0;
            SET @CodeResult = -1;
            SET @MessageResult = 'Usuario inactivo o bloqueado.';
            RETURN;
        END

        -- Consultar si existe la relación activa en sus roles asignados
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

        DECLARE @InputDataParam VARCHAR(250);
        SET @InputDataParam = CONCAT('Module:', @ModuleCode, ' | Action:', @ActionCode);

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

