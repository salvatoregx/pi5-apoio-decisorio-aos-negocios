/* ============================================================================
   06_temperatura_datacenter.sql

   Análise complementar (pergunta de negócio 4): há datacenter mais quente,
   e ele falha mais?

   Fonte: dbo.fato_temperatura_dc_dia, discos HDD, de 2023 em diante (antes
   disso a localização é imputada pelo último datacenter conhecido do disco).
   Regras:
     - O membro 'desconhecido' (dias-disco sem localização) fica de fora.
     - temperatura_media_c ponderada pelas leituras (soma / contagem).
     - discos_medios_dia = dias-disco / dias com registro.
     - maior_p95_diario_c: o maior percentil 95 diário do ano (percentil não
       se soma nem se tira média; o máximo dos diários é só um indicador).
     - AFR % com dias-disco (cada linha da fato conta discos em operação no dia).
   Evidência: olap/evidencias/06_temperatura_datacenter.csv
   ============================================================================ */

SELECT
    c.ano,
    d.codigo_datacenter AS datacenter,
    d.cidade,
    d.pais,
    SUM(CAST(f.discos AS BIGINT)) / COUNT(DISTINCT f.id_data) AS discos_medios_dia,
    CAST(1.0 * SUM(f.soma_temperatura) / NULLIF(SUM(CAST(f.contagem_temperatura AS BIGINT)), 0) AS DECIMAL(5, 2)) AS temperatura_media_c,
    MAX(f.temperatura_p95) AS maior_p95_diario_c,
    SUM(f.falhas) AS falhas,
    CAST(100.0 * SUM(f.falhas) * 365 / NULLIF(SUM(CAST(f.discos AS BIGINT)), 0) AS DECIMAL(9, 2)) AS afr_pct
FROM dbo.fato_temperatura_dc_dia AS f
JOIN dbo.dim_calendario AS c ON c.id_data = f.id_data
JOIN dbo.dim_datacenter AS d ON d.sk_datacenter = f.sk_datacenter
WHERE f.tipo_midia = 'HDD'
  AND c.ano >= 2023
  AND d.codigo_datacenter <> 'desconhecido'
GROUP BY c.ano, d.codigo_datacenter, d.cidade, d.pais
ORDER BY c.ano, temperatura_media_c DESC;
