-- ============================================================================
-- 04_qualidade_silver.sql
--
-- Objetivo:
--   Consulta de validação e indicadores de qualidade de dados da camada Silver,
--   medindo consistência, volumes, deduplicação e taxas de anomalias/nulos
--   para um determinado mês (ex: '2024-01').
--
-- Dica de custo no Synapse Serverless:
--   Sempre filtre por 'ano_mes' para limitar a leitura do OPENROWSET apenas
--   à pasta de partição correspondente no data lake.
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
-- ============================================================================

-- Indicadores de qualidade para um mês específico (exemplo: '2024-01')
DECLARE @mes_analise VARCHAR(7) = '2024-01';

SELECT
    ano_mes,
    COUNT_BIG(*) AS total_linhas_silver,
    COUNT_BIG(DISTINCT numero_serie) AS discos_distintos,
    
    -- Falhas observadas
    SUM(CAST(falha AS BIGINT)) AS total_falhas,

    -- Indicadores de qualidade
    -- Ausente = o disco não reportou o atributo; inválida = reportou um valor fora da faixa
    -- aceita e a silver o anulou. A diferença ajuda a explicar a qualidade da fonte.
    SUM(CASE WHEN capacidade_bytes IS NULL THEN 1 ELSE 0 END) AS qtd_capacidade_invalida_ou_nula,
    SUM(CASE WHEN smart_194_temperatura_bruto IS NULL THEN 1 ELSE 0 END) AS qtd_temperatura_ausente,
    SUM(CASE WHEN temperatura_c IS NULL AND smart_194_temperatura_bruto IS NOT NULL THEN 1 ELSE 0 END) AS qtd_temperatura_invalida,
    SUM(CASE WHEN smart_009_horas_ligado_bruto IS NULL THEN 1 ELSE 0 END) AS qtd_horas_ligado_ausente,
    SUM(CASE WHEN horas_ligado IS NULL AND smart_009_horas_ligado_bruto IS NOT NULL THEN 1 ELSE 0 END) AS qtd_horas_ligado_invalida,
    SUM(CASE WHEN datacenter IS NULL THEN 1 ELSE 0 END) AS qtd_sem_datacenter,
    SUM(CASE WHEN fabricante = 'Outro/Desconhecido' THEN 1 ELSE 0 END) AS qtd_fabricante_desconhecido,

    -- Distribuição por tipo de mídia e função
    SUM(CASE WHEN tipo_midia = 'SSD' THEN 1 ELSE 0 END) AS qtd_ssd,
    SUM(CASE WHEN tipo_midia = 'HDD' THEN 1 ELSE 0 END) AS qtd_hdd,
    SUM(CASE WHEN funcao_disco = 'boot' THEN 1 ELSE 0 END) AS qtd_boot,
    SUM(CASE WHEN funcao_disco = 'dados' THEN 1 ELSE 0 END) AS qtd_dados

FROM silver.disco_dia
WHERE ano_mes = @mes_analise
GROUP BY ano_mes;
GO
