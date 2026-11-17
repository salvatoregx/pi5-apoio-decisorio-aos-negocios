-- ============================================================================
-- 99_remover_tabelas.sql
--
-- Objetivo:
--   Apagar todas as tabelas do DW (fatos, dimensões e staging), para refazer
--   o banco do zero na revisão final. NÃO faz parte da execução normal.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'.
--
-- Ordem: fatos antes das dimensões, por causa das chaves estrangeiras.
-- ============================================================================

DROP TABLE IF EXISTS dbo.fato_temperatura_dc_dia;
DROP TABLE IF EXISTS dbo.fato_confiabilidade_faixas;
DROP TABLE IF EXISTS dbo.fato_confiabilidade_mensal;
DROP TABLE IF EXISTS dbo.dim_modelo_fonte;
DROP TABLE IF EXISTS dbo.dim_disco;
DROP TABLE IF EXISTS dbo.dim_modelo;
DROP TABLE IF EXISTS dbo.dim_datacenter;
DROP TABLE IF EXISTS dbo.dim_faixa_temperatura;
DROP TABLE IF EXISTS dbo.dim_faixa_idade;
DROP TABLE IF EXISTS dbo.dim_calendario;

DROP TABLE IF EXISTS stg.fato_temperatura_dc_dia;
DROP TABLE IF EXISTS stg.fato_confiabilidade_faixas;
DROP TABLE IF EXISTS stg.fato_confiabilidade_mensal;
DROP TABLE IF EXISTS stg.disco;
DROP TABLE IF EXISTS stg.modelo_fonte;
DROP TABLE IF EXISTS stg.modelo;
GO
