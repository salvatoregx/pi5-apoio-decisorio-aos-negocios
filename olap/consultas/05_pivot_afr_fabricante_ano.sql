/* ============================================================================
   05_pivot_afr_fabricante_ano.sql

   Operação: PIVOT (fabricantes nas linhas, anos nas colunas).
   Pergunta de negócio 1: como o AFR de cada fabricante evolui ano a ano?

   Fonte: dbo.fato_confiabilidade_mensal.
   Regras:
     - Só discos de dados. Cada célula é o AFR % do fabricante no ano,
       calculado com as somas de falhas e dias-disco daquele ano.
     - 2021 tem só o 2º semestre e 2026 só o 1º (janela de 20 trimestres).
     - Célula vazia: fabricante sem discos de dados naquele ano.
   Evidência: olap/evidencias/05_pivot_afr_fabricante_ano.csv
   ============================================================================ */

WITH afr AS (
    SELECT
        m.fabricante,
        c.ano,
        CAST(100.0 * SUM(f.falhas) * 365 / NULLIF(SUM(f.dias_disco), 0) AS DECIMAL(9, 2)) AS afr_pct
    FROM dbo.fato_confiabilidade_mensal AS f
    JOIN dbo.dim_modelo AS m ON m.sk_modelo = f.sk_modelo
    JOIN dbo.dim_calendario AS c ON c.id_data = f.id_data_mes
    WHERE m.funcao_disco = 'dados'
    GROUP BY m.fabricante, c.ano
)
SELECT fabricante, [2021], [2022], [2023], [2024], [2025], [2026]
FROM afr
PIVOT (MAX(afr_pct) FOR ano IN ([2021], [2022], [2023], [2024], [2025], [2026])) AS p
ORDER BY fabricante;
