-- ============================================================================
-- 08_carga_fato_confiabilidade_mensal.sql
--
-- Objetivo:
--   Carregar fato_confiabilidade_mensal (mês × modelo × datacenter efetivo).
--   Mantém a fato igual à staging: insere, atualiza e apaga (a fato é derivada
--   da gold por inteiro a cada execução).
--
-- Origem dos dados:
--   stg.fato_confiabilidade_mensal (cópia de lake/gold/fato_confiabilidade_mensal/) e as dimensões (troca de nomes e códigos pelas chaves).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisitos: sql/ddl/09_fato_confiabilidade_mensal.sql e as cargas
--   das dimensões (01 a 05). Idempotente: MERGE pela chave do grão (mês, modelo, datacenter).
--
-- afr_pct e temperatura_media são colunas calculadas na tabela: não são carregadas.
--
-- Datacenter vazio (''): parte dos dados da fonte traz o datacenter como texto
--   vazio, que a gold não imputou. Na carga ele vai para o membro 'desconhecido'
--   (cerca de 3% dos dias-disco). Limitação registrada em sql/README.md.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM stg.fato_confiabilidade_mensal)
    THROW 50021, 'stg.fato_confiabilidade_mensal está vazia: rode a cópia da gold antes da carga.', 1;

IF EXISTS (
    SELECT 1
    FROM stg.fato_confiabilidade_mensal AS f
    LEFT JOIN dbo.dim_calendario AS c ON c.id_data = CAST(REPLACE(f.ano_mes, '-', '') + '01' AS INT)
    LEFT JOIN dbo.dim_modelo AS m ON m.modelo = f.modelo
    LEFT JOIN dbo.dim_datacenter AS dc ON dc.codigo_datacenter = COALESCE(NULLIF(f.datacenter, ''), 'desconhecido')
    WHERE c.id_data IS NULL OR m.sk_modelo IS NULL OR dc.sk_datacenter IS NULL
)
    THROW 50022, 'stg.fato_confiabilidade_mensal tem mês, modelo ou datacenter sem correspondente nas dimensões.', 1;

-- As verificações acima ficam no mesmo lote do MERGE: se uma falhar, nada é gravado.
MERGE dbo.fato_confiabilidade_mensal AS alvo
USING (
    -- GROUP BY: datacenter vazio e 'desconhecido' caem na mesma chave e são somados.
    -- Os discos dos dois grupos são distintos (disco com vazio tem último datacenter
    -- não nulo), então somar discos_distintos continua exato.
    SELECT
        c.id_data AS id_data_mes,
        m.sk_modelo,
        dc.sk_datacenter,
        SUM(f.dias_disco) AS dias_disco,
        SUM(f.dias_disco_imputados) AS dias_disco_imputados,
        CAST(SUM(f.falhas) AS INT) AS falhas,
        CAST(SUM(f.discos_distintos) AS INT) AS discos_distintos,
        CAST(SUM(f.tb_dias) AS DECIMAL(18, 1)) AS tb_dias,
        SUM(f.soma_temperatura) AS soma_temperatura,
        SUM(f.contagem_temperatura) AS contagem_temperatura
    FROM stg.fato_confiabilidade_mensal AS f
    JOIN dbo.dim_calendario AS c
        ON c.id_data = CAST(REPLACE(f.ano_mes, '-', '') + '01' AS INT)
    JOIN dbo.dim_modelo AS m
        ON m.modelo = f.modelo
    JOIN dbo.dim_datacenter AS dc
        ON dc.codigo_datacenter = COALESCE(NULLIF(f.datacenter, ''), 'desconhecido')
    GROUP BY c.id_data, m.sk_modelo, dc.sk_datacenter
) AS origem
    ON alvo.id_data_mes = origem.id_data_mes
   AND alvo.sk_modelo = origem.sk_modelo
   AND alvo.sk_datacenter = origem.sk_datacenter
WHEN MATCHED THEN UPDATE SET
    alvo.dias_disco = origem.dias_disco,
    alvo.dias_disco_imputados = origem.dias_disco_imputados,
    alvo.falhas = origem.falhas,
    alvo.discos_distintos = origem.discos_distintos,
    alvo.tb_dias = origem.tb_dias,
    alvo.soma_temperatura = origem.soma_temperatura,
    alvo.contagem_temperatura = origem.contagem_temperatura
WHEN NOT MATCHED BY TARGET THEN INSERT (
    id_data_mes, sk_modelo, sk_datacenter, dias_disco, dias_disco_imputados, falhas,
    discos_distintos, tb_dias, soma_temperatura, contagem_temperatura
) VALUES (
    origem.id_data_mes, origem.sk_modelo, origem.sk_datacenter, origem.dias_disco,
    origem.dias_disco_imputados, origem.falhas, origem.discos_distintos, origem.tb_dias,
    origem.soma_temperatura, origem.contagem_temperatura
)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
GO

SELECT COUNT(*) AS linhas, SUM(dias_disco) AS dias_disco, SUM(falhas) AS falhas,
       CAST(100.0 * SUM(falhas) * 365 / SUM(dias_disco) AS DECIMAL(9, 4)) AS afr_pct_geral
FROM dbo.fato_confiabilidade_mensal;
