-- ============================================================================
-- 03_carga_dim_faixa_idade.sql
--
-- Objetivo:
--   Carregar as faixas de idade. Rótulos e limites idênticos aos da view
--   silver.disco_dia_enriquecida (faixa_idade / ordem_faixa_idade).
--
-- Origem dos dados:
--   sql/transformacao/silver/05_view_silver_disco_dia_enriquecida.sql.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisito: sql/ddl/07_dim_faixa_idade.sql.
--   Idempotente: MERGE pela chave id_faixa_idade.
-- ============================================================================

MERGE dbo.dim_faixa_idade AS alvo
USING (VALUES
    (0, N'Desconhecida', NULL, NULL),
    (1, N'< 1 ano',      0.0,  1.0),
    (2, N'1 a 2 anos',   1.0,  3.0),
    (3, N'3 a 4 anos',   3.0,  5.0),
    (4, N'5 a 6 anos',   5.0,  7.0),
    (5, N'>= 7 anos',    7.0,  NULL)
) AS origem (id_faixa_idade, descricao, anos_min, anos_max)
    ON alvo.id_faixa_idade = origem.id_faixa_idade
WHEN MATCHED THEN UPDATE SET
    alvo.descricao = origem.descricao,
    alvo.anos_min = origem.anos_min,
    alvo.anos_max = origem.anos_max
WHEN NOT MATCHED BY TARGET THEN INSERT (id_faixa_idade, descricao, anos_min, anos_max)
    VALUES (origem.id_faixa_idade, origem.descricao, origem.anos_min, origem.anos_max);
GO
