-- ============================================================================
-- 08_view_fato_confiabilidade_faixas.sql
--
-- Objetivo:
--   Lógica da fato de confiabilidade por faixas, grão
--   mês × modelo × faixa de idade × faixa de temperatura do dia.
--   Responde às perguntas 2 (temperatura e idade influenciam falhas?) e
--   5 (como o AFR evolui com a idade): a fato mensal não tem idade nem
--   temperatura do dia, e média por disco esconderia a variação ao longo da vida.
--   Acréscimo ao modelo da 1ª etapa.
--
-- Origem:
--   silver.disco_dia_enriquecida (faixas de 5 °C e de idade, com colunas de ordem).
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Materializada por ano no script 09.
--
-- Regras:
--   - As faixas são identificadas pela coluna de ordem da silver; sem leitura
--     válida (temperatura ou idade NULL), a ordem vira 0 ('Não informada' /
--     'Desconhecida'), que existe nas dimensões de faixa do Azure SQL.
-- ============================================================================

CREATE OR ALTER VIEW gold.vw_fato_confiabilidade_faixas AS
SELECT
    s.ano_mes,
    s.modelo,
    COALESCE(s.ordem_faixa_idade, 0) AS id_faixa_idade,
    COALESCE(s.ordem_faixa_temperatura, 0) AS id_faixa_temperatura,
    COUNT_BIG(*) AS dias_disco,
    SUM(CAST(s.falha AS INT)) AS falhas,
    COUNT_BIG(DISTINCT s.numero_serie) AS discos_distintos,
    SUM(CAST(s.temperatura_c AS BIGINT)) AS soma_temperatura,
    COUNT_BIG(s.temperatura_c) AS contagem_temperatura,
    SUM(s.idade_anos) AS soma_idade_anos,
    COUNT_BIG(s.idade_anos) AS contagem_idade
FROM silver.disco_dia_enriquecida AS s
GROUP BY
    s.ano_mes,
    s.modelo,
    COALESCE(s.ordem_faixa_idade, 0),
    COALESCE(s.ordem_faixa_temperatura, 0);
GO

-- Teste barato (um mês):
-- SELECT id_faixa_temperatura, SUM(dias_disco) AS dias_disco, SUM(falhas) AS falhas
-- FROM gold.vw_fato_confiabilidade_faixas WHERE ano_mes = '2024-01'
-- GROUP BY id_faixa_temperatura ORDER BY id_faixa_temperatura;
