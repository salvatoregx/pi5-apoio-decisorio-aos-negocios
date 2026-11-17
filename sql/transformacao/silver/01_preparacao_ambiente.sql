-- ============================================================================
-- 01_preparacao_ambiente.sql
-- 
-- Objetivo:
--   Criação de credenciais, data source externo e schemas no banco de dados
--   do pool serverless do Azure Synapse Analytics.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in).
--   - O comando de criação do banco roda conectado no banco 'master'.
--   - Os demais comandos rodam conectados no banco 'pi5'.
--
-- Observações importantes:
--   1. A master key exige uma senha, que não fica no repositório: o bloco dela está
--      comentado de propósito. Descomente, troque '<SENHA_FORTE>' por uma senha forte,
--      guarde-a fora do repositório e execute uma única vez. Sem a master key, a
--      criação da credencial abaixo falha, o que evita rodar o script sem esse ajuste.
--   2. A autenticação com o lake utiliza a Identidade Gerenciada (Managed Identity)
--      do workspace do Synapse, que já possui permissão de leitura/escrita no ADLS Gen2.
-- ============================================================================

-- 1. Criação do banco de dados com collation UTF-8 (necessário para ler textos em Parquet)
-- Conectar no banco 'master' para executar este bloco:
-- CREATE DATABASE pi5 COLLATE Latin1_General_100_BIN2_UTF8;

-- 2. Conectar no banco 'pi5' para executar os passos abaixo:
-- USE pi5;

-- Criação da Master Key para proteção de credenciais com escopo de banco.
-- Comentado de propósito: ver a observação 1 no cabeçalho.
-- IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
-- BEGIN
--     CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<SENHA_FORTE>';
-- END;
-- GO

-- Credencial com escopo de banco apontando para a Managed Identity do workspace
IF NOT EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'identidade_workspace')
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL identidade_workspace 
    WITH IDENTITY = 'Managed Identity';
END;
GO

-- Fonte de dados externa apontando para a raiz do container /lake
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'lake')
BEGIN
    CREATE EXTERNAL DATA SOURCE lake WITH (
        LOCATION = 'https://stpi538afc4.dfs.core.windows.net/lake',
        CREDENTIAL = identidade_workspace
    );
END;
GO

-- Formato de arquivo externo para Parquet
IF NOT EXISTS (SELECT * FROM sys.external_file_formats WHERE name = 'parquet')
BEGIN
    CREATE EXTERNAL FILE FORMAT parquet WITH (FORMAT_TYPE = PARQUET);
END;
GO

-- Criação dos esquemas lógicos
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver');
END;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO
