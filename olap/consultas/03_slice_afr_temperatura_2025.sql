/* ============================================================================
   03_slice_afr_temperatura_2025.sql

   Operação: SLICE (corte em uma dimensão: tempo = ano 2025).
   Pergunta de negócio 2: a temperatura influencia as falhas?

   Fonte: dbo.vw_confiabilidade_estrela (script 00).
   Regras:
     - Só discos de dados; 2025 é o último ano completo da janela.
     - Faixas de 5 °C, ordenadas pelo id da faixa (0 = temperatura não informada).
     - temperatura_media_c ponderada pelas leituras (soma / contagem).
   Evidência: olap/evidencias/03_slice_afr_temperatura_2025.csv
   ============================================================================ */

SELECT
    v.id_faixa_temperatura,
    v.faixa_temperatura,
    v.estresse_termico,
    SUM(v.dias_disco) AS dias_disco,
    SUM(v.falhas) AS falhas,
    CAST(100.0 * SUM(v.falhas) * 365 / NULLIF(SUM(v.dias_disco), 0) AS DECIMAL(9, 2)) AS afr_pct,
    CAST(1.0 * SUM(v.soma_temperatura) / NULLIF(SUM(v.contagem_temperatura), 0) AS DECIMAL(5, 2)) AS temperatura_media_c
FROM dbo.vw_confiabilidade_estrela AS v
WHERE v.ano = 2025
  AND v.funcao_disco = 'dados'
GROUP BY v.id_faixa_temperatura, v.faixa_temperatura, v.estresse_termico
ORDER BY v.id_faixa_temperatura;
