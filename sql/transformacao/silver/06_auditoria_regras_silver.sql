-- ============================================================================
-- 06_auditoria_regras_silver.sql
--
-- Objetivo:
--   Bateria de testes e auditoria de qualidade que valida a integridade das regras
--   de transformação da camada Silver em relação à Bronze:
--   1. Conferência volumétrica (Bronze vs Silver) e garantia de deduplicação;
--   2. Verificação de fabricantes não mapeados ('Outro/Desconhecido');
--   3. Saneamento conferido contra a bronze (capacidade, temperatura e horas ligado);
--   4. Relação entre SMART preditores e falha real observada.
--
-- Dica de custo no Synapse Serverless:
--   Executar com filtro de partição 'ano_mes' para limitar a leitura do OPENROWSET.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
-- ============================================================================

DECLARE @mes_auditoria VARCHAR(7) = '2024-01';

-- ============================================================================
-- Teste 1: Conferência volumétrica e duplicatas
-- ============================================================================
SELECT 
    '1. Volumetria Bronze vs Silver' AS teste,
    b.total_bronze,
    s.total_silver,
    (b.total_bronze - s.total_silver) AS duplicatas_descartadas
FROM (
    SELECT COUNT_BIG(*) AS total_bronze 
    FROM bronze.drivestats 
    WHERE ano_mes = @mes_auditoria
) AS b
CROSS JOIN (
    SELECT COUNT_BIG(*) AS total_silver 
    FROM silver.disco_dia 
    WHERE ano_mes = @mes_auditoria
) AS s;

-- ============================================================================
-- Teste 2: Modelos não mapeados / Fabricante Desconhecido
-- ============================================================================
SELECT 
    '2. Fabricante Desconhecido' AS teste,
    modelo,
    COUNT_BIG(*) AS ocorrencias
FROM silver.disco_dia
WHERE ano_mes = @mes_auditoria 
  AND fabricante = 'Outro/Desconhecido'
GROUP BY modelo
ORDER BY ocorrencias DESC;

-- ============================================================================
-- Teste 3: Saneamento conferido contra a bronze
--   Conta na bronze os valores que as regras devem anular e, na silver, os valores
--   anulados. Cada par deve ser igual (pode diferir só pelas duplicatas removidas,
--   ver teste 1). Diferença indica regra aplicada de forma errada na view.
-- ============================================================================
SELECT 
    '3. Saneamento bronze x silver' AS teste,
    b.capacidade_invalida AS bronze_capacidade_invalida,
    s.capacidade_nula AS silver_capacidade_nula,
    b.temperatura_invalida AS bronze_temperatura_invalida,
    s.temperatura_anulada AS silver_temperatura_anulada,
    b.horas_invalidas AS bronze_horas_invalidas,
    s.horas_anuladas AS silver_horas_anuladas
FROM (
    SELECT
        SUM(CASE WHEN capacity_bytes IS NULL OR capacity_bytes <= 0 THEN 1 ELSE 0 END) AS capacidade_invalida,
        SUM(CASE WHEN smart_194_raw IS NOT NULL
                  AND smart_194_raw NOT BETWEEN 1 AND 100
                  AND NOT (smart_194_raw > 255 AND (smart_194_raw & 255) BETWEEN 1 AND 100)
                 THEN 1 ELSE 0 END) AS temperatura_invalida,
        SUM(CASE WHEN smart_9_raw NOT BETWEEN 0 AND 200000 THEN 1 ELSE 0 END) AS horas_invalidas
    FROM bronze.drivestats
    WHERE ano_mes = @mes_auditoria
) AS b
CROSS JOIN (
    SELECT
        SUM(CASE WHEN capacidade_bytes IS NULL THEN 1 ELSE 0 END) AS capacidade_nula,
        SUM(CASE WHEN temperatura_c IS NULL AND smart_194_temperatura_bruto IS NOT NULL THEN 1 ELSE 0 END) AS temperatura_anulada,
        SUM(CASE WHEN horas_ligado IS NULL AND smart_009_horas_ligado_bruto IS NOT NULL THEN 1 ELSE 0 END) AS horas_anuladas
    FROM silver.disco_dia
    WHERE ano_mes = @mes_auditoria
) AS s;

-- ============================================================================
-- Teste 4: Correlação de Manutenção Preditiva (SMART Preditores x Falhas)
-- ============================================================================
SELECT 
    '4. Eficácia SMART Preditivo' AS teste,
    falha,
    COUNT_BIG(*) AS total_dias_disco,
    SUM(flg_risco_falha_iminente) AS qtd_com_alerta_smart,
    ROUND(100.0 * SUM(flg_risco_falha_iminente) / COUNT_BIG(*), 2) AS pct_com_alerta_smart
FROM silver.disco_dia_enriquecida
WHERE ano_mes = @mes_auditoria
GROUP BY falha;
GO
