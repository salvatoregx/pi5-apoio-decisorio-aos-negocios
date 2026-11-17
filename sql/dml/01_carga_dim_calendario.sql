-- ============================================================================
-- 01_carga_dim_calendario.sql
--
-- Objetivo:
--   Carregar dim_calendario com todos os dias da janela do projeto
--   (2021-07-01 a 2026-06-30). Nomes de mês e de dia em português, sem
--   depender da configuração de idioma da sessão (DATENAME dependeria).
--
-- Origem dos dados:
--   Gerados no próprio banco (sequência de dias).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisito: sql/ddl/02_dim_calendario.sql.
--   Idempotente: MERGE pela chave id_data.
-- ============================================================================

DECLARE @inicio DATE = '2021-07-01';
DECLARE @fim    DATE = '2026-06-30';

WITH dez AS (
    SELECT n FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS v (n)
),
sequencia AS (
    -- 0 a 9.999: cobre a janela (1.826 dias) com folga
    SELECT a.n + 10 * b.n + 100 * c.n + 1000 * d.n AS n
    FROM dez AS a CROSS JOIN dez AS b CROSS JOIN dez AS c CROSS JOIN dez AS d
),
dias AS (
    SELECT DATEADD(DAY, n, @inicio) AS data
    FROM sequencia
    WHERE n <= DATEDIFF(DAY, @inicio, @fim)
),
calendario AS (
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), data, 112)) AS id_data,
        data,
        YEAR(data) AS ano,
        CASE WHEN MONTH(data) <= 6 THEN 1 ELSE 2 END AS semestre,
        DATEPART(QUARTER, data) AS trimestre,
        MONTH(data) AS mes,
        CHOOSE(MONTH(data), N'janeiro', N'fevereiro', N'março', N'abril', N'maio', N'junho',
               N'julho', N'agosto', N'setembro', N'outubro', N'novembro', N'dezembro') AS nome_mes,
        CONVERT(CHAR(7), data, 23) AS ano_mes,
        CONCAT(YEAR(data), '-T', DATEPART(QUARTER, data)) AS ano_trimestre,
        DAY(data) AS dia,
        -- 1 = segunda ... 7 = domingo, qualquer que seja o SET DATEFIRST da sessão
        (DATEPART(WEEKDAY, data) + @@DATEFIRST - 2) % 7 + 1 AS dia_semana
    FROM dias
)
MERGE dbo.dim_calendario AS alvo
USING (
    SELECT
        c.*,
        CHOOSE(c.dia_semana, N'segunda-feira', N'terça-feira', N'quarta-feira', N'quinta-feira',
               N'sexta-feira', N'sábado', N'domingo') AS nome_dia_semana,
        CASE WHEN c.dia_semana >= 6 THEN 1 ELSE 0 END AS fim_de_semana,
        CASE WHEN c.dia = 1 THEN 1 ELSE 0 END AS primeiro_dia_mes
    FROM calendario AS c
) AS origem
    ON alvo.id_data = origem.id_data
WHEN MATCHED THEN UPDATE SET
    alvo.nome_mes = origem.nome_mes,
    alvo.nome_dia_semana = origem.nome_dia_semana,
    alvo.fim_de_semana = origem.fim_de_semana
WHEN NOT MATCHED BY TARGET THEN INSERT (
    id_data, data, ano, semestre, trimestre, mes, nome_mes, ano_mes, ano_trimestre,
    dia, dia_semana, nome_dia_semana, fim_de_semana, primeiro_dia_mes
) VALUES (
    origem.id_data, origem.data, origem.ano, origem.semestre, origem.trimestre, origem.mes,
    origem.nome_mes, origem.ano_mes, origem.ano_trimestre, origem.dia, origem.dia_semana,
    origem.nome_dia_semana, origem.fim_de_semana, origem.primeiro_dia_mes
);
GO

-- Conferência: 1.826 dias, 60 meses.
SELECT COUNT(*) AS dias, COUNT(DISTINCT ano_mes) AS meses, MIN(data) AS inicio, MAX(data) AS fim
FROM dbo.dim_calendario;
