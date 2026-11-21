/* ============================================================================
   04_dice_afr_fabricante_idade.sql

   Operação: DICE (filtro em várias dimensões ao mesmo tempo:
   fabricante × período × faixa de idade).
   Pergunta de negócio 5: discos mais velhos falham mais, e isso varia por fabricante?

   Fonte: dbo.vw_confiabilidade_estrela (script 00).
   Recorte:
     - fabricantes: Seagate, Toshiba e Western Digital;
     - período: 2024 e 2025;
     - idade: faixas a partir de 3 anos (id_faixa_idade >= 3);
     - só discos de dados.
   Evidência: olap/evidencias/04_dice_afr_fabricante_idade.csv
   ============================================================================ */

SELECT
    v.fabricante,
    v.id_faixa_idade,
    v.faixa_idade,
    SUM(v.dias_disco) AS dias_disco,
    SUM(v.falhas) AS falhas,
    CAST(100.0 * SUM(v.falhas) * 365 / NULLIF(SUM(v.dias_disco), 0) AS DECIMAL(9, 2)) AS afr_pct,
    CAST(1.0 * SUM(v.soma_idade_anos) / NULLIF(SUM(v.contagem_idade), 0) AS DECIMAL(5, 2)) AS idade_media_anos
FROM dbo.vw_confiabilidade_estrela AS v
WHERE v.fabricante IN (N'Seagate', N'Toshiba', N'Western Digital')
  AND v.ano BETWEEN 2024 AND 2025
  AND v.id_faixa_idade >= 3
  AND v.funcao_disco = 'dados'
GROUP BY v.fabricante, v.id_faixa_idade, v.faixa_idade
ORDER BY v.fabricante, v.id_faixa_idade;
