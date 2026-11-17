-- ============================================================================
-- 07_carga_dim_disco.sql
--
-- Objetivo:
--   Carregar dim_disco a partir da staging, trocando o nome do modelo e o código
--   do último datacenter pelas chaves substitutas das dimensões. Disco sem
--   nenhum datacenter conhecido aponta para o membro 'desconhecido'.
--
-- Origem dos dados:
--   stg.disco (cópia de lake/gold/disco/), dbo.dim_modelo e dbo.dim_datacenter.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisitos: sql/ddl/06_dim_disco.sql,
--   sql/dml/02_carga_dim_datacenter.sql e sql/dml/05_carga_dim_modelo.sql.
--   Idempotente: MERGE pelo número de série.
--
-- Volume: ~400 mil linhas. Leva poucos minutos na oferta gratuita.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM stg.disco)
    THROW 50011, 'stg.disco está vazia: rode a cópia da gold antes da carga.', 1;

IF EXISTS (SELECT numero_serie FROM stg.disco GROUP BY numero_serie HAVING COUNT(*) > 1)
    THROW 50012, 'stg.disco tem número de série repetido: confira a gold (script 04 da gold).', 1;

IF EXISTS (
    SELECT 1
    FROM stg.disco AS d
    LEFT JOIN dbo.dim_modelo AS m ON m.modelo = d.modelo
    LEFT JOIN dbo.dim_datacenter AS dc ON dc.codigo_datacenter = COALESCE(d.ultimo_datacenter, 'desconhecido')
    WHERE m.sk_modelo IS NULL OR dc.sk_datacenter IS NULL
)
    THROW 50013, 'stg.disco tem modelo ou datacenter sem correspondente nas dimensões: rode as cargas 02 e 05 antes.', 1;

-- As verificações acima ficam no mesmo lote do MERGE: se uma falhar, nada é gravado.
MERGE dbo.dim_disco AS alvo
USING (
    SELECT
        d.numero_serie,
        m.sk_modelo,
        dc.sk_datacenter AS sk_datacenter_ultimo,
        d.primeira_data,
        d.ultima_data,
        CAST(d.dias_observados AS INT) AS dias_observados,
        CAST(d.falhou AS BIT) AS falhou,
        d.data_falha,
        d.situacao,
        CAST(d.censurado_esquerda AS BIT) AS censurado_esquerda,
        d.horas_inicial,
        d.horas_final,
        CAST(d.temperatura_media AS DECIMAL(5, 2)) AS temperatura_media,
        CAST(d.temperatura_max AS SMALLINT) AS temperatura_max,
        d.max_smart_005,
        d.max_smart_187,
        d.max_smart_188,
        d.max_smart_197,
        d.max_smart_198
    FROM stg.disco AS d
    JOIN dbo.dim_modelo AS m
        ON m.modelo = d.modelo
    JOIN dbo.dim_datacenter AS dc
        ON dc.codigo_datacenter = COALESCE(d.ultimo_datacenter, 'desconhecido')
) AS origem
    ON alvo.numero_serie = origem.numero_serie
WHEN MATCHED THEN UPDATE SET
    alvo.sk_modelo = origem.sk_modelo,
    alvo.sk_datacenter_ultimo = origem.sk_datacenter_ultimo,
    alvo.primeira_data = origem.primeira_data,
    alvo.ultima_data = origem.ultima_data,
    alvo.dias_observados = origem.dias_observados,
    alvo.falhou = origem.falhou,
    alvo.data_falha = origem.data_falha,
    alvo.situacao = origem.situacao,
    alvo.censurado_esquerda = origem.censurado_esquerda,
    alvo.horas_inicial = origem.horas_inicial,
    alvo.horas_final = origem.horas_final,
    alvo.temperatura_media = origem.temperatura_media,
    alvo.temperatura_max = origem.temperatura_max,
    alvo.max_smart_005 = origem.max_smart_005,
    alvo.max_smart_187 = origem.max_smart_187,
    alvo.max_smart_188 = origem.max_smart_188,
    alvo.max_smart_197 = origem.max_smart_197,
    alvo.max_smart_198 = origem.max_smart_198
WHEN NOT MATCHED BY TARGET THEN INSERT (
    numero_serie, sk_modelo, sk_datacenter_ultimo, primeira_data, ultima_data, dias_observados,
    falhou, data_falha, situacao, censurado_esquerda, horas_inicial, horas_final,
    temperatura_media, temperatura_max, max_smart_005, max_smart_187, max_smart_188,
    max_smart_197, max_smart_198
) VALUES (
    origem.numero_serie, origem.sk_modelo, origem.sk_datacenter_ultimo, origem.primeira_data,
    origem.ultima_data, origem.dias_observados, origem.falhou, origem.data_falha, origem.situacao,
    origem.censurado_esquerda, origem.horas_inicial, origem.horas_final, origem.temperatura_media,
    origem.temperatura_max, origem.max_smart_005, origem.max_smart_187, origem.max_smart_188,
    origem.max_smart_197, origem.max_smart_198
);
GO

SELECT situacao, COUNT(*) AS discos, SUM(CAST(dias_observados AS BIGINT)) AS dias_disco
FROM dbo.dim_disco
GROUP BY situacao;
