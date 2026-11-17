-- ============================================================================
-- 03_view_silver_disco_dia.sql
--
-- Objetivo:
--   Cria a view da camada Silver (silver.disco_dia) no Synapse Serverless SQL.
--   Aplica limpeza, deduplicação por dia e disco, padronização de nomenclatura
--   em português, classificação de fabricantes, identificação de SSD/HDD e 
--   função (boot/dados), saneamento de métricas (temperatura, horas ligado, 
--   capacidade) e renomeação dos 88 atributos SMART selecionados.
--
-- Origem:
--   bronze.drivestats (ADLS Gen2 lake/bronze/drivestats/)
--
-- Onde executa:
--   Azure Synapse Analytics (Pool SQL Serverless Built-in, banco 'pi5').
-- ============================================================================

CREATE OR ALTER VIEW silver.disco_dia AS
WITH base AS (
    SELECT 
        b.*,
        TRIM(b.serial_number) AS _serie,
        -- Reduz espaços múltiplos repetidos a apenas um espaço
        REPLACE(REPLACE(TRIM(b.model), '   ', ' '), '  ', ' ') AS _modelo_bruto
    FROM bronze.drivestats AS b
),
padronizada AS (
    SELECT 
        *,
        -- Se começar com WUH, prefixa com 'WDC ' para unificar Western Digital
        CASE 
            WHEN _modelo_bruto LIKE 'WUH%' THEN 'WDC ' + _modelo_bruto 
            ELSE _modelo_bruto 
        END AS _modelo,
        -- Deduplicação: se houver mais de uma linha para o mesmo disco e dia,
        -- mantém a que tem falha = 1. ano_mes na partição garante poda sem ler tudo.
        ROW_NUMBER() OVER (
            PARTITION BY ano_mes, _serie, date 
            ORDER BY failure DESC
        ) AS _ordem
    FROM base
)
SELECT
    -- Identificação temporal e de particionamento
    date AS data,
    ano_mes,

    -- Identificação do disco e modelo
    _serie AS numero_serie,
    _modelo AS modelo,

    -- Fabricante padronizado (primeira regra coincidente na ordem de precedência)
    CASE 
        WHEN _modelo LIKE 'ST%' OR _modelo LIKE 'Seagate%' THEN 'Seagate'
        WHEN _modelo LIKE 'HGST%' OR _modelo LIKE 'Hitachi%' THEN 'HGST (Western Digital)'
        WHEN _modelo LIKE 'WDC%' OR _modelo LIKE 'WD %' THEN 'Western Digital'
        WHEN _modelo LIKE 'TOSHIBA%' THEN 'Toshiba'
        WHEN _modelo LIKE 'Micron%' OR _modelo LIKE 'MTFD%' THEN 'Micron'
        WHEN _modelo LIKE 'CT%' THEN 'Crucial (Micron)'
        WHEN _modelo LIKE 'SSDSC%' OR _modelo LIKE 'INTEL%' THEN 'Intel'
        WHEN _modelo LIKE 'Samsung%' THEN 'Samsung'
        WHEN _modelo LIKE 'DELLBOSS%' THEN 'Dell (BOSS)'
        WHEN _modelo LIKE 'HP %' THEN 'HP'
        ELSE 'Outro/Desconhecido'
    END AS fabricante,

    -- Tipo de mídia (SSD vs HDD via padrões de modelo)
    CASE 
        WHEN UPPER(_modelo) LIKE '%SSD%' 
          OR UPPER(_modelo) LIKE 'MTFD%' 
          OR UPPER(_modelo) LIKE 'SSDSC%' 
          OR UPPER(_modelo) LIKE 'CT[0-9]%MX%' 
          OR UPPER(_modelo) LIKE 'MICRON%' 
          OR UPPER(_modelo) LIKE 'SAMSUNG%' 
          OR UPPER(_modelo) LIKE '%ZA[0-9]%M1%' 
          OR UPPER(_modelo) LIKE 'WDC WDS%' 
          OR UPPER(_modelo) LIKE '%SA510%' 
          OR UPPER(_modelo) LIKE 'DELLBOSS%' 
        THEN 'SSD'
        ELSE 'HDD'
    END AS tipo_midia,

    -- Função do disco: boot se for SSD ou capacidade inferior a 2 TB; senão dados
    CASE 
        WHEN UPPER(_modelo) LIKE '%SSD%' 
          OR UPPER(_modelo) LIKE 'MTFD%' 
          OR UPPER(_modelo) LIKE 'SSDSC%' 
          OR UPPER(_modelo) LIKE 'CT[0-9]%MX%' 
          OR UPPER(_modelo) LIKE 'MICRON%' 
          OR UPPER(_modelo) LIKE 'SAMSUNG%' 
          OR UPPER(_modelo) LIKE '%ZA[0-9]%M1%' 
          OR UPPER(_modelo) LIKE 'WDC WDS%' 
          OR UPPER(_modelo) LIKE '%SA510%' 
          OR UPPER(_modelo) LIKE 'DELLBOSS%' 
          OR (capacity_bytes > 0 AND capacity_bytes < 2000000000000) 
        THEN 'boot'
        ELSE 'dados'
    END AS funcao_disco,

    -- Capacidade e conversão para Terabytes
    CASE WHEN capacity_bytes > 0 THEN capacity_bytes END AS capacidade_bytes,
    CASE WHEN capacity_bytes > 0 THEN ROUND(CAST(capacity_bytes AS FLOAT) / 1e12, 1) END AS capacidade_tb,

    -- Indicador de falha no dia (1 = falha, 0 = normal)
    failure AS falha,

    -- Localização física no datacenter (disponível a partir de 2023)
    datacenter,
    cluster_id AS id_cluster,
    vault_id AS id_vault,
    pod_id AS id_pod,
    pod_slot_num AS slot_pod,
    is_legacy_format AS formato_legado,

    -- Métricas de saúde e operação derivadas
    -- Temperatura: se entre 1 e 100 usa o valor; se > 255 usa byte inferior (& 255)
    CASE 
        WHEN smart_194_raw BETWEEN 1 AND 100 THEN smart_194_raw
        WHEN smart_194_raw > 255 AND (smart_194_raw & 255) BETWEEN 1 AND 100 THEN smart_194_raw & 255
    END AS temperatura_c,

    -- Horas ligado (SMART 9) e conversão para idade em anos (8766 horas/ano)
    CASE 
        WHEN smart_9_raw BETWEEN 0 AND 200000 THEN smart_9_raw 
    END AS horas_ligado,

    CASE 
        WHEN smart_9_raw BETWEEN 0 AND 200000 THEN ROUND(CAST(smart_9_raw AS FLOAT) / 8766.0, 2) 
    END AS idade_anos,

    -- ========================================================================
    -- Atributos SMART padronizados (44 atributos selecionados, bruto e normalizado)
    -- ========================================================================
    smart_1_raw AS smart_001_taxa_erros_leitura_bruto,
    smart_1_normalized AS smart_001_taxa_erros_leitura_normalizado,
    smart_2_raw AS smart_002_desempenho_throughput_bruto,
    smart_2_normalized AS smart_002_desempenho_throughput_normalizado,
    smart_3_raw AS smart_003_tempo_spin_up_bruto,
    smart_3_normalized AS smart_003_tempo_spin_up_normalizado,
    smart_4_raw AS smart_004_contagem_start_stop_bruto,
    smart_4_normalized AS smart_004_contagem_start_stop_normalizado,
    smart_5_raw AS smart_005_setores_realocados_bruto,
    smart_5_normalized AS smart_005_setores_realocados_normalizado,
    smart_7_raw AS smart_007_taxa_erros_seek_bruto,
    smart_7_normalized AS smart_007_taxa_erros_seek_normalizado,
    smart_8_raw AS smart_008_desempenho_seek_bruto,
    smart_8_normalized AS smart_008_desempenho_seek_normalizado,
    smart_9_raw AS smart_009_horas_ligado_bruto,
    smart_9_normalized AS smart_009_horas_ligado_normalizado,
    smart_10_raw AS smart_010_tentativas_spin_up_bruto,
    smart_10_normalized AS smart_010_tentativas_spin_up_normalizado,
    smart_12_raw AS smart_012_ciclos_energia_bruto,
    smart_12_normalized AS smart_012_ciclos_energia_normalizado,
    smart_18_raw AS smart_018_saude_cabecotes_bruto,
    smart_18_normalized AS smart_018_saude_cabecotes_normalizado,
    smart_22_raw AS smart_022_nivel_helio_bruto,
    smart_22_normalized AS smart_022_nivel_helio_normalizado,
    smart_23_raw AS smart_023_helio_condicao_inferior_bruto,
    smart_23_normalized AS smart_023_helio_condicao_inferior_normalizado,
    smart_24_raw AS smart_024_helio_condicao_superior_bruto,
    smart_24_normalized AS smart_024_helio_condicao_superior_normalizado,
    smart_27_raw AS smart_027_saude_mamr_bruto,
    smart_27_normalized AS smart_027_saude_mamr_normalizado,
    smart_71_raw AS smart_071_microatuador_bruto,
    smart_71_normalized AS smart_071_microatuador_normalizado,
    smart_90_raw AS smart_090_nand_mestre_bruto,
    smart_90_normalized AS smart_090_nand_mestre_normalizado,
    smart_173_raw AS smart_173_nivelamento_desgaste_bruto,
    smart_173_normalized AS smart_173_nivelamento_desgaste_normalizado,
    smart_174_raw AS smart_174_perdas_energia_inesperadas_bruto,
    smart_174_normalized AS smart_174_perdas_energia_inesperadas_normalizado,
    smart_183_raw AS smart_183_downshift_sata_bruto,
    smart_183_normalized AS smart_183_downshift_sata_normalizado,
    smart_184_raw AS smart_184_erros_ponta_a_ponta_bruto,
    smart_184_normalized AS smart_184_erros_ponta_a_ponta_normalizado,
    smart_187_raw AS smart_187_erros_incorrigiveis_reportados_bruto,
    smart_187_normalized AS smart_187_erros_incorrigiveis_reportados_normalizado,
    smart_188_raw AS smart_188_timeouts_comando_bruto,
    smart_188_normalized AS smart_188_timeouts_comando_normalizado,
    smart_189_raw AS smart_189_escritas_voo_alto_bruto,
    smart_189_normalized AS smart_189_escritas_voo_alto_normalizado,
    smart_190_raw AS smart_190_temperatura_fluxo_ar_bruto,
    smart_190_normalized AS smart_190_temperatura_fluxo_ar_normalizado,
    smart_191_raw AS smart_191_erros_sensor_choque_bruto,
    smart_191_normalized AS smart_191_erros_sensor_choque_normalizado,
    smart_192_raw AS smart_192_recolhimentos_emergencia_bruto,
    smart_192_normalized AS smart_192_recolhimentos_emergencia_normalizado,
    smart_193_raw AS smart_193_ciclos_carga_descarga_bruto,
    smart_193_normalized AS smart_193_ciclos_carga_descarga_normalizado,
    smart_194_raw AS smart_194_temperatura_bruto,
    smart_194_normalized AS smart_194_temperatura_normalizado,
    smart_195_raw AS smart_195_ecc_hardware_recuperado_bruto,
    smart_195_normalized AS smart_195_ecc_hardware_recuperado_normalizado,
    smart_196_raw AS smart_196_eventos_realocacao_bruto,
    smart_196_normalized AS smart_196_eventos_realocacao_normalizado,
    smart_197_raw AS smart_197_setores_pendentes_bruto,
    smart_197_normalized AS smart_197_setores_pendentes_normalizado,
    smart_198_raw AS smart_198_setores_incorrigiveis_offline_bruto,
    smart_198_normalized AS smart_198_setores_incorrigiveis_offline_normalizado,
    smart_199_raw AS smart_199_erros_crc_udma_bruto,
    smart_199_normalized AS smart_199_erros_crc_udma_normalizado,
    smart_200_raw AS smart_200_taxa_erros_multizona_bruto,
    smart_200_normalized AS smart_200_taxa_erros_multizona_normalizado,
    smart_220_raw AS smart_220_deslocamento_prato_bruto,
    smart_220_normalized AS smart_220_deslocamento_prato_normalizado,
    smart_222_raw AS smart_222_horas_carregado_bruto,
    smart_222_normalized AS smart_222_horas_carregado_normalizado,
    smart_223_raw AS smart_223_tentativas_carga_descarga_bruto,
    smart_223_normalized AS smart_223_tentativas_carga_descarga_normalizado,
    smart_224_raw AS smart_224_friccao_carga_bruto,
    smart_224_normalized AS smart_224_friccao_carga_normalizado,
    smart_226_raw AS smart_226_tempo_carga_bruto,
    smart_226_normalized AS smart_226_tempo_carga_normalizado,
    smart_231_raw AS smart_231_vida_restante_ssd_bruto,
    smart_231_normalized AS smart_231_vida_restante_ssd_normalizado,
    smart_240_raw AS smart_240_horas_voo_cabecote_bruto,
    smart_240_normalized AS smart_240_horas_voo_cabecote_normalizado,
    smart_241_raw AS smart_241_total_lbas_escritos_bruto,
    smart_241_normalized AS smart_241_total_lbas_escritos_normalizado,
    smart_242_raw AS smart_242_total_lbas_lidos_bruto,
    smart_242_normalized AS smart_242_total_lbas_lidos_normalizado

FROM padronizada
WHERE _ordem = 1;
GO
