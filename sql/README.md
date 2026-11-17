# sql

Scripts SQL do projeto, executados no Azure.

| Pasta | Conteúdo | Onde roda |
|---|---|---|
| `transformacao/silver/` | bronze → silver: renomeação, padronização, deduplicação | Synapse serverless |
| `transformacao/gold/` | silver → gold: agregações do modelo dimensional | Synapse serverless |
| `ddl/` | criação das tabelas do DW (dimensões, fatos, chaves) | Azure SQL Database |
| `dml/` | carga e manutenção das tabelas do DW | Azure SQL Database |

Convenções:

- Um objeto por arquivo, com prefixo numérico para a ordem de execução (`01_dim_calendario.sql`).
- Scripts idempotentes: rodar duas vezes não pode duplicar dados.
- Nomes em português, `snake_case`, sem acentos.

## Frente T2: gold, DDL e DML

### Modelo dimensional

| Tabela (Azure SQL `dw`) | Grão | Origem na gold (`lake/gold/`) |
|---|---|---|
| `dim_calendario` | dia (`id_data` = AAAAMMDD) | gerada no banco |
| `dim_datacenter` | datacenter (+ membro `desconhecido`) | `config/datacenters.json` |
| `dim_modelo` | modelo | `modelo/` (silver + `config/catalogo_fabricantes.csv`) |
| `dim_modelo_fonte` | modelo × URL | `modelo_fonte/` (`config/catalogo_fabricantes_fontes.csv`) |
| `dim_disco` | disco (número de série) | `disco/` |
| `dim_faixa_idade`, `dim_faixa_temperatura` | faixa | regras da silver enriquecida |
| `fato_confiabilidade_mensal` | mês × modelo × datacenter efetivo | `fato_confiabilidade_mensal/` |
| `fato_confiabilidade_faixas` | mês × modelo × faixa de idade × faixa de temperatura | `fato_confiabilidade_faixas/ano=*/` |
| `fato_temperatura_dc_dia` | dia × datacenter efetivo × tipo de mídia | `fato_temperatura_dc_dia/ano=*/` |

`fato_confiabilidade_faixas` e as duas dimensões de faixa são um acréscimo ao modelo da 1ª etapa: sem elas,
o AFR por idade (pergunta 5) e por temperatura (pergunta 2) só sairia de médias por disco.

Regras aplicadas:

- **AFR** = `100 × falhas / (dias_disco / 365)`, coluna calculada nas fatos. Ao reagregar, somar `falhas` e
  `dias_disco` e recalcular.
- **Datacenter efetivo** = `COALESCE(datacenter do dia, último datacenter conhecido do disco)`; sem nenhum,
  `desconhecido`. As fatos guardam quantos dias-disco foram imputados.
- **Chaves:** dimensões com chave substituta (`sk_*`, `IDENTITY`) e chave natural `UNIQUE`; o `MERGE` pela
  chave natural mantém a `sk_*` estável entre cargas. Fatos com PK no grão e FK para as dimensões.
- **Idempotência:** DDL com `IF OBJECT_ID(...) IS NULL`; DML com `MERGE` (as fatos também apagam o que saiu
  da staging). As verificações de cada carga ficam no mesmo lote do `MERGE`: se uma falha, nada é gravado.

### Ordem de execução

**0. Referência no lake (uma vez).** Copiar os dois CSVs do catálogo para `lake/referencia/`
(Synapse Studio → Data → Linked → `lake` → New folder `referencia` → Upload), ou pelo Cloud Shell:

```bash
for f in catalogo_fabricantes catalogo_fabricantes_fontes; do
  az storage fs file upload --account-name stpi538afc4 -f lake --auth-mode login \
    -s config/$f.csv -p referencia/$f.csv --overwrite
done
```

**1. Gold no Synapse** (`transformacao/gold/`, banco `pi5`), nesta ordem:

| Script | O que faz |
|---|---|
| `01_views_referencia_catalogo.sql` | views sobre os CSVs de `lake/referencia/` |
| `02_view_disco_mes.sql` | view intermediária disco × mês × datacenter do dia |
| `03_cetas_disco_mes.sql` | grava a view anterior, **um ano por bloco**, e cria a view `gold.disco_mes` |
| `04_cetas_disco.sql` | `gold.disco` (ciclo de vida e último datacenter) |
| `05_cetas_modelo.sql` | `gold.modelo` (com o catálogo) |
| `06_cetas_modelo_fonte.sql` | `gold.modelo_fonte` |
| `07_cetas_fato_confiabilidade_mensal.sql` | `gold.fato_confiabilidade_mensal` |
| `08_view_…` + `09_cetas_fato_confiabilidade_faixas.sql` | fato por faixas, um ano por bloco |
| `10_view_…` + `11_cetas_fato_temperatura_dc_dia.sql` | fato de temperatura, um ano por bloco |
| `90_conferencia_gold.sql` | totais entre bronze e gold |

Antes de materializar, teste cada view com um mês (`WHERE ano_mes = '2024-01'`). Ao rodar o primeiro ano do
script 03, confira em *Messages* o volume processado: deve ser uma fração da bronze, sinal de que o filtro por
`ano_mes` está podando as pastas. Para refazer uma CETAS, apague antes a pasta de destino no lake.

**2. DDL no Azure SQL** (`ddl/`, banco `dw`): `00` (só o administrador Entra do servidor, uma vez), depois
`01` a `11` e `20` a `25`. `99_remover_tabelas.sql` apaga tudo, para refazer do zero.

**3. Cópia da gold para a staging** (Synapse Pipelines, atividade Copy, sem código):

1. *Manage → Linked services → New → Azure SQL Database*: servidor `sql-pi5-38afc4`, banco `dw`,
   autenticação **System-assigned managed identity**. *Test connection* (depende do script `ddl/00`).
2. Para o lake, usar o linked service padrão do workspace se ele apontar para `stpi538afc4`; senão, criar um
   *Azure Data Lake Storage Gen2* com a mesma identidade.
3. *Integrate → + → Pipeline* `pl_gold_para_dw`, com uma atividade Copy por tabela:

   | Origem (Parquet, container `lake`, wildcard file `*.parquet`, *Recursively*) | Destino (pre-copy script) |
   |---|---|
   | `gold/modelo` | `stg.modelo` (`TRUNCATE TABLE stg.modelo`) |
   | `gold/modelo_fonte` | `stg.modelo_fonte` (`TRUNCATE TABLE stg.modelo_fonte`) |
   | `gold/disco` | `stg.disco` (`TRUNCATE TABLE stg.disco`) |
   | `gold/fato_confiabilidade_mensal` | `stg.fato_confiabilidade_mensal` (`TRUNCATE TABLE …`) |
   | `gold/fato_confiabilidade_faixas` | `stg.fato_confiabilidade_faixas` (`TRUNCATE TABLE …`) |
   | `gold/fato_temperatura_dc_dia` | `stg.fato_temperatura_dc_dia` (`TRUNCATE TABLE …`) |

   No destino: *Table option* = *None* (as tabelas já existem), *Write behavior* = *Insert*. Na aba
   *Mapping*, *Import schemas*: os nomes das colunas são iguais, o mapeamento é automático.
4. *Publish all* e *Add trigger → Trigger now*. Acompanhar em *Monitor*.

**4. DML no Azure SQL** (`dml/`, banco `dw`): `01` a `10`, nesta ordem, e `11_conferencia_dw.sql` para
conferir. Os totais de dias-disco e falhas precisam bater com `90_conferencia_gold.sql`.
Feche a conexão ao terminar: o banco gratuito só pausa 60 minutos depois da última conexão.
