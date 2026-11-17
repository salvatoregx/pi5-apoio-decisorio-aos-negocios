-- ============================================================================
-- 04_carga_dim_faixa_temperatura.sql
--
-- Objetivo:
--   Carregar as faixas de temperatura (5 °C). Rótulos e limites idênticos aos da
--   view silver.disco_dia_enriquecida (faixa_temperatura / ordem_faixa_temperatura);
--   estresse_termico = 1 a partir de 40 °C, como flg_estresse_termico da silver.
--
-- Origem dos dados:
--   sql/transformacao/silver/05_view_silver_disco_dia_enriquecida.sql.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisito: sql/ddl/08_dim_faixa_temperatura.sql.
--   Idempotente: MERGE pela chave id_faixa_temperatura.
-- ============================================================================

MERGE dbo.dim_faixa_temperatura AS alvo
USING (VALUES
    (0, N'Não informada', NULL, NULL, 0),
    (1, N'< 20 °C',       NULL, 20,   0),
    (2, N'20 a 24 °C',    20,   25,   0),
    (3, N'25 a 29 °C',    25,   30,   0),
    (4, N'30 a 34 °C',    30,   35,   0),
    (5, N'35 a 39 °C',    35,   40,   0),
    (6, N'40 a 44 °C',    40,   45,   1),
    (7, N'>= 45 °C',      45,   NULL, 1)
) AS origem (id_faixa_temperatura, descricao, temperatura_min_c, temperatura_max_c, estresse_termico)
    ON alvo.id_faixa_temperatura = origem.id_faixa_temperatura
WHEN MATCHED THEN UPDATE SET
    alvo.descricao = origem.descricao,
    alvo.temperatura_min_c = origem.temperatura_min_c,
    alvo.temperatura_max_c = origem.temperatura_max_c,
    alvo.estresse_termico = origem.estresse_termico
WHEN NOT MATCHED BY TARGET THEN INSERT (
    id_faixa_temperatura, descricao, temperatura_min_c, temperatura_max_c, estresse_termico
) VALUES (
    origem.id_faixa_temperatura, origem.descricao, origem.temperatura_min_c,
    origem.temperatura_max_c, origem.estresse_termico
);
GO
