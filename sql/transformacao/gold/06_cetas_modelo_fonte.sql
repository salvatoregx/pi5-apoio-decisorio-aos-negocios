-- ============================================================================
-- 06_cetas_modelo_fonte.sql
--
-- Objetivo:
--   Gold das fontes das especificações: uma linha por modelo × URL (relação 1:n
--   com o modelo). Alimenta dim_modelo_fonte no Azure SQL.
--
-- Origem:
--   gold.ref_catalogo_fontes (script 01).
--
-- Destino:
--   lake/gold/modelo_fonte/ (Parquet) e tabela externa gold.modelo_fonte.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Para refazer: apague a pasta lake/gold/modelo_fonte/ antes de rodar de novo.
-- ============================================================================

IF OBJECT_ID('gold.modelo_fonte') IS NOT NULL
    DROP EXTERNAL TABLE gold.modelo_fonte;
GO

CREATE EXTERNAL TABLE gold.modelo_fonte
WITH (
    LOCATION = 'gold/modelo_fonte/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT
    f.modelo,
    f.url,
    f.titulo,
    f.tipo_fonte,
    f.campos,
    f.acessado_em
FROM gold.ref_catalogo_fontes AS f;
GO
