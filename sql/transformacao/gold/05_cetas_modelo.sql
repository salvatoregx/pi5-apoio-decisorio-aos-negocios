-- ============================================================================
-- 05_cetas_modelo.sql
--
-- Objetivo:
--   Gold de modelos: uma linha por modelo observado na janela, com fabricante,
--   mídia, função, capacidade e as especificações do catálogo dos fabricantes.
--   Alimenta dim_modelo no Azure SQL.
--
-- Origem:
--   gold.disco_mes (script 03) e gold.ref_catalogo_fabricantes (script 01).
--
-- Destino:
--   lake/gold/modelo/ (Parquet) e tabela externa gold.modelo.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Para refazer: apague a pasta lake/gold/modelo/ antes de rodar de novo.
--
-- Regras:
--   - capacidade_tb e funcao_disco: os da capacidade com mais dias-disco no
--     modelo (capacidade inválida, NULL na silver, não entra na escolha).
--   - Modelos que não estão no catálogo entram com as especificações nulas
--     e no_catalogo = 0 (regra do guia, seção 6.1).
-- ============================================================================

IF OBJECT_ID('gold.modelo') IS NOT NULL
    DROP EXTERNAL TABLE gold.modelo;
GO

CREATE EXTERNAL TABLE gold.modelo
WITH (
    LOCATION = 'gold/modelo/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT
    m.modelo,
    m.fabricante,
    m.tipo_midia,
    COALESCE(c.funcao_disco, m.funcao_disco) AS funcao_disco,
    c.capacidade_tb,
    m.primeira_data,
    m.ultima_data,
    m.dias_disco,
    m.discos_distintos,
    m.falhas,
    CASE WHEN cat.modelo IS NOT NULL THEN 1 ELSE 0 END AS no_catalogo,
    cat.familia_produto,
    cat.tecnologia_gravacao,
    cat.preenchimento,
    cat.formato,
    cat.rpm,
    cat.interface,
    cat.cache_mb,
    cat.potencia_ociosa_w,
    cat.potencia_operacao_w,
    cat.criterio_potencia_operacao,
    cat.temp_operacao_min_c,
    cat.temp_operacao_max_c,
    cat.mtbf_horas,
    cat.afr_declarado_pct,
    cat.carga_trabalho_tb_ano,
    cat.garantia_anos,
    cat.observacoes
FROM (
    SELECT
        modelo,
        MAX(fabricante) AS fabricante,
        MAX(tipo_midia) AS tipo_midia,
        MAX(funcao_disco) AS funcao_disco,
        MIN(primeira_data) AS primeira_data,
        MAX(ultima_data) AS ultima_data,
        SUM(dias_disco) AS dias_disco,
        COUNT_BIG(DISTINCT numero_serie) AS discos_distintos,
        SUM(falhas) AS falhas
    FROM gold.disco_mes
    GROUP BY modelo
) AS m
LEFT JOIN (
    -- Capacidade predominante do modelo
    SELECT modelo, capacidade_tb, funcao_disco
    FROM (
        SELECT
            modelo,
            capacidade_tb,
            MAX(funcao_disco) AS funcao_disco,
            ROW_NUMBER() OVER (PARTITION BY modelo ORDER BY SUM(dias_disco) DESC) AS ordem
        FROM gold.disco_mes
        WHERE capacidade_tb IS NOT NULL
        GROUP BY modelo, capacidade_tb
    ) AS x
    WHERE x.ordem = 1
) AS c
    ON c.modelo = m.modelo
LEFT JOIN gold.ref_catalogo_fabricantes AS cat
    ON cat.modelo = m.modelo;
GO

-- Conferência: modelos observados que ficaram fora do catálogo.
-- SELECT modelo, fabricante, dias_disco FROM gold.modelo WHERE no_catalogo = 0 ORDER BY dias_disco DESC;
