-- ============================================================================
-- 10_view_fato_temperatura_dc_dia.sql
--
-- Objetivo:
--   Lógica da fato de temperatura, grão dia × datacenter efetivo × tipo de mídia.
--   Responde à pergunta 4 (há datacenter mais quente?) e apoia a 2.
--
-- Origem:
--   silver.disco_dia e gold.disco (último datacenter conhecido, para imputar
--   a localização antes de 2023).
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Materializada por ano no script 11.
--
-- Regras:
--   - Datacenter efetivo: mesma regra da fato mensal (COALESCE com o último
--     datacenter conhecido; sem nenhum, 'desconhecido'). discos_imputados conta
--     os discos do dia sem datacenter no dado original.
--   - Percentis p50 e p95 pelo método do posto mais próximo (equivale a
--     PERCENTILE_DISC): a menor temperatura cuja frequência acumulada alcança
--     50% / 95% das leituras válidas. A temperatura é inteira (1 a 100 °C),
--     então o histograma por grau dá o percentil exato sem ordenar linha a linha.
--   - Uma única cadeia de agregações (sem junção entre CTEs) para que o filtro
--     por ano_mes da CETAS chegue até a bronze e leia só as pastas do ano.
--   - Medidas não aditivas (percentis, máximo) acompanham as partes aditivas
--     (soma e contagem de temperatura) para reagregar médias corretamente.
-- ============================================================================

CREATE OR ALTER VIEW gold.vw_fato_temperatura_dc_dia AS
WITH dia AS (
    SELECT
        s.ano_mes,
        s.data,
        COALESCE(s.datacenter, d.ultimo_datacenter, 'desconhecido') AS datacenter,
        s.tipo_midia,
        CASE WHEN s.datacenter IS NULL THEN 1 ELSE 0 END AS imputado,
        s.capacidade_tb,
        s.temperatura_c,
        s.falha
    FROM silver.disco_dia AS s
    LEFT JOIN gold.disco AS d
        ON d.numero_serie = s.numero_serie
),
-- Histograma por grau (inclui uma linha para temperatura NULL, para não perder
-- discos, capacidade e falhas dos dias sem leitura válida)
histograma AS (
    SELECT
        ano_mes,
        data,
        datacenter,
        tipo_midia,
        temperatura_c,
        COUNT_BIG(*) AS discos,
        SUM(imputado) AS discos_imputados,
        SUM(capacidade_tb) AS capacidade_tb,
        SUM(CAST(falha AS INT)) AS falhas
    FROM dia
    GROUP BY ano_mes, data, datacenter, tipo_midia, temperatura_c
),
acumulado AS (
    SELECT
        h.*,
        -- SUM ignora NULL: a linha de temperatura NULL não entra no acumulado
        SUM(CASE WHEN h.temperatura_c IS NOT NULL THEN h.discos END) OVER (
            PARTITION BY h.ano_mes, h.data, h.datacenter, h.tipo_midia
            ORDER BY h.temperatura_c
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS leituras_acumuladas,
        SUM(CASE WHEN h.temperatura_c IS NOT NULL THEN h.discos END) OVER (
            PARTITION BY h.ano_mes, h.data, h.datacenter, h.tipo_midia
        ) AS leituras_total
    FROM histograma AS h
)
SELECT
    ano_mes,
    data,
    datacenter,
    tipo_midia,
    SUM(discos) AS discos,
    SUM(discos_imputados) AS discos_imputados,
    SUM(capacidade_tb) AS capacidade_tb_total,
    SUM(CAST(temperatura_c AS BIGINT) * discos) AS soma_temperatura,
    SUM(CASE WHEN temperatura_c IS NOT NULL THEN discos ELSE 0 END) AS contagem_temperatura,
    MIN(CASE WHEN temperatura_c IS NOT NULL AND leituras_acumuladas >= 0.50 * leituras_total
             THEN temperatura_c END) AS temperatura_p50,
    MIN(CASE WHEN temperatura_c IS NOT NULL AND leituras_acumuladas >= 0.95 * leituras_total
             THEN temperatura_c END) AS temperatura_p95,
    MAX(temperatura_c) AS temperatura_max,
    SUM(falhas) AS falhas
FROM acumulado
GROUP BY ano_mes, data, datacenter, tipo_midia;
GO

-- Teste barato (um mês):
-- SELECT TOP 50 * FROM gold.vw_fato_temperatura_dc_dia WHERE ano_mes = '2024-01' ORDER BY data, datacenter;
