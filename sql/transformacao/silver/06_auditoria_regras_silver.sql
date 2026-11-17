-- ============================================================================
-- 06_auditoria_regras_silver.sql
--
-- Objetivo:
--   Bateria de testes e auditoria de qualidade que valida a integridade das regras
--   de transformação da camada Silver em relação à Bronze:
--   1. Conferência volumétrica (Bronze vs Silver) e garantia de deduplicação;
--   2. Verificação de fabricantes não mapeados ('Outro/Desconhecido');
--   3. Validação dos limites de saneamento (capacidades <= 0, temperaturas fora de 1-100, etc.);
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
-- Teste 3: Auditoria dos limites de saneamento (deve retornar 0 para todas as anomalias)
-- ============================================================================
SELECT 
    '3. Integridade do Saneamento' AS teste,
    SUM(CASE WHEN capacidade_bytes <= 0 THEN 1 ELSE 0 END) AS violacoes_capacidade_negativa_ou_zero,
    SUM(CASE WHEN temperatura_c NOT BETWEEN 1 AND 100 THEN 1 ELSE 0 END) AS violacoes_temperatura_fora_faixa,
    SUM(CASE WHEN horas_ligado NOT BETWEEN 0 AND 200000 THEN 1 ELSE 0 END) AS violacoes_horas_fora_faixa,
    SUM(CASE WHEN tipo_midia NOT IN ('SSD', 'HDD') THEN 1 ELSE 0 END) AS violacoes_midia_invalida,
    SUM(CASE WHEN funcao_disco NOT IN ('boot', 'dados') THEN 1 ELSE 0 END) AS violacoes_funcao_invalida
FROM silver.disco_dia
WHERE ano_mes = @mes_auditoria;

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
