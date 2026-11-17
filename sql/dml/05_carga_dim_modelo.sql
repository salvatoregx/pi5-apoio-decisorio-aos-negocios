-- ============================================================================
-- 05_carga_dim_modelo.sql
--
-- Objetivo:
--   Carregar dim_modelo a partir da staging. Atualiza os modelos que já existem
--   (a chave substituta sk_modelo não muda) e insere os novos. Modelos que saem
--   da staging não são apagados: podem estar referenciados por discos e fatos.
--
-- Origem dos dados:
--   stg.modelo (cópia de lake/gold/modelo/ pela atividade Copy do Synapse).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisito: sql/ddl/04_dim_modelo.sql.
--   Idempotente: MERGE pelo nome do modelo.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM stg.modelo)
    THROW 50001, 'stg.modelo está vazia: rode a cópia da gold antes da carga.', 1;

IF EXISTS (SELECT modelo FROM stg.modelo GROUP BY modelo HAVING COUNT(*) > 1)
    THROW 50002, 'stg.modelo tem modelo repetido: confira a gold (script 05 da gold).', 1;

-- As verificações acima ficam no mesmo lote do MERGE: se uma falhar, nada é gravado.
MERGE dbo.dim_modelo AS alvo
USING (
    SELECT
        modelo,
        fabricante,
        tipo_midia,
        funcao_disco,
        CAST(capacidade_tb AS DECIMAL(6, 1)) AS capacidade_tb,
        primeira_data,
        ultima_data,
        CAST(no_catalogo AS BIT) AS no_catalogo,
        familia_produto,
        tecnologia_gravacao,
        preenchimento,
        formato,
        rpm,
        interface,
        cache_mb,
        potencia_ociosa_w,
        potencia_operacao_w,
        criterio_potencia_operacao,
        temp_operacao_min_c,
        temp_operacao_max_c,
        mtbf_horas,
        afr_declarado_pct,
        carga_trabalho_tb_ano,
        CAST(garantia_anos AS TINYINT) AS garantia_anos,
        observacoes
    FROM stg.modelo
) AS origem
    ON alvo.modelo = origem.modelo
WHEN MATCHED THEN UPDATE SET
    alvo.fabricante = origem.fabricante,
    alvo.tipo_midia = origem.tipo_midia,
    alvo.funcao_disco = origem.funcao_disco,
    alvo.capacidade_tb = origem.capacidade_tb,
    alvo.primeira_data = origem.primeira_data,
    alvo.ultima_data = origem.ultima_data,
    alvo.no_catalogo = origem.no_catalogo,
    alvo.familia_produto = origem.familia_produto,
    alvo.tecnologia_gravacao = origem.tecnologia_gravacao,
    alvo.preenchimento = origem.preenchimento,
    alvo.formato = origem.formato,
    alvo.rpm = origem.rpm,
    alvo.interface = origem.interface,
    alvo.cache_mb = origem.cache_mb,
    alvo.potencia_ociosa_w = origem.potencia_ociosa_w,
    alvo.potencia_operacao_w = origem.potencia_operacao_w,
    alvo.criterio_potencia_operacao = origem.criterio_potencia_operacao,
    alvo.temp_operacao_min_c = origem.temp_operacao_min_c,
    alvo.temp_operacao_max_c = origem.temp_operacao_max_c,
    alvo.mtbf_horas = origem.mtbf_horas,
    alvo.afr_declarado_pct = origem.afr_declarado_pct,
    alvo.carga_trabalho_tb_ano = origem.carga_trabalho_tb_ano,
    alvo.garantia_anos = origem.garantia_anos,
    alvo.observacoes = origem.observacoes
WHEN NOT MATCHED BY TARGET THEN INSERT (
    modelo, fabricante, tipo_midia, funcao_disco, capacidade_tb, primeira_data, ultima_data,
    no_catalogo, familia_produto, tecnologia_gravacao, preenchimento, formato, rpm, interface,
    cache_mb, potencia_ociosa_w, potencia_operacao_w, criterio_potencia_operacao,
    temp_operacao_min_c, temp_operacao_max_c, mtbf_horas, afr_declarado_pct,
    carga_trabalho_tb_ano, garantia_anos, observacoes
) VALUES (
    origem.modelo, origem.fabricante, origem.tipo_midia, origem.funcao_disco, origem.capacidade_tb,
    origem.primeira_data, origem.ultima_data, origem.no_catalogo, origem.familia_produto,
    origem.tecnologia_gravacao, origem.preenchimento, origem.formato, origem.rpm, origem.interface,
    origem.cache_mb, origem.potencia_ociosa_w, origem.potencia_operacao_w,
    origem.criterio_potencia_operacao, origem.temp_operacao_min_c, origem.temp_operacao_max_c,
    origem.mtbf_horas, origem.afr_declarado_pct, origem.carga_trabalho_tb_ano,
    origem.garantia_anos, origem.observacoes
);
GO

SELECT fabricante, tipo_midia, COUNT(*) AS modelos, SUM(CAST(no_catalogo AS INT)) AS no_catalogo
FROM dbo.dim_modelo
GROUP BY fabricante, tipo_midia
ORDER BY fabricante, tipo_midia;
