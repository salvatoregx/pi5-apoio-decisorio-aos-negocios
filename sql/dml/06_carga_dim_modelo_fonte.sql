-- ============================================================================
-- 06_carga_dim_modelo_fonte.sql
--
-- Objetivo:
--   Carregar as fontes das especificações (modelo × URL). Mantém a tabela igual
--   à staging: insere, atualiza e apaga (nenhuma tabela depende desta).
--   Fontes de modelos que não aparecem nos dados da janela ficam de fora.
--
-- Origem dos dados:
--   stg.modelo_fonte (cópia de lake/gold/modelo_fonte/) e dbo.dim_modelo.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisitos: sql/ddl/05_dim_modelo_fonte.sql
--   e sql/dml/05_carga_dim_modelo.sql. Idempotente: MERGE por modelo × URL.
-- ============================================================================

MERGE dbo.dim_modelo_fonte AS alvo
USING (
    SELECT DISTINCT
        m.sk_modelo,
        f.url,
        f.titulo,
        f.tipo_fonte,
        f.campos,
        f.acessado_em
    FROM stg.modelo_fonte AS f
    JOIN dbo.dim_modelo AS m
        ON m.modelo = f.modelo
    WHERE f.url IS NOT NULL
) AS origem
    ON alvo.sk_modelo = origem.sk_modelo
   AND alvo.url = origem.url
WHEN MATCHED THEN UPDATE SET
    alvo.titulo = origem.titulo,
    alvo.tipo_fonte = origem.tipo_fonte,
    alvo.campos = origem.campos,
    alvo.acessado_em = origem.acessado_em
WHEN NOT MATCHED BY TARGET THEN INSERT (sk_modelo, url, titulo, tipo_fonte, campos, acessado_em)
    VALUES (origem.sk_modelo, origem.url, origem.titulo, origem.tipo_fonte, origem.campos, origem.acessado_em)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
GO

-- Fontes descartadas por não haver o modelo em dim_modelo (esperado: 0)
SELECT COUNT(*) AS fontes_sem_modelo
FROM stg.modelo_fonte AS f
WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_modelo AS m WHERE m.modelo = f.modelo);
