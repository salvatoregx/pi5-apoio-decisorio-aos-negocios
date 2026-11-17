-- ============================================================================
-- 03_dim_datacenter.sql
--
-- Objetivo:
--   Dimensão de datacenter: código da Backblaze e localização inferida.
--   Inclui o membro 'desconhecido', para os dias-disco de discos que nunca
--   tiveram localização registrada (saíram da frota antes de 2023).
--
-- Origem dos dados:
--   config/datacenters.json (sql/dml/02_carga_dim_datacenter.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.dim_datacenter', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_datacenter (
        sk_datacenter          INT IDENTITY(1, 1) NOT NULL,
        codigo_datacenter      VARCHAR(20)   NOT NULL,  -- 'phx1', 'sac0', ..., 'desconhecido'
        cidade                 NVARCHAR(100) NULL,
        estado_provincia       NVARCHAR(100) NULL,
        pais                   NVARCHAR(100) NULL,
        regiao_backblaze       NVARCHAR(50)  NULL,
        latitude               DECIMAL(9, 6) NULL,
        longitude              DECIMAL(9, 6) NULL,
        fuso_horario           VARCHAR(50)   NULL,
        confianca_localizacao  NVARCHAR(100) NULL,
        observacao             NVARCHAR(300) NULL,
        CONSTRAINT pk_dim_datacenter PRIMARY KEY (sk_datacenter),
        CONSTRAINT uq_dim_datacenter_codigo UNIQUE (codigo_datacenter)
    );
END;
GO
