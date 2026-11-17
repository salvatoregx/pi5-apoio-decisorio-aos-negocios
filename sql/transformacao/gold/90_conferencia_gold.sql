-- ============================================================================
-- 90_conferencia_gold.sql
--
-- Objetivo:
--   Conferir se as tabelas da gold são consistentes entre si e com a bronze.
--   Material para o README, o vídeo e a revisão final (checklist do guia).
--
-- Origem:
--   bronze.drivestats e tabelas/views da gold (scripts 03 a 11).
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--   Custo baixo: na bronze lê só a coluna failure (centavos); as demais
--   consultas leem a gold, que é pequena.
--
-- Resultado esperado:
--   - dias_disco igual em todas as linhas de "dias-disco por tabela".
--   - linhas_bronze - dias_disco = duplicatas removidas na silver (esperado 0
--     ou muito pouco).
--   - falhas iguais em todas as tabelas.
-- ============================================================================

-- 1. Dias-disco e falhas por tabela da gold, ao lado da bronze
SELECT 'bronze.drivestats' AS tabela,
       COUNT_BIG(*) AS dias_disco,
       SUM(CAST(failure AS BIGINT)) AS falhas
FROM bronze.drivestats
UNION ALL
SELECT 'gold.disco_mes', SUM(dias_disco), SUM(CAST(falhas AS BIGINT)) FROM gold.disco_mes
UNION ALL
SELECT 'gold.disco', SUM(dias_observados), SUM(CAST(falhou AS BIGINT)) FROM gold.disco
UNION ALL
SELECT 'gold.modelo', SUM(dias_disco), SUM(CAST(falhas AS BIGINT)) FROM gold.modelo
UNION ALL
SELECT 'gold.fato_confiabilidade_mensal', SUM(dias_disco), SUM(CAST(falhas AS BIGINT)) FROM gold.fato_confiabilidade_mensal
UNION ALL
SELECT 'gold.fato_confiabilidade_faixas', SUM(dias_disco), SUM(CAST(falhas AS BIGINT)) FROM gold.fato_confiabilidade_faixas
UNION ALL
SELECT 'gold.fato_temperatura_dc_dia', SUM(discos), SUM(CAST(falhas AS BIGINT)) FROM gold.fato_temperatura_dc_dia;
-- Observação: em gold.disco a coluna é falhou (0/1 por disco). Se algum disco tiver
-- mais de uma falha registrada, esse total fica menor que o das outras tabelas.

-- 2. Dias-disco por mês: bronze x fato mensal (mostra em que mês há diferença)
SELECT b.ano_mes, b.linhas_bronze, f.dias_disco, b.linhas_bronze - f.dias_disco AS diferenca
FROM (
    SELECT ano_mes, COUNT_BIG(*) AS linhas_bronze
    FROM bronze.drivestats
    GROUP BY ano_mes
) AS b
LEFT JOIN (
    SELECT ano_mes, SUM(dias_disco) AS dias_disco
    FROM gold.fato_confiabilidade_mensal
    GROUP BY ano_mes
) AS f
    ON f.ano_mes = b.ano_mes
ORDER BY b.ano_mes;

-- 3. Tamanho da gold (linhas por tabela) e imputação de datacenter
SELECT 'gold.disco' AS tabela, COUNT_BIG(*) AS linhas FROM gold.disco
UNION ALL SELECT 'gold.modelo', COUNT_BIG(*) FROM gold.modelo
UNION ALL SELECT 'gold.modelo_fonte', COUNT_BIG(*) FROM gold.modelo_fonte
UNION ALL SELECT 'gold.fato_confiabilidade_mensal', COUNT_BIG(*) FROM gold.fato_confiabilidade_mensal
UNION ALL SELECT 'gold.fato_confiabilidade_faixas', COUNT_BIG(*) FROM gold.fato_confiabilidade_faixas
UNION ALL SELECT 'gold.fato_temperatura_dc_dia', COUNT_BIG(*) FROM gold.fato_temperatura_dc_dia;

SELECT
    LEFT(ano_mes, 4) AS ano,
    SUM(dias_disco) AS dias_disco,
    SUM(dias_disco_imputados) AS dias_disco_imputados,
    SUM(CASE WHEN datacenter = 'desconhecido' THEN dias_disco ELSE 0 END) AS dias_disco_sem_local,
    ROUND(100.0 * SUM(dias_disco_imputados) / SUM(dias_disco), 2) AS pct_imputado
FROM gold.fato_confiabilidade_mensal
GROUP BY LEFT(ano_mes, 4)
ORDER BY ano;
