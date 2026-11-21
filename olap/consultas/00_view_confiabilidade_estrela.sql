/* ============================================================================
   00_view_confiabilidade_estrela.sql

   Cria a view dbo.vw_confiabilidade_estrela: a fato de confiabilidade por
   faixas junto com as dimensões de calendário, modelo, idade e temperatura.
   Base das consultas OLAP por faixa (03 e 04). Só leitura: não altera tabelas.

   Onde executa: Azure SQL Database, banco dw (conectado direto no dw).

   Medidas:
     - Aditivas (podem ser somadas): dias_disco, falhas, soma/contagem de
       temperatura e de idade.
     - AFR % = 100 × SUM(falhas) × 365 / SUM(dias_disco). Sempre recalcular a
       partir das somas; nunca somar nem tirar média de afr_pct.
     - discos_distintos NÃO é aditivo (o mesmo disco aparece em vários meses e
       faixas). Para contar discos, usar dbo.dim_disco.
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
    c.data AS data_mes,
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
    m.funcao_disco,
    m.capacidade_tb,
    m.afr_declarado_pct,
    m.temp_operacao_max_c,

    -- Tempo de vida
    i.descricao AS faixa_idade,
    i.anos_min,
    i.anos_max,

    -- Temperatura
    t.descricao AS faixa_temperatura,
    t.temperatura_min_c,
    t.temperatura_max_c,
    t.estresse_termico,

    -- Medidas aditivas
    f.dias_disco,
    f.falhas,
    f.soma_temperatura,
    f.contagem_temperatura,
    f.soma_idade_anos,
    f.contagem_idade
FROM dbo.fato_confiabilidade_faixas AS f
JOIN dbo.dim_calendario AS c ON c.id_data = f.id_data_mes
JOIN dbo.dim_modelo AS m ON m.sk_modelo = f.sk_modelo
JOIN dbo.dim_faixa_idade AS i ON i.id_faixa_idade = f.id_faixa_idade
JOIN dbo.dim_faixa_temperatura AS t ON t.id_faixa_temperatura = f.id_faixa_temperatura;
GO

-- Conferência: a view precisa ter as mesmas linhas, falhas e dias-disco da fato.
SELECT
    (SELECT COUNT(*) FROM dbo.fato_confiabilidade_faixas) AS linhas_fato,
    (SELECT COUNT(*) FROM dbo.vw_confiabilidade_estrela) AS linhas_view,
    (SELECT SUM(falhas) FROM dbo.fato_confiabilidade_faixas) AS falhas_fato,
    (SELECT SUM(falhas) FROM dbo.vw_confiabilidade_estrela) AS falhas_view,
    (SELECT SUM(dias_disco) FROM dbo.fato_confiabilidade_faixas) AS dias_disco_fato,
    (SELECT SUM(dias_disco) FROM dbo.vw_confiabilidade_estrela) AS dias_disco_view;
