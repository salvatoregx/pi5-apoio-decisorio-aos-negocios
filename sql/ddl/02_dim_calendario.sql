-- ============================================================================
-- 02_dim_calendario.sql
--
-- Objetivo:
--   Dimensão de calendário, grão dia. A chave id_data é inteira no formato
--   AAAAMMDD. As fatos mensais apontam para o 1º dia do mês.
--
-- Origem dos dados:
--   Gerada no próprio banco (sql/dml/01_carga_dim_calendario.sql).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Idempotente: só cria se não existir.
-- ============================================================================

IF OBJECT_ID('dbo.dim_calendario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dim_calendario (
        id_data          INT          NOT NULL,
        data             DATE         NOT NULL,
        ano              SMALLINT     NOT NULL,
        semestre         TINYINT      NOT NULL,
        trimestre        TINYINT      NOT NULL,
        mes              TINYINT      NOT NULL,
        nome_mes         NVARCHAR(12) NOT NULL,
        ano_mes          CHAR(7)      NOT NULL,  -- '2024-01'
        ano_trimestre    CHAR(7)      NOT NULL,  -- '2024-T1'
        dia              TINYINT      NOT NULL,
        dia_semana       TINYINT      NOT NULL,  -- 1 = segunda ... 7 = domingo (ISO 8601)
        nome_dia_semana  NVARCHAR(15) NOT NULL,
        fim_de_semana    BIT          NOT NULL,
        primeiro_dia_mes BIT          NOT NULL,
        CONSTRAINT pk_dim_calendario PRIMARY KEY (id_data),
        CONSTRAINT uq_dim_calendario_data UNIQUE (data),
        CONSTRAINT ck_dim_calendario_mes CHECK (mes BETWEEN 1 AND 12),
        CONSTRAINT ck_dim_calendario_dia_semana CHECK (dia_semana BETWEEN 1 AND 7)
    );
END;
GO
