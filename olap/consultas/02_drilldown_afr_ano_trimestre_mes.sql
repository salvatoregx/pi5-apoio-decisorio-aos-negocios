/* ============================================================================
   02_drilldown_afr_ano_trimestre_mes.sql

   Operação: DRILL-DOWN (ano → trimestre → mês) para um fabricante.
   Pergunta de negócio 5: como o AFR evolui com o tempo (envelhecimento da frota)?

   Fonte: dbo.fato_confiabilidade_mensal.
   Regras:
     - Só discos de dados. Fabricante na variável @fabricante.
     - nivel: 'ano', 'trimestre' ou 'mês'; cada ano aparece seguido dos seus
       trimestres, e cada trimestre dos seus meses.
     - 2021 começa em julho e 2026 termina em junho (janela de 20 trimestres).
   Evidência: olap/evidencias/02_drilldown_afr_ano_trimestre_mes.csv
   ============================================================================ */

DECLARE @fabricante NVARCHAR(50) = N'Seagate';

SELECT
    CASE GROUPING_ID(c.ano, c.trimestre, c.ano_mes)
        WHEN 0 THEN 'mês'
        WHEN 1 THEN 'trimestre'
        WHEN 3 THEN 'ano'
        ELSE 'total'
    END AS nivel,
    c.ano,
    c.trimestre,
    c.ano_mes,
    SUM(f.dias_disco) AS dias_disco,
    SUM(f.falhas) AS falhas,
    CAST(100.0 * SUM(f.falhas) * 365 / NULLIF(SUM(f.dias_disco), 0) AS DECIMAL(9, 2)) AS afr_pct
FROM dbo.fato_confiabilidade_mensal AS f
JOIN dbo.dim_modelo AS m ON m.sk_modelo = f.sk_modelo
JOIN dbo.dim_calendario AS c ON c.id_data = f.id_data_mes
WHERE m.funcao_disco = 'dados'
  AND m.fabricante = @fabricante
GROUP BY ROLLUP (c.ano, c.trimestre, c.ano_mes)
ORDER BY
    GROUPING(c.ano), c.ano,
    GROUPING(c.trimestre) DESC, c.trimestre,
    GROUPING(c.ano_mes) DESC, c.ano_mes;
