-- ============================================================================
-- 10_carga_fato_temperatura_dc_dia.sql
--
-- Objetivo:
--   Carregar fato_temperatura_dc_dia (dia × datacenter efetivo × tipo de mídia).
--   Mantém a fato igual à staging: insere, atualiza e apaga (a fato é derivada
--   da gold por inteiro a cada execução).
--
-- Origem dos dados:
--   stg.fato_temperatura_dc_dia (cópia de lake/gold/fato_temperatura_dc_dia/) e as dimensões (troca de nomes e códigos pelas chaves).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisitos: sql/ddl/11_fato_temperatura_dc_dia.sql e as cargas
--   das dimensões (01 a 05). Idempotente: MERGE pela chave do grão (dia, datacenter, mídia).
--
-- temperatura_media é coluna calculada na tabela: não é carregada.
--
-- Datacenter vazio (''): parte dos dados da fonte traz o datacenter como texto
--   vazio, que a gold não imputou. Na carga ele vai para o membro 'desconhecido'
--   (cerca de 3% dos dias-disco). Limitação registrada em sql/README.md.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM stg.fato_temperatura_dc_dia)
    THROW 50041, 'stg.fato_temperatura_dc_dia está vazia: rode a cópia da gold antes da carga.', 1;

IF EXISTS (
    SELECT 1
    FROM stg.fato_temperatura_dc_dia AS f
    LEFT JOIN dbo.dim_calendario AS c ON c.data = f.data
    LEFT JOIN dbo.dim_datacenter AS dc ON dc.codigo_datacenter = COALESCE(NULLIF(f.datacenter, ''), 'desconhecido')
    WHERE c.id_data IS NULL OR dc.sk_datacenter IS NULL
)
    THROW 50042, 'stg.fato_temperatura_dc_dia tem dia ou datacenter sem correspondente nas dimensões.', 1;

-- As verificações acima ficam no mesmo lote do MERGE: se uma falhar, nada é gravado.
MERGE dbo.fato_temperatura_dc_dia AS alvo
USING (
    -- GROUP BY: datacenter vazio e 'desconhecido' caem na mesma chave e são somados.
    -- p50 e p95 não se somam: na linha combinada ficam os do grupo com mais leituras
    -- (aproximação que só afeta o membro 'desconhecido').
    SELECT
        id_data,
        sk_datacenter,
        tipo_midia,
        CAST(SUM(discos) AS INT) AS discos,
        CAST(SUM(discos_imputados) AS INT) AS discos_imputados,
        CAST(SUM(capacidade_tb_total) AS DECIMAL(12, 1)) AS capacidade_tb_total,
        SUM(soma_temperatura) AS soma_temperatura,
        CAST(SUM(contagem_temperatura) AS INT) AS contagem_temperatura,
        CAST(MAX(CASE WHEN ordem = 1 THEN temperatura_p50 END) AS SMALLINT) AS temperatura_p50,
        CAST(MAX(CASE WHEN ordem = 1 THEN temperatura_p95 END) AS SMALLINT) AS temperatura_p95,
        CAST(MAX(temperatura_max) AS SMALLINT) AS temperatura_max,
        CAST(SUM(falhas) AS INT) AS falhas
    FROM (
        SELECT
            c.id_data,
            dc.sk_datacenter,
            f.tipo_midia,
            f.discos,
            f.discos_imputados,
            f.capacidade_tb_total,
            f.soma_temperatura,
            f.contagem_temperatura,
            f.temperatura_p50,
            f.temperatura_p95,
            f.temperatura_max,
            f.falhas,
            ROW_NUMBER() OVER (
                PARTITION BY c.id_data, dc.sk_datacenter, f.tipo_midia
                ORDER BY f.contagem_temperatura DESC
            ) AS ordem
        FROM stg.fato_temperatura_dc_dia AS f
        JOIN dbo.dim_calendario AS c
            ON c.data = f.data
        JOIN dbo.dim_datacenter AS dc
            ON dc.codigo_datacenter = COALESCE(NULLIF(f.datacenter, ''), 'desconhecido')
    ) AS x
    GROUP BY id_data, sk_datacenter, tipo_midia
) AS origem
    ON alvo.id_data = origem.id_data
   AND alvo.sk_datacenter = origem.sk_datacenter
   AND alvo.tipo_midia = origem.tipo_midia
WHEN MATCHED THEN UPDATE SET
    alvo.discos = origem.discos,
    alvo.discos_imputados = origem.discos_imputados,
    alvo.capacidade_tb_total = origem.capacidade_tb_total,
    alvo.soma_temperatura = origem.soma_temperatura,
    alvo.contagem_temperatura = origem.contagem_temperatura,
    alvo.temperatura_p50 = origem.temperatura_p50,
    alvo.temperatura_p95 = origem.temperatura_p95,
    alvo.temperatura_max = origem.temperatura_max,
    alvo.falhas = origem.falhas
WHEN NOT MATCHED BY TARGET THEN INSERT (
    id_data, sk_datacenter, tipo_midia, discos, discos_imputados, capacidade_tb_total,
    soma_temperatura, contagem_temperatura, temperatura_p50, temperatura_p95, temperatura_max, falhas
) VALUES (
    origem.id_data, origem.sk_datacenter, origem.tipo_midia, origem.discos, origem.discos_imputados,
    origem.capacidade_tb_total, origem.soma_temperatura, origem.contagem_temperatura,
    origem.temperatura_p50, origem.temperatura_p95, origem.temperatura_max, origem.falhas
)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
GO

SELECT COUNT(*) AS linhas, SUM(CAST(discos AS BIGINT)) AS dias_disco, SUM(falhas) AS falhas
FROM dbo.fato_temperatura_dc_dia;
