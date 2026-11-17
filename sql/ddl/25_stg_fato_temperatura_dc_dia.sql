-- ============================================================================
-- 25_stg_fato_temperatura_dc_dia.sql
--
-- Objetivo:
--   Tabela de staging stg.fato_temperatura_dc_dia: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (10_carga_fato_temperatura_dc_dia.sql).
--
-- Origem dos dados:
--   lake/gold/fato_temperatura_dc_dia/ano=*/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.fato_temperatura_dc_dia', 'U') IS NULL
BEGIN
    CREATE TABLE stg.fato_temperatura_dc_dia (
        ano_mes              CHAR(7) NULL,
        data                 DATE NULL,
        datacenter           VARCHAR(20) NULL,
        tipo_midia           VARCHAR(3) NULL,
        discos               BIGINT NULL,
        discos_imputados     BIGINT NULL,
        capacidade_tb_total  FLOAT NULL,
        soma_temperatura     BIGINT NULL,
        contagem_temperatura BIGINT NULL,
        temperatura_p50      BIGINT NULL,
        temperatura_p95      BIGINT NULL,
        temperatura_max      BIGINT NULL,
        falhas               BIGINT NULL
    );
END;
GO
