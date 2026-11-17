-- ============================================================================
-- 02_view_bronze_drivestats.sql
--
-- Objetivo:
--   Criar a view sobre os arquivos Parquet da camada bronze no data lake,
--   expondo a coluna virtual 'ano_mes' via filepath(1) para permitir poda de
--   partições (partition pruning) pelo Synapse Serverless SQL.
--
-- Origem:
--   lake/bronze/drivestats/ano_mes=*/*.parquet (ADLS Gen2)
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
-- ============================================================================

CREATE OR ALTER VIEW bronze.drivestats AS
SELECT 
    b.*, 
    b.filepath(1) AS ano_mes
FROM OPENROWSET(
    BULK 'bronze/drivestats/ano_mes=*/*.parquet',
    DATA_SOURCE = 'lake',
    FORMAT = 'PARQUET'
) AS b;
GO
