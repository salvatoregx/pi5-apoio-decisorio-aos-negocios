# Apoio decisório na gestão de datacenters

Projeto Integrador do 5º semestre (Senac). Pipeline ELT e data warehouse sobre o
[Backblaze Drive Stats](https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data):
registros diários de SMART e falhas de cerca de 350 mil discos, usados para analisar
confiabilidade por modelo e fabricante, fatores de risco (temperatura, idade, localização)
e sinais de falha iminente.

## Arquitetura

```
Backblaze Drive Stats (Apache Iceberg, S3 público da Backblaze)
   │  E + L: Python + DuckDB num contêiner do Azure Container Instances
   │         snapshot mais recente, 4 meses em paralelo, conciliação com o manifesto
   ▼
ADLS Gen2  lake/bronze/drivestats/      Parquet com os nomes originais da fonte
   │  T: Synapse Analytics, pool SQL serverless
   ▼
ADLS Gen2  lake/silver/  →  lake/gold/  dados limpos → agregados do modelo dimensional
   │  carga
   ▼
Azure SQL Database  dw                   DDL, DML e operações OLAP
```

Todos os recursos ficam no grupo `rg-pi5`, região Brazil South, numa assinatura Azure for Students.

## Tecnologias

| Tecnologia | Uso | Por quê |
|---|---|---|
| Python 3.12 + [uv](https://docs.astral.sh/uv/) | código da extração e carga | dependências travadas em `uv.lock`, ambiente reproduzível |
| DuckDB (extensões `iceberg` e `httpfs`) | leitura da tabela Iceberg e gravação em Parquet | lê Iceberg direto do S3 da Backblaze, que o Synapse não lê; roda dentro do processo, sem servidor |
| Azure Container Instances | execução da extração na nuvem | contêiner sob demanda, cobrado só enquanto roda; não depende da máquina de ninguém |
| ADLS Gen2 | data lake (bronze, silver, gold) | armazenamento hierárquico barato, lido nativamente pelo Synapse |
| Synapse Analytics (serverless) | transformação em SQL sobre o lake | cobrado por volume lido, sem cluster ligado |
| Azure SQL Database (oferta gratuita) | data warehouse | T-SQL completo para DDL, DML e OLAP, sem custo dentro da cota mensal |
| Microsoft Entra ID + identidades gerenciadas | autenticação | nenhuma senha ou chave no código; acesso por papel (RBAC) |
| az CLI + Bash | provisionamento | scripts idempotentes em `infra/` |
| GitHub Actions, ruff, pytest | qualidade | lint, formatação e testes a cada push e pull request |

## Fonte de dados

Tabela Apache Iceberg pública mantida pela Backblaze, no bucket `drivestats-iceberg`, lida com as
credenciais **somente leitura** que a própria Backblaze divulga (`config/fonte_dados.json`).
Documentação da fonte: <https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data>.

- **Janela:** 2021-07 a 2026-06, 20 trimestres fechados.
- **Volume carregado:** **493.160.806 linhas** em 60 meses, conferidas mês a mês com o manifesto do
  snapshot `00262` da tabela.
- **Limitações:** os campos de localização (`datacenter`, `cluster_id`, `vault_id`, `pod_id`) só existem
  a partir de 2023. Discos que já operavam em 2021-07 têm vida anterior não observada (censura à
  esquerda); o SMART 9 (horas ligado) permite estimar a idade.

## Extração e carga (E e L)

O pacote `drivestats_el` (em `src/drivestats_el/`) copia a tabela Iceberg para a camada bronze, mês a mês.

1. **Snapshot e contagem.** Localiza o metadata.json mais recente da tabela e soma as linhas por mês
   no manifesto, ignorando arquivos marcados como removidos.
2. **Extração.** Cada mês é lido em fatias de 7 dias (um Parquet por fatia, compressão zstd), para
   limitar a memória. Entram as colunas de identificação e os 44 atributos SMART com pelo menos 1% de
   preenchimento na janela (`src/drivestats_el/catalogo_smart.py`), com os nomes originais da fonte.
3. **Carga.** As fatias do mês substituem o conteúdo da pasta `ano_mes=AAAA-MM` no lake.
4. **Conciliação.** Linhas gravadas devem ser iguais às do manifesto. O resultado fica em
   `_controle/AAAA-MM.json`, no próprio lake: status, snapshot, linhas, bytes e duração.
5. **Retomada.** Um mês só é refeito se não estiver no destino, se falhou na conciliação ou se a
   contagem na fonte mudou. Interromper e rodar de novo continua de onde parou.

Vários meses rodam ao mesmo tempo (`--paralelo`), cada um num processo com a própria conexão DuckDB.
Com 4 em paralelo, num contêiner de 4 vCPU e 16 GB, a janela completa levou 25 minutos.

Estrutura da bronze:

```
lake/bronze/drivestats/
├── ano_mes=2021-07/parte_01.parquet ... parte_29.parquet
├── ...
├── ano_mes=2026-06/...
└── _controle/2021-07.json ... 2026-06.json
```

## Transformação (T)

> A cargo da frente de transformação: regras da silver, agregações da gold e scripts em `sql/transformacao/`.

## Data warehouse: DDL e DML

> A cargo da frente do modelo dimensional: scripts em `sql/ddl/` e `sql/dml/`.

## Operações OLAP

> A cargo da frente de OLAP: consultas em `olap/consultas/` e evidências em `olap/evidencias/`.

## Como executar

### Ambiente no Azure

No [Cloud Shell](https://shell.azure.com), já autenticado:

```bash
git clone https://github.com/salvatoregx/pi5-apoio-decisorio-aos-negocios
cd pi5-apoio-decisorio-aos-negocios
bash infra/provisionar.sh        # lake, Synapse, Azure SQL e orçamento
bash infra/extrair_no_azure.sh   # extração da janela completa para o lake
```

Detalhes, região e decisões de segurança: [`infra/README.md`](infra/README.md).

### Extração local

```bash
uv sync
uv run drivestats extrair --inicio 2021-07 --fim 2021-09 --destino local   # grava em data/bronze
uv run drivestats status --destino local
```

Com `PI5_ADLS_CONTA` definida e `az login` feito, o destino padrão passa a ser o lake.
`uv run drivestats --help` lista as opções e as variáveis de ambiente.

### Testes

```bash
uv run ruff check && uv run ruff format --check && uv run pytest
```

Os testes não acessam rede nem o Azure: a fonte é simulada com arquivos Parquet gerados no próprio teste.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `src/drivestats_el/` | extração e carga (E e L) |
| `tests/` | testes automatizados |
| `config/` | fonte de dados, datacenters e catálogo de fabricantes |
| `infra/` | provisionamento e extração no Azure |
| `sql/` | transformações (Synapse), DDL e DML (Azure SQL) |
| `olap/` | consultas OLAP e evidências |
| `docs/` | documentação de apoio |
| `.github/` | CI, template de pull request e responsáveis por pasta |
