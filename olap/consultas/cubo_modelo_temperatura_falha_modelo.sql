/* ============================================================================
   OLAP CONFIABILIDADE DE DISCOS
   Modelo × Tempo de Vida × Falhas × Temperatura
   ----------------------------------------------------------------------------
   Cria : 1 view (read-only) — não altera nenhuma tabela existente
   Lê   : fato_confiabilidade_faixas + 4 dimensões
   Medida canônica: falhas_por_disco_ano = SUM(falhas) * 365 / SUM(dias_disco)
   ============================================================================ */

USE [dw];   -- <<< ajuste se necessário
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO


/* ============================================================================
   1. VIEW ESTRELA (única criação — apenas SELECT encapsulado)
   ============================================================================ */
CREATE OR ALTER VIEW dbo.vw_confiabilidade_estrela
AS
SELECT
    -- Chaves
    f.id_data_mes,
    f.sk_modelo,
    f.id_faixa_idade,
    f.id_faixa_temperatura,

    -- Tempo
    c.data          AS data_mes,
    c.ano,
    c.semestre,
    c.trimestre,
    c.mes,
    c.nome_mes,
    c.ano_mes,
    c.ano_trimestre,

    -- Produto
    m.fabricante,
    m.familia_produto,
    m.modelo,
    m.tipo_midia,
    m.capacidade_tb,
    m.afr_declarado_pct,
    m.temp_operacao_max_c,

    -- Tempo de vida
    i.descricao     AS faixa_idade,
    i.anos_min,
    i.anos_max,

    -- Temperatura
    t.descricao     AS faixa_temperatura,
    t.temperatura_min_c,
    t.temperatura_max_c,
    t.estresse_termico,

    -- Medidas base (aditivas — somar sempre que precisar)
    f.dias_disco,
    f.falhas,
    f.discos_distintos,
    f.soma_temperatura,
    f.contagem_temperatura,
    f.soma_idade_anos,
    f.contagem_idade,

    -- Medida pré-calculada da origem (NÃO somar; preferir recalcular)
    f.afr_pct
FROM dbo.fato_confiabilidade_faixas f
LEFT JOIN dbo.dim_calendario         c ON c.id_data              = f.id_data_mes
LEFT JOIN dbo.dim_modelo             m ON m.sk_modelo            = f.sk_modelo
LEFT JOIN dbo.dim_faixa_idade        i ON i.id_faixa_idade       = f.id_faixa_idade
LEFT JOIN dbo.dim_faixa_temperatura  t ON t.id_faixa_temperatura = f.id_faixa_temperatura;
GO


/* ============================================================================
   VALIDAÇÃO RÁPIDA (rode primeiro — deve retornar os mesmos números)
   ============================================================================ */
SELECT
    (SELECT COUNT(*) FROM dbo.fato_confiabilidade_faixas)      AS linhas_fato,
    (SELECT COUNT(*) FROM dbo.vw_confiabilidade_estrela)       AS linhas_view,
    (SELECT SUM(falhas) FROM dbo.fato_confiabilidade_faixas)   AS falhas_fato,
    (SELECT SUM(falhas) FROM dbo.vw_confiabilidade_estrela)    AS falhas_view,
    (SELECT SUM(dias_disco) FROM dbo.fato_confiabilidade_faixas) AS dias_fato,
    (SELECT SUM(dias_disco) FROM dbo.vw_confiabilidade_estrela)  AS dias_view;
GO
-- Esperado: linhas_fato = linhas_view | falhas_fato = falhas_view | dias_fato = dias_view


/* ============================================================================
   2. PIVOT: Faixa de Idade × Faixa de Temperatura (todos os tempos)
   → identifica o "joelho" de falha: idade alta + temperatura alta
   ============================================================================ */
SELECT
    faixa_idade,
    anos_min,
    faixa_temperatura,
    temperatura_min_c,
    estresse_termico,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    SUM(discos_distintos)                                             AS discos,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano,
    CAST(SUM(soma_temperatura) * 1.0 / NULLIF(SUM(contagem_temperatura),0)
        AS DECIMAL(10,2))                                             AS temperatura_media_c,
    CAST(SUM(soma_idade_anos) * 1.0 / NULLIF(SUM(contagem_idade),0)
        AS DECIMAL(10,2))                                             AS idade_media_anos
FROM dbo.vw_confiabilidade_estrela
GROUP BY faixa_idade, anos_min, faixa_temperatura, temperatura_min_c, estresse_termico
ORDER BY anos_min, temperatura_min_c;
GO


/* ============================================================================
   3. RANKING: Modelos por confiabilidade (todos os tempos)
   ============================================================================ */
SELECT
    fabricante,
    modelo,
    tipo_midia,
    capacidade_tb,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    SUM(discos_distintos)                                             AS discos,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano,
    CAST(SUM(soma_temperatura) * 1.0 / NULLIF(SUM(contagem_temperatura),0)
        AS DECIMAL(10,2))                                             AS temperatura_media_c,
    CAST(SUM(soma_idade_anos) * 1.0 / NULLIF(SUM(contagem_idade),0)
        AS DECIMAL(10,2))                                             AS idade_media_anos
FROM dbo.vw_confiabilidade_estrela
GROUP BY fabricante, modelo, tipo_midia, capacidade_tb
ORDER BY falhas_por_disco_ano DESC;
GO


/* ============================================================================
   4. DRILL-DOWN: Modelo → Faixa de Idade → Faixa de Temperatura (ano 2024)
   ============================================================================ */
SELECT
    fabricante,
    modelo,
    faixa_idade,
    faixa_temperatura,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano
FROM dbo.vw_confiabilidade_estrela
WHERE ano = 2024
GROUP BY fabricante, modelo, faixa_idade, anos_min, faixa_temperatura, temperatura_min_c
ORDER BY modelo, anos_min, temperatura_min_c;
GO


/* ============================================================================
   5. COMPARAÇÃO ANUAL (YOY) por modelo
   ============================================================================ */
SELECT
    fabricante,
    modelo,
    ano,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano
FROM dbo.vw_confiabilidade_estrela
WHERE ano BETWEEN 2022 AND 2024
GROUP BY fabricante, modelo, ano
ORDER BY modelo, ano;
GO


/* ============================================================================
   6. EVOLUÇÃO MENSAL (ano 2024)
   ============================================================================ */
SELECT
    fabricante,
    modelo,
    mes,
    nome_mes,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano
FROM dbo.vw_confiabilidade_estrela
WHERE ano = 2024
GROUP BY fabricante, modelo, mes, nome_mes
ORDER BY modelo, mes;
GO


/* ============================================================================
   7. ROLL-UP: Fabricante × Ano (agregação hierárquica)
   ============================================================================ */
SELECT
    fabricante,
    ano,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    SUM(discos_distintos)                                             AS discos,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano
FROM dbo.vw_confiabilidade_estrela
GROUP BY fabricante, ano
ORDER BY fabricante, ano;
GO


/* ============================================================================
   8. CUBO COMPLETO EM 1 QUERY (todos os níveis via GROUPING SETS)
   → simula um cubo OLAP sem materializar nada
   ============================================================================ */
SELECT
    CASE
        WHEN GROUPING(id_data_mes)=0 AND GROUPING(sk_modelo)=0
         AND GROUPING(id_faixa_idade)=0 AND GROUPING(id_faixa_temperatura)=0
            THEN 'MES_MDL_IDD_TMP'
        WHEN GROUPING(id_data_mes)=0 AND GROUPING(sk_modelo)=0
         AND GROUPING(id_faixa_idade)=0 THEN 'MES_MDL_IDD'
        WHEN GROUPING(id_data_mes)=0 AND GROUPING(sk_modelo)=0 THEN 'MES_MDL'
        WHEN GROUPING(id_data_mes)=0 THEN 'MES'
        WHEN GROUPING(sk_modelo)=0 AND GROUPING(id_faixa_idade)=0
         AND GROUPING(id_faixa_temperatura)=0 THEN 'MDL_IDD_TMP'
        WHEN GROUPING(sk_modelo)=0 THEN 'MDL'
        WHEN GROUPING(id_faixa_idade)=0 AND GROUPING(id_faixa_temperatura)=0 THEN 'IDD_TMP'
        ELSE 'TOTAL'
    END AS nivel,
    COALESCE(ano,              0 ) AS ano,
    COALESCE(fabricante,      '—') AS fabricante,
    COALESCE(faixa_idade,     '—') AS faixa_idade,
    COALESCE(faixa_temperatura,'—') AS faixa_temperatura,
    SUM(falhas)                                                       AS falhas,
    SUM(dias_disco)                                                   AS dias_disco,
    CAST(SUM(falhas) * 365.0 / NULLIF(SUM(dias_disco),0) AS DECIMAL(10,4))
        AS falhas_por_disco_ano
FROM dbo.vw_confiabilidade_estrela
GROUP BY GROUPING SETS (
    (id_data_mes, sk_modelo, id_faixa_idade, id_faixa_temperatura),  -- grão completo
    (id_data_mes, sk_modelo, id_faixa_idade),                        -- agrega temperatura
    (id_data_mes, sk_modelo),                                        -- agrega idade
    (id_data_mes),                                                   -- só mês
    (sk_modelo, id_faixa_idade, id_faixa_temperatura),               -- sem tempo
    (sk_modelo),                                                     -- só modelo
    (id_faixa_idade, id_faixa_temperatura),                          -- só idade × temp
    ()                                                               -- total global
);
GO