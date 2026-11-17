-- ============================================================================
-- 00_acesso_identidade_synapse.sql
--
-- Objetivo:
--   Permitir que a atividade Copy do Synapse Pipelines grave a gold nas tabelas
--   de staging (stg) do banco dw. A identidade gerenciada do workspace vira
--   usuária do banco.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'.
--   Precisa ser executado pelo administrador Microsoft Entra do servidor
--   (CREATE USER exige permissão que os integrantes não têm). Uma vez só.
--
-- Permissões:
--   - db_datareader / db_datawriter: ler e gravar a staging.
--   - db_ddladmin: o pre-copy script da atividade Copy faz TRUNCATE TABLE,
--     que exige permissão de ALTER na tabela.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'syn-pi5-38afc4')
BEGIN
    CREATE USER [syn-pi5-38afc4] FROM EXTERNAL PROVIDER;
END;
GO

ALTER ROLE db_datareader ADD MEMBER [syn-pi5-38afc4];
ALTER ROLE db_datawriter ADD MEMBER [syn-pi5-38afc4];
ALTER ROLE db_ddladmin ADD MEMBER [syn-pi5-38afc4];
GO
