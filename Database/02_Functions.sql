USE [CUPPO];
GO

-- ===== Security.encryptHash
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 5. FUNCIÓN ENCRIPTAR CONTRASEÑA (Adaptada a Salt de 32 Bytes y Varbinary(256))
CREATE   FUNCTION [Security].[encryptHash](
    @Password VARCHAR(MAX),
    @Salt VARBINARY(32)
)
RETURNS VARBINARY(256)
AS
BEGIN
    -- Concatenación binaria directa evitando la conversión implícita a NVARCHAR
    RETURN CONVERT(VARBINARY(256), HASHBYTES('SHA2_512', CONVERT(VARBINARY(MAX), @Password) + @Salt));
END;
GO

