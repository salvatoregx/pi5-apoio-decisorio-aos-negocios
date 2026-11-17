-- ============================================================================
-- 03_cetas_disco_mes.sql
--
-- Objetivo:
--   Materializar a view gold.vw_disco_mes no lake, um ano por vez.
--
-- Origem:
--   gold.vw_disco_mes (script 02), que lê silver.disco_dia.
--
-- Destino:
--   lake/gold/disco_mes/ano=AAAA/ (Parquet), uma tabela externa por ano:
--   gold.disco_mes_2021 ... gold.disco_mes_2026. A view gold.disco_mes, no fim do
--   script, junta todos os anos.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--
-- Como executar:
--   - Um bloco por vez (selecione o bloco do ano e execute). Cada ano lê só as
--     pastas daquele ano na bronze e fica bem abaixo do limite de ~30 min.
--   - Para refazer um ano: apague a pasta lake/gold/disco_mes/ano=AAAA/ no lake
--     (DROP EXTERNAL TABLE não apaga os arquivos e a CETAS exige pasta vazia).
--   - O filtro usa literais, não variáveis, para garantir a poda das pastas.
-- ============================================================================

-- ---------------------------------------------------------------------------- 2021
IF OBJECT_ID('gold.disco_mes_2021') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2021;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2021
WITH (
    LOCATION = 'gold/disco_mes/ano=2021/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2021-01' AND '2021-12';
GO

-- ---------------------------------------------------------------------------- 2022
IF OBJECT_ID('gold.disco_mes_2022') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2022;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2022
WITH (
    LOCATION = 'gold/disco_mes/ano=2022/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2022-01' AND '2022-12';
GO

-- ---------------------------------------------------------------------------- 2023
IF OBJECT_ID('gold.disco_mes_2023') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2023;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2023
WITH (
    LOCATION = 'gold/disco_mes/ano=2023/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2023-01' AND '2023-12';
GO

-- ---------------------------------------------------------------------------- 2024
IF OBJECT_ID('gold.disco_mes_2024') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2024;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2024
WITH (
    LOCATION = 'gold/disco_mes/ano=2024/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2024-01' AND '2024-12';
GO

-- ---------------------------------------------------------------------------- 2025
IF OBJECT_ID('gold.disco_mes_2025') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2025;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2025
WITH (
    LOCATION = 'gold/disco_mes/ano=2025/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2025-01' AND '2025-12';
GO

-- ---------------------------------------------------------------------------- 2026
IF OBJECT_ID('gold.disco_mes_2026') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco_mes_2026;
GO
CREATE EXTERNAL TABLE gold.disco_mes_2026
WITH (
    LOCATION = 'gold/disco_mes/ano=2026/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT *
FROM gold.vw_disco_mes
WHERE ano_mes BETWEEN '2026-01' AND '2026-12';
GO

-- ---------------------------------------------------------------------------- todos os anos
-- Lê todas as pastas gravadas acima. Usada pelos próximos scripts da gold.
CREATE OR ALTER VIEW gold.disco_mes AS
SELECT *
FROM OPENROWSET(
    BULK 'gold/disco_mes/ano=*/*.parquet',
    DATA_SOURCE = 'lake',
    FORMAT = 'PARQUET'
) AS g;
GO

-- Conferência: a soma de dias_disco por mês deve bater com as linhas da silver.
-- SELECT ano_mes, SUM(dias_disco) AS dias_disco, SUM(falhas) AS falhas
-- FROM gold.disco_mes GROUP BY ano_mes ORDER BY ano_mes;
