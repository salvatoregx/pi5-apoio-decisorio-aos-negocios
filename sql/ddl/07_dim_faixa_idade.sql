-- ============================================================================
-- 07_dim_faixa_idade.sql
--
-- Objetivo:
--   Faixas de idade do disco (anos de operação pelo SMART 9), as mesmas da
--   silver enriquecida. id_faixa_idade = coluna ordem_faixa_idade da silver;
--   0 = idade desconhecida.
--
-- Origem dos dados:
--   Regras de sql/transformacao/silver/05_view_silver_disco_dia_enriquecida.sql
--   (sql/dml/03_carga_dim_faixa_idade.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.dim_faixa_idade', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_faixa_idade (
        id_faixa_idade  TINYINT      NOT NULL,
        descricao       NVARCHAR(20) NOT NULL,
        anos_min        DECIMAL(4, 1) NULL,  -- inclusivo
        anos_max        DECIMAL(4, 1) NULL,  -- exclusivo
        CONSTRAINT pk_dim_faixa_idade PRIMARY KEY (id_faixa_idade)
    );
END;
GO
