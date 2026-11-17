-- ============================================================================
-- 07_cetas_fato_confiabilidade_mensal.sql
--
-- Objetivo:
--   Gold da fato de confiabilidade, grão mês × modelo × datacenter efetivo.
--   Responde às perguntas 1 (AFR por modelo e fabricante) e 4 (setorização
--   física). Alimenta fato_confiabilidade_mensal no Azure SQL.
--
-- Origem:
--   gold.disco_mes (script 03) e gold.disco (script 04).
--
-- Destino:
--   lake/gold/fato_confiabilidade_mensal/ (Parquet) e tabela externa
--   gold.fato_confiabilidade_mensal.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Para refazer: apague a pasta lake/gold/fato_confiabilidade_mensal/.
--
-- Regras:
--   - Datacenter efetivo = COALESCE(datacenter do dia, último datacenter
--     conhecido do disco). Disco que nunca teve localização (saiu antes de
--     2023) fica como 'desconhecido'.
--   - dias_disco_imputados conta os dias-disco sem datacenter no dado original
--     (atribuídos ao último conhecido ou, sem nenhum, a 'desconhecido').
--   - afr_pct = 100 × falhas / (dias_disco / 365). Ao reagregar, some falhas e
--     dias_disco e recalcule; nunca tire média de AFR.
--   - discos_distintos não é aditivo entre meses (o mesmo disco aparece em
--     vários meses): para períodos maiores, contar em dim_disco.
-- ============================================================================

IF OBJECT_ID('gold.fato_confiabilidade_mensal') IS NOT NULL
    DROP EXTERNAL TABLE gold.fato_confiabilidade_mensal;
GO

CREATE EXTERNAL TABLE gold.fato_confiabilidade_mensal
WITH (
    LOCATION = 'gold/fato_confiabilidade_mensal/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT
    m.ano_mes,
    m.modelo,
    COALESCE(m.datacenter, d.ultimo_datacenter, 'desconhecido') AS datacenter,
    SUM(m.dias_disco) AS dias_disco,
    SUM(CASE WHEN m.datacenter IS NULL THEN m.dias_disco ELSE 0 END) AS dias_disco_imputados,
    SUM(m.falhas) AS falhas,
    COUNT_BIG(DISTINCT m.numero_serie) AS discos_distintos,
    SUM(m.tb_dias) AS tb_dias,
    SUM(m.soma_temperatura) AS soma_temperatura,
    SUM(m.contagem_temperatura) AS contagem_temperatura,
    ROUND(100.0 * SUM(m.falhas) / (SUM(m.dias_disco) / 365.0), 4) AS afr_pct
FROM gold.disco_mes AS m
LEFT JOIN gold.disco AS d
    ON d.numero_serie = m.numero_serie
GROUP BY
    m.ano_mes,
    m.modelo,
    COALESCE(m.datacenter, d.ultimo_datacenter, 'desconhecido');
GO

-- Conferência: dias-disco e falhas totais devem bater com gold.disco_mes.
-- SELECT SUM(dias_disco) AS dias_disco, SUM(falhas) AS falhas,
--        SUM(dias_disco_imputados) AS imputados
-- FROM gold.fato_confiabilidade_mensal;
