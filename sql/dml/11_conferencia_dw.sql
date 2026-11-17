-- ============================================================================
-- 11_conferencia_dw.sql
--
-- Objetivo:
--   Conferir a carga do DW: staging × tabelas finais, consistência entre as
--   fatos e uma consulta de fumaça com o AFR por fabricante e ano. Só leitura.
--
-- Origem dos dados:
--   Schemas stg e dbo do banco dw.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw', depois das cargas 01 a 10.
--
-- Resultado esperado:
--   - Consulta 1: diferenca = 0 em todas as linhas.
--   - Consulta 2: dias_disco e falhas iguais nas três fatos e em dim_disco
--     (falhas de dim_disco conta discos que falharam; pode ficar um pouco abaixo
--     se algum disco tiver mais de uma falha registrada).
--   - Os totais devem bater com sql/transformacao/gold/90_conferencia_gold.sql.
-- ============================================================================

-- 1. Linhas na staging × linhas na tabela final
SELECT 'dim_modelo' AS tabela,
       (SELECT COUNT(*) FROM stg.modelo) AS linhas_stg,
       (SELECT COUNT(*) FROM dbo.dim_modelo) AS linhas_dw,
       (SELECT COUNT(*) FROM stg.modelo) - (SELECT COUNT(*) FROM dbo.dim_modelo) AS diferenca
UNION ALL
SELECT 'dim_disco',
       (SELECT COUNT(*) FROM stg.disco),
       (SELECT COUNT(*) FROM dbo.dim_disco),
       (SELECT COUNT(*) FROM stg.disco) - (SELECT COUNT(*) FROM dbo.dim_disco)
UNION ALL
SELECT 'fato_confiabilidade_mensal',
       (SELECT COUNT(*) FROM stg.fato_confiabilidade_mensal),
       (SELECT COUNT(*) FROM dbo.fato_confiabilidade_mensal),
       (SELECT COUNT(*) FROM stg.fato_confiabilidade_mensal) - (SELECT COUNT(*) FROM dbo.fato_confiabilidade_mensal)
UNION ALL
SELECT 'fato_confiabilidade_faixas',
       (SELECT COUNT(*) FROM stg.fato_confiabilidade_faixas),
       (SELECT COUNT(*) FROM dbo.fato_confiabilidade_faixas),
       (SELECT COUNT(*) FROM stg.fato_confiabilidade_faixas) - (SELECT COUNT(*) FROM dbo.fato_confiabilidade_faixas)
UNION ALL
SELECT 'fato_temperatura_dc_dia',
       (SELECT COUNT(*) FROM stg.fato_temperatura_dc_dia),
       (SELECT COUNT(*) FROM dbo.fato_temperatura_dc_dia),
       (SELECT COUNT(*) FROM stg.fato_temperatura_dc_dia) - (SELECT COUNT(*) FROM dbo.fato_temperatura_dc_dia);

-- 2. Dias-disco e falhas: as fatos precisam contar a mesma coisa
SELECT 'fato_confiabilidade_mensal' AS tabela, SUM(dias_disco) AS dias_disco, SUM(CAST(falhas AS BIGINT)) AS falhas
FROM dbo.fato_confiabilidade_mensal
UNION ALL
SELECT 'fato_confiabilidade_faixas', SUM(dias_disco), SUM(CAST(falhas AS BIGINT))
FROM dbo.fato_confiabilidade_faixas
UNION ALL
SELECT 'fato_temperatura_dc_dia', SUM(CAST(discos AS BIGINT)), SUM(CAST(falhas AS BIGINT))
FROM dbo.fato_temperatura_dc_dia
UNION ALL
SELECT 'dim_disco', SUM(CAST(dias_observados AS BIGINT)), SUM(CAST(falhou AS BIGINT))
FROM dbo.dim_disco;

-- 3. Fumaça: AFR por fabricante e ano (somando falhas e dias-disco, nunca média de AFR)
SELECT
    m.fabricante,
    c.ano,
    SUM(f.dias_disco) AS dias_disco,
    SUM(f.falhas) AS falhas,
    CAST(100.0 * SUM(f.falhas) * 365 / SUM(f.dias_disco) AS DECIMAL(9, 2)) AS afr_pct
FROM dbo.fato_confiabilidade_mensal AS f
JOIN dbo.dim_modelo AS m ON m.sk_modelo = f.sk_modelo
JOIN dbo.dim_calendario AS c ON c.id_data = f.id_data_mes
WHERE m.funcao_disco = 'dados'
GROUP BY m.fabricante, c.ano
ORDER BY m.fabricante, c.ano;
