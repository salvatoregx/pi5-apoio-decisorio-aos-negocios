-- ============================================================================
-- 11_cetas_fato_temperatura_dc_dia.sql
--
-- Objetivo:
--   Materializar a view gold.vw_fato_temperatura_dc_dia no lake, um ano por vez.
--   Alimenta fato_temperatura_dc_dia no Azure SQL.
--   Pré-requisito: gold.disco (script 04), usada para imputar o datacenter.
--
-- Origem:
--   gold.vw_fato_temperatura_dc_dia (script 10), que lê silver.disco_dia e gold.disco.
--
-- Destino:
--   lake/gold/fato_temperatura_dc_dia/ano=AAAA/ (Parquet), uma tabela externa por ano:
--   gold.fato_temperatura_dc_dia_2021 ... gold.fato_temperatura_dc_dia_2026. A view gold.fato_temperatura_dc_dia, no fim do
--   script, junta todos os anos.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--
-- Como executar:
--   - Um bloco por vez (selecione o bloco do ano e execute). Cada ano lê só as
--     pastas daquele ano na bronze e fica bem abaixo do limite de ~30 min.
--   - Para refazer um ano: apague a pasta lake/gold/fato_temperatura_dc_dia/ano=AAAA/ no lake
--     (DROP EXTERNAL TABLE não apaga os arquivos e a CETAS exige pasta vazia).
--   - O filtro usa literais, não variáveis, para garantir a poda das pastas.
-- ============================================================================

-- ---------------------------------------------------------------------------- 2021
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2021') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2021;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2021
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2021/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2021-01' AND '2021-12';
GO

-- ---------------------------------------------------------------------------- 2022
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2022') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2022;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2022
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2022/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2022-01' AND '2022-12';
GO

-- ---------------------------------------------------------------------------- 2023
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2023') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2023;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2023
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2023/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2023-01' AND '2023-12';
GO

-- ---------------------------------------------------------------------------- 2024
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2024') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2024;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2024
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2024/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2024-01' AND '2024-12';
GO

-- ---------------------------------------------------------------------------- 2025
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2025') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2025;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2025
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2025/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2025-01' AND '2025-12';
GO

-- ---------------------------------------------------------------------------- 2026
IF OBJECT_ID('gold.fato_temperatura_dc_dia_2026') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_temperatura_dc_dia_2026;
GO
CREATE EXTERNAL TABLE gold.fato_temperatura_dc_dia_2026
WITH (
    LOCATION = 'gold/fato_temperatura_dc_dia/ano=2026/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_fato_temperatura_dc_dia
WHERE ano_mes BETWEEN '2026-01' AND '2026-12';
GO

-- ---------------------------------------------------------------------------- todos os anos
CREATE OR ALTER VIEW gold.fato_temperatura_dc_dia AS
SELECT *
FROM OPENROWSET(
    BULK 'gold/fato_temperatura_dc_dia/ano=*/*.parquet',
    DATA_SOURCE = 'lake',
    FORMAT = 'PARQUET'
) AS g;
GO

-- Conferência: a soma de discos (dias-disco) deve bater com gold.fato_confiabilidade_mensal.
-- SELECT SUM(discos) AS dias_disco, SUM(falhas) AS falhas, SUM(discos_imputados) AS imputados
-- FROM gold.fato_temperatura_dc_dia;
