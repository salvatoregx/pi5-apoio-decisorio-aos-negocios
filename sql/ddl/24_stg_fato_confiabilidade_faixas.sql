-- ============================================================================
-- 24_stg_fato_confiabilidade_faixas.sql
--
-- Objetivo:
--   Tabela de staging stg.fato_confiabilidade_faixas: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (09_carga_fato_confiabilidade_faixas.sql).
--
-- Origem dos dados:
--   lake/gold/fato_confiabilidade_faixas/ano=*/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.fato_confiabilidade_faixas', 'U') IS NULL
BEGIN
    CREATE TABLE stg.fato_confiabilidade_faixas (
        ano_mes              CHAR(7) NULL,
        modelo               VARCHAR(100) COLLATE Latin1_General_100_CS_AS NULL,
        id_faixa_idade       INT NULL,
        id_faixa_temperatura INT NULL,
        dias_disco           BIGINT NULL,
        falhas               BIGINT NULL,
        discos_distintos     BIGINT NULL,
        soma_temperatura     BIGINT NULL,
        contagem_temperatura BIGINT NULL,
        soma_idade_anos      FLOAT NULL,
        contagem_idade       BIGINT NULL
    );
END;
GO
