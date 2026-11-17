-- ============================================================================
-- 04_dim_modelo.sql
--
-- Objetivo:
--   Dimensão de modelo de disco: classificação derivada na silver (fabricante,
--   mídia, função, capacidade) e especificações do catálogo dos fabricantes.
--   Hierarquia para roll-up/drill-down: fabricante → modelo.
--
-- Origem dos dados:
--   lake/gold/modelo/ → stg.modelo (sql/dml/05_carga_dim_modelo.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
--
-- Collation de modelo: sensível a maiúsculas (CS), como no lake. Com a collation
--   padrão do banco (CI), dois valores que só diferem na caixa violariam o UNIQUE.
-- ============================================================================

IF OBJECT_ID('dbo.dim_modelo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_modelo (
        sk_modelo                  INT IDENTITY(1, 1) NOT NULL,
        modelo                     VARCHAR(100) COLLATE Latin1_General_100_CS_AS   NOT NULL,
        fabricante                 NVARCHAR(50)   NOT NULL,
        tipo_midia                 VARCHAR(3)     NOT NULL,  -- HDD / SSD
        funcao_disco               VARCHAR(5)     NOT NULL,  -- boot / dados
        capacidade_tb              DECIMAL(6, 1)  NULL,
        primeira_data              DATE           NULL,      -- primeiro dia observado na janela
        ultima_data                DATE           NULL,      -- último dia observado na janela
        no_catalogo                BIT            NOT NULL,  -- 1 = tem especificações no catálogo
        familia_produto            NVARCHAR(100)  NULL,
        tecnologia_gravacao        NVARCHAR(100)  NULL,
        preenchimento              NVARCHAR(20)   NULL,      -- ar / hélio
        formato                    NVARCHAR(20)   NULL,
        rpm                        INT            NULL,
        interface                  NVARCHAR(50)   NULL,
        cache_mb                   INT            NULL,
        potencia_ociosa_w          DECIMAL(6, 2)  NULL,
        potencia_operacao_w        DECIMAL(6, 2)  NULL,
        criterio_potencia_operacao NVARCHAR(100)  NULL,
        temp_operacao_min_c        DECIMAL(5, 1)  NULL,
        temp_operacao_max_c        DECIMAL(5, 1)  NULL,
        mtbf_horas                 INT            NULL,
        afr_declarado_pct          DECIMAL(6, 3)  NULL,
        carga_trabalho_tb_ano      DECIMAL(8, 1)  NULL,
        garantia_anos              TINYINT        NULL,
        observacoes                NVARCHAR(1000) NULL,
        CONSTRAINT pk_dim_modelo PRIMARY KEY (sk_modelo),
        CONSTRAINT uq_dim_modelo_modelo UNIQUE (modelo),
        CONSTRAINT ck_dim_modelo_tipo_midia CHECK (tipo_midia IN ('HDD', 'SSD')),
        CONSTRAINT ck_dim_modelo_funcao CHECK (funcao_disco IN ('boot', 'dados'))
    );
END;
GO
