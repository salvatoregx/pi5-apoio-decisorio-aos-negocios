-- ============================================================================
-- 05_dim_modelo_fonte.sql
--
-- Objetivo:
--   Fontes das especificações de cada modelo (relação 1:n com dim_modelo):
--   datasheets, manuais e páginas consultadas, com os campos que cada uma sustenta.
--
-- Origem dos dados:
--   config/catalogo_fabricantes_fontes.csv → lake/gold/modelo_fonte/ → stg.modelo_fonte
--   (sql/dml/06_carga_dim_modelo_fonte.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.dim_modelo_fonte', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_modelo_fonte (
        sk_modelo_fonte INT IDENTITY(1, 1) NOT NULL,
        sk_modelo       INT           NOT NULL,
        url             VARCHAR(500)  NOT NULL,
        titulo          NVARCHAR(300) NULL,
        tipo_fonte      VARCHAR(50)   NULL,  -- datasheet_fabricante, manual_fabricante, ...
        campos          NVARCHAR(500) NULL,  -- campos do catálogo sustentados pela fonte
        acessado_em     DATE          NULL,
        CONSTRAINT pk_dim_modelo_fonte PRIMARY KEY (sk_modelo_fonte),
        CONSTRAINT uq_dim_modelo_fonte UNIQUE (sk_modelo, url),
        CONSTRAINT fk_dim_modelo_fonte_modelo FOREIGN KEY (sk_modelo)
            REFERENCES dbo.dim_modelo (sk_modelo)
    );
END;
GO
