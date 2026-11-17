-- ============================================================================
-- 22_stg_disco.sql
--
-- Objetivo:
--   Tabela de staging stg.disco: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (07_carga_dim_disco.sql).
--
-- Origem dos dados:
--   lake/gold/disco/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.disco', 'U') IS NULL
BEGIN
    CREATE TABLE stg.disco (
        numero_serie       VARCHAR(50) COLLATE Latin1_General_100_CS_AS NULL,
        modelo             VARCHAR(100) COLLATE Latin1_General_100_CS_AS NULL,
        primeira_data      DATE NULL,
        ultima_data        DATE NULL,
        dias_observados    BIGINT NULL,
        falhou             INT NULL,
        data_falha         DATE NULL,
        ultimo_datacenter  VARCHAR(20) NULL,
        horas_inicial      INT NULL,
        horas_final        INT NULL,
        temperatura_media  FLOAT NULL,
        temperatura_max    BIGINT NULL,
        max_smart_005      BIGINT NULL,
        max_smart_187      BIGINT NULL,
        max_smart_188      BIGINT NULL,
        max_smart_197      BIGINT NULL,
        max_smart_198      BIGINT NULL,
        situacao           VARCHAR(10) NULL,
        censurado_esquerda INT NULL
    );
END;
GO
