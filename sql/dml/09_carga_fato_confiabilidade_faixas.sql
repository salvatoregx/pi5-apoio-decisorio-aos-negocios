-- ============================================================================
-- 09_carga_fato_confiabilidade_faixas.sql
--
-- Objetivo:
--   Carregar fato_confiabilidade_faixas (mês × modelo × faixa de idade ×
--   faixa de temperatura).
--   Mantém a fato igual à staging: insere, atualiza e apaga (a fato é derivada
--   da gold por inteiro a cada execução).
--
-- Origem dos dados:
--   stg.fato_confiabilidade_faixas (cópia de lake/gold/fato_confiabilidade_faixas/) e as dimensões (troca de nomes e códigos pelas chaves).
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisitos: sql/ddl/10_fato_confiabilidade_faixas.sql e as cargas
--   das dimensões (01 a 05). Idempotente: MERGE pela chave do grão (mês, modelo, faixas).
--
-- afr_pct é coluna calculada na tabela: não é carregada.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM stg.fato_confiabilidade_faixas)
    THROW 50031, 'stg.fato_confiabilidade_faixas está vazia: rode a cópia da gold antes da carga.', 1;

IF EXISTS (
    SELECT 1
    FROM stg.fato_confiabilidade_faixas AS f
    LEFT JOIN dbo.dim_calendario AS c ON c.id_data = CAST(REPLACE(f.ano_mes, '-', '') + '01' AS INT)
    LEFT JOIN dbo.dim_modelo AS m ON m.modelo = f.modelo
    LEFT JOIN dbo.dim_faixa_idade AS fi ON fi.id_faixa_idade = f.id_faixa_idade
    LEFT JOIN dbo.dim_faixa_temperatura AS ft ON ft.id_faixa_temperatura = f.id_faixa_temperatura
    WHERE c.id_data IS NULL OR m.sk_modelo IS NULL
       OR fi.id_faixa_idade IS NULL OR ft.id_faixa_temperatura IS NULL
)
    THROW 50032, 'stg.fato_confiabilidade_faixas tem mês, modelo ou faixa sem correspondente nas dimensões.', 1;

-- As verificações acima ficam no mesmo lote do MERGE: se uma falhar, nada é gravado.
MERGE dbo.fato_confiabilidade_faixas AS alvo
USING (
    SELECT
        c.id_data AS id_data_mes,
        m.sk_modelo,
        CAST(f.id_faixa_idade AS TINYINT) AS id_faixa_idade,
        CAST(f.id_faixa_temperatura AS TINYINT) AS id_faixa_temperatura,
        f.dias_disco,
        CAST(f.falhas AS INT) AS falhas,
        CAST(f.discos_distintos AS INT) AS discos_distintos,
        f.soma_temperatura,
        f.contagem_temperatura,
        CAST(f.soma_idade_anos AS DECIMAL(18, 2)) AS soma_idade_anos,
        f.contagem_idade
    FROM stg.fato_confiabilidade_faixas AS f
    JOIN dbo.dim_calendario AS c
        ON c.id_data = CAST(REPLACE(f.ano_mes, '-', '') + '01' AS INT)
    JOIN dbo.dim_modelo AS m
        ON m.modelo = f.modelo
) AS origem
    ON alvo.id_data_mes = origem.id_data_mes
   AND alvo.sk_modelo = origem.sk_modelo
   AND alvo.id_faixa_idade = origem.id_faixa_idade
   AND alvo.id_faixa_temperatura = origem.id_faixa_temperatura
WHEN MATCHED THEN UPDATE SET
    alvo.dias_disco = origem.dias_disco,
    alvo.falhas = origem.falhas,
    alvo.discos_distintos = origem.discos_distintos,
    alvo.soma_temperatura = origem.soma_temperatura,
    alvo.contagem_temperatura = origem.contagem_temperatura,
    alvo.soma_idade_anos = origem.soma_idade_anos,
    alvo.contagem_idade = origem.contagem_idade
WHEN NOT MATCHED BY TARGET THEN INSERT (
    id_data_mes, sk_modelo, id_faixa_idade, id_faixa_temperatura, dias_disco, falhas,
    discos_distintos, soma_temperatura, contagem_temperatura, soma_idade_anos, contagem_idade
) VALUES (
    origem.id_data_mes, origem.sk_modelo, origem.id_faixa_idade, origem.id_faixa_temperatura,
    origem.dias_disco, origem.falhas, origem.discos_distintos, origem.soma_temperatura,
    origem.contagem_temperatura, origem.soma_idade_anos, origem.contagem_idade
)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
GO

SELECT COUNT(*) AS linhas, SUM(dias_disco) AS dias_disco, SUM(falhas) AS falhas
FROM dbo.fato_confiabilidade_faixas;
