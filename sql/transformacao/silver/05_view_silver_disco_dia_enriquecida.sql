-- ============================================================================
-- 05_view_silver_disco_dia_enriquecida.sql
--
-- Objetivo:
--   View enriquecida da camada Silver (silver.disco_dia_enriquecida).
--   Adiciona flags de saúde de manutenção preditiva (atributos SMART críticos),
--   sinalizadores de anomalias operacionais (temperatura excessiva, idade crítica)
--   e faixas categorizadas para facilitar agregações e análises OLAP.
--
-- Origem:
--   silver.disco_dia
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
-- ============================================================================

CREATE OR ALTER VIEW silver.disco_dia_enriquecida AS
SELECT
    s.*,

    -- ========================================================================
    -- Indicadores de Manutenção Preditiva (SMART Preditores Backblaze)
    -- ========================================================================
    -- SMART 5: Setores Realocados > 0 indica degradação da mídia magnética
    CASE WHEN s.smart_005_setores_realocados_bruto > 0 THEN 1 ELSE 0 END AS flg_smart_005_alerta,

    -- SMART 187: Erros Incorrigíveis Reportados > 0
    CASE WHEN s.smart_187_erros_incorrigiveis_reportados_bruto > 0 THEN 1 ELSE 0 END AS flg_smart_187_alerta,

    -- SMART 188: Timeouts de Comando > 0
    CASE WHEN s.smart_188_timeouts_comando_bruto > 0 THEN 1 ELSE 0 END AS flg_smart_188_alerta,

    -- SMART 197: Setores Pendentes > 0 (setores instáveis aguardando remapeamento)
    CASE WHEN s.smart_197_setores_pendentes_bruto > 0 THEN 1 ELSE 0 END AS flg_smart_197_alerta,

    -- SMART 198: Setores Incorrigíveis Offline > 0
    CASE WHEN s.smart_198_setores_incorrigiveis_offline_bruto > 0 THEN 1 ELSE 0 END AS flg_smart_198_alerta,

    -- Sinalizador composto: se qualquer um dos 5 atributos preditores estiver alterado
    CASE 
        WHEN s.smart_005_setores_realocados_bruto > 0
          OR s.smart_187_erros_incorrigiveis_reportados_bruto > 0
          OR s.smart_188_timeouts_comando_bruto > 0
          OR s.smart_197_setores_pendentes_bruto > 0
          OR s.smart_198_setores_incorrigiveis_offline_bruto > 0
        THEN 1 
        ELSE 0 
    END AS flg_risco_falha_iminente,

    -- ========================================================================
    -- Faixas Operacionais para Análise Dimensional / OLAP
    -- ========================================================================
    -- Faixas de temperatura operacional (intervalos de 5 °C)
    CASE 
        WHEN s.temperatura_c IS NULL THEN 'Não informada'
        WHEN s.temperatura_c < 20 THEN '< 20°C (Baixa)'
        WHEN s.temperatura_c BETWEEN 20 AND 24 THEN '20 a 24°C'
        WHEN s.temperatura_c BETWEEN 25 AND 29 THEN '25 a 29°C (Ideal)'
        WHEN s.temperatura_c BETWEEN 30 AND 34 THEN '30 a 34°C'
        WHEN s.temperatura_c BETWEEN 35 AND 39 THEN '35 a 39°C (Elevada)'
        WHEN s.temperatura_c BETWEEN 40 AND 44 THEN '40 a 44°C (Crítica)'
        ELSE '>= 45°C (Perigo)'
    END AS faixa_temperatura,

    -- Alerta de estresse térmico (acima de 40 °C é crítico em datacenter)
    CASE WHEN s.temperatura_c >= 40 THEN 1 ELSE 0 END AS flg_estresse_termico,

    -- Faixas de idade de uso (anos de operação)
    CASE 
        WHEN s.idade_anos IS NULL THEN 'Desconhecida'
        WHEN s.idade_anos < 1.0 THEN '< 1 ano (Novo)'
        WHEN s.idade_anos BETWEEN 1.0 AND 2.99 THEN '1 a 2 anos'
        WHEN s.idade_anos BETWEEN 3.0 AND 4.99 THEN '3 a 4 anos (Maturo)'
        WHEN s.idade_anos BETWEEN 5.0 AND 6.99 THEN '5 a 6 anos (Fim de ciclo)'
        ELSE '>= 7 anos (Crítico)'
    END AS faixa_idade,

    -- Indicador de localização imputada vs observada
    CASE WHEN s.datacenter IS NULL THEN 1 ELSE 0 END AS flg_sem_localizacao_original

FROM silver.disco_dia AS s;
GO
