-- ============================================================================
-- 20_stg_modelo.sql
--
-- Objetivo:
--   Tabela de staging stg.modelo: recebe a gold sem transformação, pela
--   atividade Copy do Synapse Pipelines. Os nomes das colunas são os mesmos do
--   Parquet, para o mapeamento automático por nome. Tudo aceita NULL: as
--   regras de qualidade ficam na carga para o dbo (05_carga_dim_modelo.sql).
--
-- Origem dos dados:
--   lake/gold/modelo/ (Parquet gravado pela CETAS no Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('stg.modelo', 'U') IS NULL
BEGIN
    CREATE TABLE stg.modelo (
        modelo                     VARCHAR(100) COLLATE Latin1_General_100_CS_AS NULL,
        fabricante                 NVARCHAR(50) NULL,
        tipo_midia                 VARCHAR(3) NULL,
        funcao_disco               VARCHAR(5) NULL,
        capacidade_tb              FLOAT NULL,
        primeira_data              DATE NULL,
        ultima_data                DATE NULL,
        dias_disco                 BIGINT NULL,
        discos_distintos           BIGINT NULL,
        falhas                     BIGINT NULL,
        no_catalogo                INT NULL,
        familia_produto            NVARCHAR(100) NULL,
        tecnologia_gravacao        NVARCHAR(100) NULL,
        preenchimento              NVARCHAR(20) NULL,
        formato                    NVARCHAR(20) NULL,
        rpm                        INT NULL,
        interface                  NVARCHAR(50) NULL,
        cache_mb                   INT NULL,
        potencia_ociosa_w          DECIMAL(6, 2) NULL,
        potencia_operacao_w        DECIMAL(6, 2) NULL,
        criterio_potencia_operacao NVARCHAR(100) NULL,
        temp_operacao_min_c        DECIMAL(5, 1) NULL,
        temp_operacao_max_c        DECIMAL(5, 1) NULL,
        mtbf_horas                 INT NULL,
        afr_declarado_pct          DECIMAL(6, 3) NULL,
        carga_trabalho_tb_ano      DECIMAL(8, 1) NULL,
        garantia_anos              INT NULL,
        observacoes                NVARCHAR(1000) NULL
    );
END;
GO
