-- ============================================================================
-- 09_fato_confiabilidade_mensal.sql
--
-- Objetivo:
--   Fato de confiabilidade, grão mês × modelo × datacenter efetivo.
--   Medidas aditivas: dias_disco, dias_disco_imputados, falhas, tb_dias,
--   soma e contagem de temperatura. Não aditivas: discos_distintos (entre
--   meses) e afr_pct (coluna calculada; ao reagregar, recalcular com as somas).
--
-- Origem dos dados:
--   lake/gold/fato_confiabilidade_mensal/ → stg.fato_confiabilidade_mensal
--   (sql/dml/08_carga_fato_confiabilidade_mensal.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
--
-- Fórmula (Backblaze): AFR % = 100 × falhas / (dias_disco / 365).
-- ============================================================================

IF OBJECT_ID('dbo.fato_confiabilidade_mensal', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fato_confiabilidade_mensal (
        id_data_mes           INT            NOT NULL,  -- 1º dia do mês (AAAAMM01)
        sk_modelo             INT            NOT NULL,
        sk_datacenter         INT            NOT NULL,
        dias_disco            BIGINT         NOT NULL,
        dias_disco_imputados  BIGINT         NOT NULL,
        falhas                INT            NOT NULL,
        discos_distintos      INT            NOT NULL,
        tb_dias               DECIMAL(18, 1) NULL,
        soma_temperatura      BIGINT         NULL,
        contagem_temperatura  BIGINT         NOT NULL,
        afr_pct               AS CAST(100.0 * falhas * 365 / NULLIF(dias_disco, 0) AS DECIMAL(9, 4)) PERSISTED,
        temperatura_media     AS CAST(1.0 * soma_temperatura / NULLIF(contagem_temperatura, 0) AS DECIMAL(5, 2)) PERSISTED,
        CONSTRAINT pk_fato_confiabilidade_mensal PRIMARY KEY (id_data_mes, sk_modelo, sk_datacenter),
        CONSTRAINT fk_fcm_calendario FOREIGN KEY (id_data_mes)
            REFERENCES dbo.dim_calendario (id_data),
        CONSTRAINT fk_fcm_modelo FOREIGN KEY (sk_modelo)
            REFERENCES dbo.dim_modelo (sk_modelo),
        CONSTRAINT fk_fcm_datacenter FOREIGN KEY (sk_datacenter)
            REFERENCES dbo.dim_datacenter (sk_datacenter),
        CONSTRAINT ck_fcm_imputados CHECK (dias_disco_imputados <= dias_disco)
    );
    CREATE INDEX ix_fcm_modelo ON dbo.fato_confiabilidade_mensal (sk_modelo);
    CREATE INDEX ix_fcm_datacenter ON dbo.fato_confiabilidade_mensal (sk_datacenter);
END;
GO
