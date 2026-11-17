-- ============================================================================
-- 04_cetas_disco.sql
--
-- Objetivo:
--   Gold de discos: uma linha por disco (número de série) com o ciclo de vida
--   observado na janela 2021-07 a 2026-06. Alimenta dim_disco no Azure SQL e
--   fornece o último datacenter conhecido, usado para imputar a localização
--   nas fatos (a localização só existe a partir de 2023).
--
-- Origem:
--   gold.disco_mes (script 03).
--
-- Destino:
--   lake/gold/disco/ (Parquet) e tabela externa gold.disco.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Para refazer: apague a pasta lake/gold/disco/ antes de rodar de novo.
--
-- Regras:
--   - modelo e ultimo_datacenter: valor do último dia em que apareceram
--     (MAX de "AAAA-MM-DD" + valor, depois corta a data).
--   - situacao: 'falhou' se teve falha; 'ativo' se aparece no último dia da
--     janela; senão 'retirado' (saiu da frota sem falha registrada).
--   - censurado_esquerda = 1: o disco já operava no 1º dia da janela, então a
--     vida anterior não foi observada (a idade real vem das horas ligado).
-- ============================================================================

IF OBJECT_ID('gold.disco') IS NOT NULL
    DROP EXTERNAL TABLE gold.disco;
GO

CREATE EXTERNAL TABLE gold.disco
WITH (
    LOCATION = 'gold/disco/',
    DATA_SOURCE = lake,
    FILE_FORMAT = parquet
) AS
SELECT
    d.numero_serie,
    SUBSTRING(d.chave_modelo, 11, 200) AS modelo,
    d.primeira_data,
    d.ultima_data,
    d.dias_observados,
    CASE WHEN d.falhas > 0 THEN 1 ELSE 0 END AS falhou,
    d.data_falha,
    SUBSTRING(d.chave_datacenter, 11, 50) AS ultimo_datacenter,
    CAST(SUBSTRING(d.chave_horas_inicial, 11, 6) AS INT) AS horas_inicial,
    CAST(SUBSTRING(d.chave_horas_final, 11, 6) AS INT) AS horas_final,
    CAST(d.soma_temperatura AS FLOAT) / NULLIF(d.contagem_temperatura, 0) AS temperatura_media,
    d.temperatura_max,
    d.max_smart_005,
    d.max_smart_187,
    d.max_smart_188,
    d.max_smart_197,
    d.max_smart_198,
    CASE
        WHEN d.falhas > 0 THEN 'falhou'
        WHEN d.ultima_data = j.fim_janela THEN 'ativo'
        ELSE 'retirado'
    END AS situacao,
    CASE WHEN d.primeira_data = j.inicio_janela THEN 1 ELSE 0 END AS censurado_esquerda
FROM (
    SELECT
        m.numero_serie,
        MAX(CONVERT(CHAR(10), m.ultima_data, 23) + m.modelo) AS chave_modelo,
        MIN(m.primeira_data) AS primeira_data,
        MAX(m.ultima_data) AS ultima_data,
        SUM(m.dias_disco) AS dias_observados,
        SUM(m.falhas) AS falhas,
        MAX(m.data_falha) AS data_falha,
        MAX(CASE WHEN m.datacenter IS NOT NULL
                 THEN CONVERT(CHAR(10), m.ultima_data, 23) + m.datacenter
            END) AS chave_datacenter,
        MIN(m.chave_horas_inicial) AS chave_horas_inicial,
        MAX(m.chave_horas_final) AS chave_horas_final,
        SUM(m.soma_temperatura) AS soma_temperatura,
        SUM(m.contagem_temperatura) AS contagem_temperatura,
        MAX(m.temperatura_max) AS temperatura_max,
        MAX(m.max_smart_005) AS max_smart_005,
        MAX(m.max_smart_187) AS max_smart_187,
        MAX(m.max_smart_188) AS max_smart_188,
        MAX(m.max_smart_197) AS max_smart_197,
        MAX(m.max_smart_198) AS max_smart_198
    FROM gold.disco_mes AS m
    GROUP BY m.numero_serie
) AS d
CROSS JOIN (
    SELECT MIN(primeira_data) AS inicio_janela, MAX(ultima_data) AS fim_janela
    FROM gold.disco_mes
) AS j;
GO

-- Conferência:
-- SELECT situacao, COUNT(*) AS discos, SUM(dias_observados) AS dias_disco
-- FROM gold.disco GROUP BY situacao;
-- SELECT COUNT(*) AS discos_sem_datacenter FROM gold.disco WHERE ultimo_datacenter IS NULL;
