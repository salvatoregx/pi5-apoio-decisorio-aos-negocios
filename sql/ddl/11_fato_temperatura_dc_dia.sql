-- ============================================================================
-- 11_fato_temperatura_dc_dia.sql
--
-- Objetivo:
--   Fato de temperatura, grão dia × datacenter efetivo × tipo de mídia.
--   Medidas aditivas: discos (dias-disco), discos_imputados, capacidade,
--   soma e contagem de temperatura, falhas. Não aditivas: p50, p95 e máximo
--   (valem só para o próprio dia).
--
-- Origem dos dados:
--   lake/gold/fato_temperatura_dc_dia/ → stg.fato_temperatura_dc_dia
--   (sql/dml/10_carga_fato_temperatura_dc_dia.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.fato_temperatura_dc_dia', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fato_temperatura_dc_dia (
        id_data               INT            NOT NULL,
        sk_datacenter         INT            NOT NULL,
        tipo_midia            VARCHAR(3)     NOT NULL,  -- dimensão degenerada: HDD / SSD
        discos                INT            NOT NULL,
        discos_imputados      INT            NOT NULL,
        capacidade_tb_total   DECIMAL(12, 1) NULL,
        soma_temperatura      BIGINT         NULL,
        contagem_temperatura  INT            NOT NULL,
        temperatura_p50       SMALLINT       NULL,
        temperatura_p95       SMALLINT       NULL,
        temperatura_max       SMALLINT       NULL,
        falhas                INT            NOT NULL,
        temperatura_media     AS CAST(1.0 * soma_temperatura / NULLIF(contagem_temperatura, 0) AS DECIMAL(5, 2)) PERSISTED,
        CONSTRAINT pk_fato_temperatura_dc_dia PRIMARY KEY (id_data, sk_datacenter, tipo_midia),
        CONSTRAINT fk_ftd_calendario FOREIGN KEY (id_data)
            REFERENCES dbo.dim_calendario (id_data),
        CONSTRAINT fk_ftd_datacenter FOREIGN KEY (sk_datacenter)
            REFERENCES dbo.dim_datacenter (sk_datacenter),
        CONSTRAINT ck_ftd_tipo_midia CHECK (tipo_midia IN ('HDD', 'SSD'))
    );
    CREATE INDEX ix_ftd_datacenter ON dbo.fato_temperatura_dc_dia (sk_datacenter);
END;
GO
