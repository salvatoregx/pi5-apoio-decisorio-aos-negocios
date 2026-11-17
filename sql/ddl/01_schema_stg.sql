-- ============================================================================
-- 01_schema_stg.sql
--
-- Objetivo:
--   Criar o schema stg, que recebe a gold copiada do lake pela atividade Copy
--   do Synapse Pipelines. As dimensões e fatos ficam no schema dbo.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END;
GO
