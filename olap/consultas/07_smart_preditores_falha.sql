/* ============================================================================
   07_smart_preditores_falha.sql

   Análise complementar (pergunta de negócio 3): os atributos SMART apontados
   pela Backblaze como preditores aparecem mais nos discos que falharam?

   Fonte: dbo.dim_disco (um registro por disco, com o máximo de cada SMART
   na janela) e dbo.dim_modelo.
   Regras:
     - Só discos de dados. Conta discos de verdade (uma linha por número de série).
     - pct_smart_NNN: % dos discos do grupo com o valor máximo > 0 no atributo.
     - pct_algum_alerta: % com pelo menos um dos cinco atributos > 0.
   Evidência: olap/evidencias/07_smart_preditores_falha.csv
   ============================================================================ */

SELECT
    CASE WHEN dd.falhou = 1 THEN 'falhou' ELSE 'não falhou' END AS grupo,
    COUNT(*) AS discos,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_005 > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_smart_005,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_187 > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_smart_187,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_188 > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_smart_188,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_197 > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_smart_197,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_198 > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_smart_198,
    CAST(100.0 * SUM(CASE WHEN dd.max_smart_005 > 0 OR dd.max_smart_187 > 0 OR dd.max_smart_188 > 0
                           OR dd.max_smart_197 > 0 OR dd.max_smart_198 > 0
                          THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS pct_algum_alerta
FROM dbo.dim_disco AS dd
JOIN dbo.dim_modelo AS m ON m.sk_modelo = dd.sk_modelo
WHERE m.funcao_disco = 'dados'
GROUP BY CASE WHEN dd.falhou = 1 THEN 'falhou' ELSE 'não falhou' END
ORDER BY grupo;
