-- ============================================================================
-- 10_fato_confiabilidade_faixas.sql
--
-- Objetivo:
--   Fato de confiabilidade por faixas, grão mês × modelo × faixa de idade ×
--   faixa de temperatura do dia. Permite AFR por idade (pergunta 5) e por
--   temperatura (pergunta 2) com a regra correta: somar falhas e dias-disco
--   da faixa e recalcular. Acréscimo ao modelo da 1ª etapa.
--
-- Origem dos dados:
--   lake/gold/fato_confiabilidade_faixas/ → stg.fato_confiabilidade_faixas
--   (sql/dml/09_carga_fato_confiabilidade_faixas.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.fato_confiabilidade_faixas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fato_confiabilidade_faixas (
        id_data_mes           INT            NOT NULL,  -- 1º dia do mês (AAAAMM01)
        sk_modelo             INT            NOT NULL,
        id_faixa_idade        TINYINT        NOT NULL,
        id_faixa_temperatura  TINYINT        NOT NULL,
        dias_disco            BIGINT         NOT NULL,
        falhas                INT            NOT NULL,
        discos_distintos      INT            NOT NULL,  -- não aditivo entre meses e faixas
        soma_temperatura      BIGINT         NULL,
        contagem_temperatura  BIGINT         NOT NULL,
        soma_idade_anos       DECIMAL(18, 2) NULL,
        contagem_idade        BIGINT         NOT NULL,
        afr_pct               AS CAST(100.0 * falhas * 365 / NULLIF(dias_disco, 0) AS DECIMAL(9, 4)) PERSISTED,
        CONSTRAINT pk_fato_confiabilidade_faixas
            PRIMARY KEY (id_data_mes, sk_modelo, id_faixa_idade, id_faixa_temperatura),
        CONSTRAINT fk_fcf_calendario FOREIGN KEY (id_data_mes)
            REFERENCES dbo.dim_calendario (id_data),
        CONSTRAINT fk_fcf_modelo FOREIGN KEY (sk_modelo)
            REFERENCES dbo.dim_modelo (sk_modelo),
        CONSTRAINT fk_fcf_faixa_idade FOREIGN KEY (id_faixa_idade)
            REFERENCES dbo.dim_faixa_idade (id_faixa_idade),
        CONSTRAINT fk_fcf_faixa_temperatura FOREIGN KEY (id_faixa_temperatura)
            REFERENCES dbo.dim_faixa_temperatura (id_faixa_temperatura)
    );
    CREATE INDEX ix_fcf_modelo ON dbo.fato_confiabilidade_faixas (sk_modelo);
END;
GO
