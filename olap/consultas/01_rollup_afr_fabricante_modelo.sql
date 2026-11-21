/* ============================================================================
   01_rollup_afr_fabricante_modelo.sql

   Operação: ROLL-UP (modelo → fabricante → total).
   Pergunta de negócio 1: qual fabricante e qual modelo falham menos?

   Fonte: dbo.fato_confiabilidade_mensal, janela completa (2021-07 a 2026-06).
   Regras:
     - Só discos de dados (funcao_disco = 'dados').
     - Modelos com menos de 100 mil dias-disco ficam de fora das linhas de
       modelo (amostra pequena distorce o AFR; mesmo critério da Backblaze),
       mas continuam somados no subtotal do fabricante e no total.
     - nivel: 'modelo', 'fabricante' (subtotal) ou 'total'.
   Evidência: olap/evidencias/01_rollup_afr_fabricante_modelo.csv
   ============================================================================ */

SELECT
    CASE GROUPING_ID(m.fabricante, m.modelo)
        WHEN 0 THEN 'modelo'
        WHEN 1 THEN 'fabricante'
        ELSE 'total'
    END AS nivel,
    CASE WHEN GROUPING(m.fabricante) = 1 THEN '(todos)' ELSE m.fabricante END AS fabricante,
    CASE WHEN GROUPING(m.modelo) = 1 THEN '(todos)' ELSE m.modelo END AS modelo,
    SUM(f.dias_disco) AS dias_disco,
    SUM(f.falhas) AS falhas,
    CAST(100.0 * SUM(f.falhas) * 365 / NULLIF(SUM(f.dias_disco), 0) AS DECIMAL(9, 2)) AS afr_pct
FROM dbo.fato_confiabilidade_mensal AS f
JOIN dbo.dim_modelo AS m ON m.sk_modelo = f.sk_modelo
WHERE m.funcao_disco = 'dados'
GROUP BY ROLLUP (m.fabricante, m.modelo)
HAVING GROUPING(m.modelo) = 1 OR SUM(f.dias_disco) >= 100000
ORDER BY
    GROUPING(m.fabricante),        -- total por último
    m.fabricante,
    GROUPING(m.modelo) DESC,       -- subtotal do fabricante antes dos modelos
    afr_pct;
