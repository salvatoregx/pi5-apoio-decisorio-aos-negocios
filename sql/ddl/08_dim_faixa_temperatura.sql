-- ============================================================================
-- 08_dim_faixa_temperatura.sql
--
-- Objetivo:
--   Faixas de temperatura de 5 °C, as mesmas da silver enriquecida.
--   id_faixa_temperatura = coluna ordem_faixa_temperatura da silver;
--   0 = temperatura não informada.
--
-- Origem dos dados:
--   Regras de sql/transformacao/silver/05_view_silver_disco_dia_enriquecida.sql
--   (sql/dml/04_carga_dim_faixa_temperatura.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.dim_faixa_temperatura', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_faixa_temperatura (
        id_faixa_temperatura TINYINT      NOT NULL,
        descricao            NVARCHAR(20) NOT NULL,
        temperatura_min_c    SMALLINT     NULL,  -- inclusivo
        temperatura_max_c    SMALLINT     NULL,  -- exclusivo
        estresse_termico     BIT          NOT NULL,  -- faixa a partir de 40 °C
        CONSTRAINT pk_dim_faixa_temperatura PRIMARY KEY (id_faixa_temperatura)
    );
END;
GO
