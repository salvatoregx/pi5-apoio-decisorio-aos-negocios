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
    -- Faixas de temperatura (intervalos de 5 °C). Os rótulos são neutros: qual faixa tem
    -- mais falhas é uma conclusão da análise OLAP, não da limpeza. A coluna de ordem
    -- permite ordenar as faixas nas consultas (o texto não ordena corretamente).
    CASE 
        WHEN s.temperatura_c IS NULL THEN 'Não informada'
        WHEN s.temperatura_c < 20 THEN '< 20 °C'
        WHEN s.temperatura_c < 25 THEN '20 a 24 °C'
        WHEN s.temperatura_c < 30 THEN '25 a 29 °C'
        WHEN s.temperatura_c < 35 THEN '30 a 34 °C'
        WHEN s.temperatura_c < 40 THEN '35 a 39 °C'
        WHEN s.temperatura_c < 45 THEN '40 a 44 °C'
        ELSE '>= 45 °C'
    END AS faixa_temperatura,
    CASE 
        WHEN s.temperatura_c IS NULL THEN NULL
        WHEN s.temperatura_c < 20 THEN 1
        WHEN s.temperatura_c < 25 THEN 2
        WHEN s.temperatura_c < 30 THEN 3
        WHEN s.temperatura_c < 35 THEN 4
        WHEN s.temperatura_c < 40 THEN 5
        WHEN s.temperatura_c < 45 THEN 6
        ELSE 7
    END AS ordem_faixa_temperatura,

    -- Temperatura a partir de 40 °C. Limiar de análise: a exploração da 1ª etapa
    -- (2 meses) mostrou AFR acima da média a partir de 40 °C e bem maior a partir de 45 °C.
    CASE WHEN s.temperatura_c >= 40 THEN 1 ELSE 0 END AS flg_estresse_termico,

    -- Faixas de idade de uso (anos de operação, a partir do SMART 9)
    CASE 
        WHEN s.idade_anos IS NULL THEN 'Desconhecida'
        WHEN s.idade_anos < 1 THEN '< 1 ano'
        WHEN s.idade_anos < 3 THEN '1 a 2 anos'
        WHEN s.idade_anos < 5 THEN '3 a 4 anos'
        WHEN s.idade_anos < 7 THEN '5 a 6 anos'
        ELSE '>= 7 anos'
    END AS faixa_idade,
    CASE 
        WHEN s.idade_anos IS NULL THEN NULL
        WHEN s.idade_anos < 1 THEN 1
        WHEN s.idade_anos < 3 THEN 2
        WHEN s.idade_anos < 5 THEN 3
        WHEN s.idade_anos < 7 THEN 4
        ELSE 5
    END AS ordem_faixa_idade,

    -- Registro sem datacenter (a localização só existe a partir de 2023; a imputação pelo
    -- último datacenter conhecido do disco fica para a gold)
    CASE WHEN s.datacenter IS NULL THEN 1 ELSE 0 END AS flg_sem_localizacao_original

FROM silver.disco_dia AS s;
GO
