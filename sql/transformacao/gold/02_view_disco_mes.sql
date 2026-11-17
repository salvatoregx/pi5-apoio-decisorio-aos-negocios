-- ============================================================================
-- 02_view_disco_mes.sql
--
-- Objetivo:
--   View intermediária da gold: agrega a silver em uma linha por
--   disco × mês × modelo × capacidade × datacenter do dia (que pode ser NULL).
--   Reduz ~493 milhões de dias-disco a ~20 milhões de linhas, de onde saem
--   gold.disco, gold.modelo e gold.fato_confiabilidade_mensal.
--
-- Por que esse grão:
--   - Manter o datacenter do dia (inclusive NULL) permite aplicar depois a regra
--     do datacenter efetivo (COALESCE com o último datacenter do disco) sem
--     reler a silver, e contar exatamente os dias-disco imputados.
--   - Medidas são todas aditivas (contagens e somas) ou MIN/MAX, que reagregam
--     sem erro para o disco inteiro ou para o modelo.
--
-- Origem:
--   silver.disco_dia (view sobre a bronze).
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--
-- Observações:
--   - Não é materializada aqui: o script 03 grava a view no lake, um ano por vez,
--     filtrando por ano_mes (o filtro chega até a bronze e lê só aquelas pastas).
--   - chave_horas_inicial / chave_horas_final guardam "AAAA-MM-DD" + horas com
--     6 dígitos. O MIN/MAX desse texto devolve as horas do primeiro/último dia
--     com leitura válida, sem precisar de função de janela.
-- ============================================================================

CREATE OR ALTER VIEW gold.vw_disco_mes AS
SELECT
    s.numero_serie,
    s.ano_mes,
    s.modelo,
    MAX(s.fabricante) AS fabricante,
    MAX(s.tipo_midia) AS tipo_midia,
    MAX(s.funcao_disco) AS funcao_disco,
    s.capacidade_tb,
    s.datacenter,

    MIN(s.data) AS primeira_data,
    MAX(s.data) AS ultima_data,
    COUNT_BIG(*) AS dias_disco,
    SUM(CAST(s.falha AS INT)) AS falhas,
    MAX(CASE WHEN s.falha = 1 THEN s.data END) AS data_falha,
    SUM(s.capacidade_tb) AS tb_dias,

    SUM(CAST(s.temperatura_c AS BIGINT)) AS soma_temperatura,
    COUNT_BIG(s.temperatura_c) AS contagem_temperatura,
    MAX(s.temperatura_c) AS temperatura_max,

    MIN(CASE WHEN s.horas_ligado IS NOT NULL
             THEN CONVERT(CHAR(10), s.data, 23)
                  + RIGHT('000000' + CAST(s.horas_ligado AS VARCHAR(6)), 6)
        END) AS chave_horas_inicial,
    MAX(CASE WHEN s.horas_ligado IS NOT NULL
             THEN CONVERT(CHAR(10), s.data, 23)
                  + RIGHT('000000' + CAST(s.horas_ligado AS VARCHAR(6)), 6)
        END) AS chave_horas_final,

    -- Atributos SMART preditores de falha (estudo da Backblaze): máximo no período
    MAX(s.smart_005_setores_realocados_bruto) AS max_smart_005,
    MAX(s.smart_187_erros_incorrigiveis_reportados_bruto) AS max_smart_187,
    MAX(s.smart_188_timeouts_comando_bruto) AS max_smart_188,
    MAX(s.smart_197_setores_pendentes_bruto) AS max_smart_197,
    MAX(s.smart_198_setores_incorrigiveis_offline_bruto) AS max_smart_198
FROM silver.disco_dia AS s
GROUP BY
    s.numero_serie,
    s.ano_mes,
    s.modelo,
    s.capacidade_tb,
    s.datacenter;
GO

-- Teste barato antes de materializar (um mês só):
-- SELECT TOP 100 * FROM gold.vw_disco_mes WHERE ano_mes = '2024-01';
-- SELECT SUM(dias_disco) FROM gold.vw_disco_mes WHERE ano_mes = '2024-01';
--   -> deve ser igual a SELECT COUNT_BIG(*) FROM silver.disco_dia WHERE ano_mes = '2024-01';
