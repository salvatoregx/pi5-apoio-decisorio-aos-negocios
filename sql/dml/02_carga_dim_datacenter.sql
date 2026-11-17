-- ============================================================================
-- 02_carga_dim_datacenter.sql
--
-- Objetivo:
--   Carregar dim_datacenter com os 6 datacenters da Backblaze e o membro
--   'desconhecido'. Depois, acrescenta qualquer código que apareça na staging e
--   não esteja no JSON (com localização nula), para nenhuma fato ficar sem chave.
--
-- Origem dos dados:
--   config/datacenters.json (valores transcritos abaixo; a nota do JSON explica
--   que o mapeamento código → cidade foi inferido do código IATA) e, para
--   códigos novos, stg.disco e stg.fato_confiabilidade_mensal.
--
-- Onde executa:
--   Azure SQL Database, banco 'dw'. Pré-requisito: sql/ddl/03_dim_datacenter.sql.
--   Idempotente: MERGE pelo código do datacenter.
-- ============================================================================

MERGE dbo.dim_datacenter AS alvo
USING (VALUES
    ('sac0', N'Sacramento ou Stockton (não confirmado)', N'Califórnia', N'Estados Unidos', N'US West', 38.58, -121.49, 'America/Los_Angeles', N'incerta (Sacramento/Stockton)', NULL),
    ('sac2', N'Sacramento ou Stockton (não confirmado)', N'Califórnia', N'Estados Unidos', N'US West', 38.58, -121.49, 'America/Los_Angeles', N'incerta (Sacramento/Stockton)', NULL),
    ('phx1', N'Phoenix', N'Arizona', N'Estados Unidos', N'US West', 33.45, -112.07, 'America/Phoenix', N'inferida (código IATA)', NULL),
    ('iad1', N'Reston / Norte da Virgínia', N'Virgínia', N'Estados Unidos', N'US East', 38.96, -77.36, 'America/New_York', N'inferida (código IATA)', NULL),
    ('ams5', N'Amsterdã', N'Holanda do Norte', N'Países Baixos', N'EU Central', 52.37, 4.9, 'Europe/Amsterdam', N'inferida (código IATA)', NULL),
    ('yyz1', N'Toronto', N'Ontário', N'Canadá', N'CA East', 43.65, -79.38, 'America/Toronto', N'inferida (código IATA)', N'Região CA East inaugurada em jan/2025'),
    ('desconhecido', N'Não informado', NULL, NULL, NULL, NULL, NULL, NULL, N'sem localização', N'Discos sem nenhum registro de localização (saíram da frota antes de 2023)')
) AS origem (
    codigo_datacenter, cidade, estado_provincia, pais, regiao_backblaze,
    latitude, longitude, fuso_horario, confianca_localizacao, observacao
)
    ON alvo.codigo_datacenter = origem.codigo_datacenter
WHEN MATCHED THEN UPDATE SET
    alvo.cidade = origem.cidade,
    alvo.estado_provincia = origem.estado_provincia,
    alvo.pais = origem.pais,
    alvo.regiao_backblaze = origem.regiao_backblaze,
    alvo.latitude = origem.latitude,
    alvo.longitude = origem.longitude,
    alvo.fuso_horario = origem.fuso_horario,
    alvo.confianca_localizacao = origem.confianca_localizacao,
    alvo.observacao = origem.observacao
WHEN NOT MATCHED BY TARGET THEN INSERT (
    codigo_datacenter, cidade, estado_provincia, pais, regiao_backblaze,
    latitude, longitude, fuso_horario, confianca_localizacao, observacao
) VALUES (
    origem.codigo_datacenter, origem.cidade, origem.estado_provincia, origem.pais,
    origem.regiao_backblaze, origem.latitude, origem.longitude, origem.fuso_horario,
    origem.confianca_localizacao, origem.observacao
);
GO

-- Códigos presentes nos dados e ausentes do JSON (esperado: nenhum)
INSERT INTO dbo.dim_datacenter (codigo_datacenter, confianca_localizacao, observacao)
SELECT DISTINCT n.codigo, N'não mapeado', N'Código encontrado nos dados e ausente de config/datacenters.json'
FROM (
    SELECT ultimo_datacenter AS codigo FROM stg.disco WHERE ultimo_datacenter IS NOT NULL
    UNION
    SELECT datacenter FROM stg.fato_confiabilidade_mensal
    UNION
    SELECT datacenter FROM stg.fato_temperatura_dc_dia
) AS n
WHERE NULLIF(n.codigo, '') IS NOT NULL  -- vazio vai para 'desconhecido' nas cargas
  AND NOT EXISTS (SELECT 1 FROM dbo.dim_datacenter AS d WHERE d.codigo_datacenter = n.codigo);
GO

SELECT * FROM dbo.dim_datacenter ORDER BY sk_datacenter;
