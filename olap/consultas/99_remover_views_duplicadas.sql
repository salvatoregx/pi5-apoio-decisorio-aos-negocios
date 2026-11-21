/* ============================================================================
   99_remover_views_duplicadas.sql

   Remove do dw as views criadas pelo primeiro script de cubo operacional, que
   duplicavam dimensões já existentes (dim_calendario e dim_datacenter).
   As consultas OLAP usam as dimensões originais. Rodar uma vez.

   Onde executa: Azure SQL Database, banco dw.
   ============================================================================ */

DROP VIEW IF EXISTS dbo.cubo_operacional;   -- depende das três abaixo: sai primeiro
DROP VIEW IF EXISTS dbo.dim_tempo_dia;
DROP VIEW IF EXISTS dbo.vw_dim_datacenter;
DROP VIEW IF EXISTS dbo.dim_tipo_midia;
