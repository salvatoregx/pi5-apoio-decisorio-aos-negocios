-- ============================================================================
-- 01_views_referencia_catalogo.sql
--
-- Objetivo:
--   Expor no Synapse o catálogo de especificações dos fabricantes e as fontes
--   dessas especificações, para que a gold de modelos junte os dados técnicos
--   (tecnologia, hélio, RPM, potência, MTBF, AFR declarado, garantia).
--
-- Origem:
--   config/catalogo_fabricantes.csv e config/catalogo_fabricantes_fontes.csv,
--   copiados para lake/referencia/ (passo manual, uma vez; ver sql/README.md).
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
--
-- Observações:
--   - Os campos numéricos são lidos como texto e convertidos com TRY_CAST:
--     campo vazio no CSV vira NULL em vez de erro.
--   - PARSER_VERSION 2.0 trata aspas duplicadas ("3.5""") conforme a RFC 4180.
-- ============================================================================

CREATE OR ALTER VIEW gold.ref_catalogo_fabricantes AS
SELECT
    c.modelo,
    c.fabricante,
    NULLIF(c.familia_produto, '') AS familia_produto,
    NULLIF(c.tecnologia_gravacao, '') AS tecnologia_gravacao,
    NULLIF(c.preenchimento, '') AS preenchimento,
    NULLIF(c.formato, '') AS formato,
    TRY_CAST(NULLIF(c.rpm, '') AS INT) AS rpm,
    NULLIF(c.interface, '') AS interface,
    TRY_CAST(NULLIF(c.cache_mb, '') AS INT) AS cache_mb,
    TRY_CAST(NULLIF(c.potencia_ociosa_w, '') AS DECIMAL(6, 2)) AS potencia_ociosa_w,
    TRY_CAST(NULLIF(c.potencia_operacao_w, '') AS DECIMAL(6, 2)) AS potencia_operacao_w,
    NULLIF(c.criterio_potencia_operacao, '') AS criterio_potencia_operacao,
    TRY_CAST(NULLIF(c.temp_operacao_min_c, '') AS DECIMAL(5, 1)) AS temp_operacao_min_c,
    TRY_CAST(NULLIF(c.temp_operacao_max_c, '') AS DECIMAL(5, 1)) AS temp_operacao_max_c,
    TRY_CAST(NULLIF(c.mtbf_horas, '') AS INT) AS mtbf_horas,
    TRY_CAST(NULLIF(c.afr_declarado_pct, '') AS DECIMAL(6, 3)) AS afr_declarado_pct,
    TRY_CAST(NULLIF(c.carga_trabalho_tb_ano, '') AS DECIMAL(8, 1)) AS carga_trabalho_tb_ano,
    TRY_CAST(NULLIF(c.garantia_anos, '') AS INT) AS garantia_anos,
    NULLIF(c.observacoes, '') AS observacoes
FROM OPENROWSET(
    BULK 'referencia/catalogo_fabricantes.csv',
    DATA_SOURCE = 'lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE,
    FIELDQUOTE = '"'
) WITH (
    modelo VARCHAR(100),
    fabricante VARCHAR(100),
    familia_produto VARCHAR(100),
    tecnologia_gravacao VARCHAR(100),
    preenchimento VARCHAR(20),
    formato VARCHAR(20),
    rpm VARCHAR(20),
    interface VARCHAR(50),
    cache_mb VARCHAR(20),
    potencia_ociosa_w VARCHAR(20),
    potencia_operacao_w VARCHAR(20),
    criterio_potencia_operacao VARCHAR(100),
    temp_operacao_min_c VARCHAR(20),
    temp_operacao_max_c VARCHAR(20),
    mtbf_horas VARCHAR(20),
    afr_declarado_pct VARCHAR(20),
    carga_trabalho_tb_ano VARCHAR(20),
    garantia_anos VARCHAR(20),
    observacoes VARCHAR(1000)
) AS c;
GO

CREATE OR ALTER VIEW gold.ref_catalogo_fontes AS
SELECT
    f.modelo,
    f.url,
    f.titulo,
    f.tipo_fonte,
    f.campos,
    TRY_CAST(NULLIF(f.acessado_em, '') AS DATE) AS acessado_em
FROM OPENROWSET(
    BULK 'referencia/catalogo_fabricantes_fontes.csv',
    DATA_SOURCE = 'lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE,
    FIELDQUOTE = '"'
) WITH (
    modelo VARCHAR(100),
    url VARCHAR(500),
    titulo VARCHAR(300),
    tipo_fonte VARCHAR(50),
    campos VARCHAR(500),
    acessado_em VARCHAR(20)
) AS f;
GO

-- Conferência rápida (custo desprezível: arquivos de poucos KB).
-- Esperado: 100 modelos e 164 fontes.
-- SELECT COUNT(*) FROM gold.ref_catalogo_fabricantes;
-- SELECT COUNT(*) FROM gold.ref_catalogo_fontes;
