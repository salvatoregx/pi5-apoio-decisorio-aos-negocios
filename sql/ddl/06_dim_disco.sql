-- ============================================================================
-- 06_dim_disco.sql
--
-- Objetivo:
--   Dimensão de disco (número de série): ciclo de vida observado na janela,
--   último datacenter conhecido, idade, temperatura e máximos dos atributos
--   SMART preditores de falha. Responde à pergunta 3 (manutenção preditiva).
--
-- Origem dos dados:
--   lake/gold/disco/ → stg.disco (sql/dml/07_carga_dim_disco.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
--
-- Collation de numero_serie: sensível a maiúsculas (CS), como no lake. Com a collation
--   padrão do banco (CI), dois valores que só diferem na caixa violariam o UNIQUE.
--
-- Observações:
--   - sk_datacenter_ultimo aponta para 'desconhecido' quando o disco nunca
--     teve localização registrada.
--   - censurado_esquerda = 1: o disco já operava no início da janela (2021-07-01).
-- ============================================================================

IF OBJECT_ID('dbo.dim_disco', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_disco (
        sk_disco              INT IDENTITY(1, 1) NOT NULL,
        numero_serie          VARCHAR(50) COLLATE Latin1_General_100_CS_AS   NOT NULL,
        sk_modelo             INT           NOT NULL,
        sk_datacenter_ultimo  INT           NOT NULL,
        primeira_data         DATE          NOT NULL,
        ultima_data           DATE          NOT NULL,
        dias_observados       INT           NOT NULL,
        falhou                BIT           NOT NULL,
        data_falha            DATE          NULL,
        situacao              VARCHAR(10)   NOT NULL,  -- ativo / falhou / retirado
        censurado_esquerda    BIT           NOT NULL,
        horas_inicial         INT           NULL,
        horas_final           INT           NULL,
        idade_inicial_anos    AS CAST(horas_inicial / 8766.0 AS DECIMAL(6, 2)) PERSISTED,
        idade_final_anos      AS CAST(horas_final / 8766.0 AS DECIMAL(6, 2)) PERSISTED,
        temperatura_media     DECIMAL(5, 2) NULL,
        temperatura_max       SMALLINT      NULL,
        max_smart_005         BIGINT        NULL,  -- setores realocados
        max_smart_187         BIGINT        NULL,  -- erros incorrigíveis reportados
        max_smart_188         BIGINT        NULL,  -- timeouts de comando
        max_smart_197         BIGINT        NULL,  -- setores pendentes
        max_smart_198         BIGINT        NULL,  -- setores incorrigíveis offline
        CONSTRAINT pk_dim_disco PRIMARY KEY (sk_disco),
        CONSTRAINT uq_dim_disco_numero_serie UNIQUE (numero_serie),
        CONSTRAINT fk_dim_disco_modelo FOREIGN KEY (sk_modelo)
            REFERENCES dbo.dim_modelo (sk_modelo),
        CONSTRAINT fk_dim_disco_datacenter FOREIGN KEY (sk_datacenter_ultimo)
            REFERENCES dbo.dim_datacenter (sk_datacenter),
        CONSTRAINT ck_dim_disco_situacao CHECK (situacao IN ('ativo', 'falhou', 'retirado'))
    );
    CREATE INDEX ix_dim_disco_modelo ON dbo.dim_disco (sk_modelo);
END;
GO
