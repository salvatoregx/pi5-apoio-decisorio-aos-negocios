-- ============================================================================
-- 21_stg_modelo_fonte.sql
--
-- Objetivo:
--   Tabela de staging stg.modelo_fonte: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (06_carga_dim_modelo_fonte.sql).
--
-- Origem dos dados:
--   lake/gold/modelo_fonte/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.modelo_fonte', 'U') IS NULL
BEGIN
    CREATE TABLE stg.modelo_fonte (
        modelo      VARCHAR(100) COLLATE Latin1_General_100_CS_AS NULL,
        url         VARCHAR(500) NULL,
        titulo      NVARCHAR(300) NULL,
        tipo_fonte  VARCHAR(50) NULL,
        campos      NVARCHAR(500) NULL,
        acessado_em DATE NULL
    );
END;
GO
