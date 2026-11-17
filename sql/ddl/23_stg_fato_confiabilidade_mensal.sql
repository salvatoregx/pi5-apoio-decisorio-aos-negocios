-- ============================================================================
-- 23_stg_fato_confiabilidade_mensal.sql
--
-- Objetivo:
--   Tabela de staging stg.fato_confiabilidade_mensal: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (08_carga_fato_confiabilidade_mensal.sql).
--
-- Origem dos dados:
--   lake/gold/fato_confiabilidade_mensal/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.fato_confiabilidade_mensal', 'U') IS NULL
BEGIN
    CREATE TABLE stg.fato_confiabilidade_mensal (
        ano_mes              CHAR(7) NULL,
        modelo               VARCHAR(100) COLLATE Latin1_General_100_CS_AS NULL,
        datacenter           VARCHAR(20) NULL,
        dias_disco           BIGINT NULL,
        dias_disco_imputados BIGINT NULL,
        falhas               BIGINT NULL,
        discos_distintos     BIGINT NULL,
        tb_dias              FLOAT NULL,
        soma_temperatura     BIGINT NULL,
        contagem_temperatura BIGINT NULL,
        afr_pct              FLOAT NULL
    );
END;
GO
