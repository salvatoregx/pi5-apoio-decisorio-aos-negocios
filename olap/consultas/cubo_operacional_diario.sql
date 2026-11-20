/* ============================================================
   CUBO OPERACIONAL — SCRIPT CONSOLIDADO
   Pré-requisitos:
     - dbo.fato_temperatura_dc_dia  (fato, diário × DC × mídia)
     - dbo.dim_datacenter           (TABELA real, com FK do fato)
   ============================================================ */


/* ------------------------------------------------------------
   0) Sanidade (opcional; roda só para conferir)
   ------------------------------------------------------------ */
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.name = 'fato_temperatura_dc_dia';
GO


/* ------------------------------------------------------------
   1) Limpeza idempotente (SÓ views; NÃO toca na dim_datacenter)
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.cubo_operacional','V')  IS NOT NULL DROP VIEW dbo.cubo_operacional;
IF OBJECT_ID('dbo.vw_dim_datacenter','V') IS NOT NULL DROP VIEW dbo.vw_dim_datacenter;
IF OBJECT_ID('dbo.dim_tempo_dia','V')     IS NOT NULL DROP VIEW dbo.dim_tempo_dia;
IF OBJECT_ID('dbo.dim_tipo_midia','V')    IS NOT NULL DROP VIEW dbo.dim_tipo_midia;
GO


/* ------------------------------------------------------------
   2) Wrapper sobre a dim_datacenter real
      (padroniza os nomes que o cubo espera: datacenter, regiao)
   ------------------------------------------------------------ */
CREATE VIEW dbo.vw_dim_datacenter AS
SELECT
    sk_datacenter,
    codigo_datacenter      AS datacenter,
    cidade,
    estado_provincia,
    regiao_backblaze       AS regiao,
    pais,
    latitude,
    longitude,
    fuso_horario,
    confianca_localizacao,
    observacao
FROM dbo.dim_datacenter;
GO


/* ------------------------------------------------------------
   3) dim_tempo_dia (derivada de id_data yyyymmdd)
   ------------------------------------------------------------ */
CREATE VIEW dbo.dim_tempo_dia AS
SELECT DISTINCT
    id_data,
    CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112)                     AS [data],
    YEAR   (CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112))            AS ano,
    MONTH  (CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112))            AS mes,
    DAY    (CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112))            AS dia,
    DATEPART(QUARTER, CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112))  AS trimestre,
    YEAR   (CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112)) * 100
      + MONTH(CONVERT(DATE, CAST(id_data AS VARCHAR(8)), 112))          AS id_data_mes
FROM dbo.fato_temperatura_dc_dia;
GO


/* ------------------------------------------------------------
   4) dim_tipo_midia
   ------------------------------------------------------------ */
CREATE VIEW dbo.dim_tipo_midia AS
SELECT DISTINCT
    tipo_midia,
    tipo_midia AS descricao
FROM dbo.fato_temperatura_dc_dia;
GO


/* ------------------------------------------------------------
   5) cubo_operacional — a view OLAP principal
   ------------------------------------------------------------ */
CREATE VIEW dbo.cubo_operacional AS
SELECT
    -- EIXOS TEMPORAIS (hierarquia: ano → trimestre → mês → dia)
    t.[data], t.ano, t.trimestre, t.mes, t.dia, t.id_data_mes,

    -- EIXOS GEOGRÁFICOS (hierarquia: país → região → estado → cidade → DC)
    dc.pais, dc.regiao, dc.estado_provincia, dc.cidade, dc.datacenter, dc.fuso_horario,

    -- EIXO PRODUTO
    f.tipo_midia,

    -- MEDIDAS ADITIVAS (somar em qualquer nível, exceto tempo para "discos")
    f.discos, f.discos_imputados, f.capacidade_tb_total,
    f.falhas, f.soma_temperatura, f.contagem_temperatura,

    -- MEDIDAS SEMI-ADITIVAS (agregação = MAX, nunca soma)
    f.temperatura_p50, f.temperatura_p95, f.temperatura_max,

    -- MEDIDAS DERIVADAS (recalcular a partir dos aditivos; NUNCA somar)
    CAST(ROUND(CAST(f.soma_temperatura AS DECIMAL(18,4))
               / NULLIF(f.contagem_temperatura, 0), 2) AS DECIMAL(10,2))
        AS temperatura_media_calc,

    CAST(ROUND(f.discos_imputados * 100.0 / NULLIF(f.discos, 0), 2) AS DECIMAL(10,2))
        AS pct_imputados,

    CAST(ROUND(f.capacidade_tb_total
               / NULLIF(CAST(f.discos AS DECIMAL(18,4)), 0), 2) AS DECIMAL(10,2))
        AS capacidade_tb_por_disco,

    CAST(ROUND(f.falhas * 365.0 / NULLIF(f.discos, 0), 4) AS DECIMAL(10,4))
        AS falhas_por_disco_ano

FROM dbo.fato_temperatura_dc_dia f
JOIN dbo.dim_tempo_dia    t  ON t.id_data        = f.id_data
JOIN dbo.vw_dim_datacenter dc ON dc.sk_datacenter = f.sk_datacenter;
GO


/* ============================================================
   6) VALIDAÇÃO — rode só depois do script acima
   ============================================================ */

-- 6.1 as 4 views existem?
SELECT name, type_desc, modify_date
FROM sys.objects
WHERE name IN ('vw_dim_datacenter','dim_tempo_dia','dim_tipo_midia','cubo_operacional')
ORDER BY name;
GO

-- 6.2 amostra do cubo
SELECT TOP 10 *
FROM dbo.cubo_operacional
ORDER BY [data] DESC, datacenter, tipo_midia;
GO

-- 6.3 contagem bate com o CSV (~90 dias × ~10 linhas/dia ≈ ~900 linhas)
SELECT COUNT(*) AS linhas, COUNT(DISTINCT [data]) AS dias
FROM dbo.cubo_operacional;
GO