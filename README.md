# Apoio decisório na gestão de datacenters

Projeto Integrador do 5º semestre (Senac). Pipeline ELT e data warehouse sobre o
[Backblaze Drive Stats](https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data):
registros diários de SMART e falhas de cerca de 350 mil discos, usados para analisar
confiabilidade por modelo e fabricante, fatores de risco (temperatura, idade, localização)
e sinais de falha iminente.

## Arquitetura

```
Backblaze Drive Stats (Apache Iceberg, S3 público)
   │  E: Python + DuckDB, snapshot mais recente, mês a mês, conciliado com o manifesto
   ▼
ADLS Gen2 /bronze             L: Parquet com os nomes originais da fonte
   │  T: Synapse serverless (SQL)
   ▼
ADLS Gen2 /silver → /gold
   │  carga do modelo dimensional
   ▼
Azure SQL Database (DW)       DDL, DML e operações OLAP
```

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `src/pi5/` | extração e carga (E e L) |
| `config/` | fonte de dados, datacenters e catálogo de fabricantes |
| `infra/` | provisionamento no Azure |
| `sql/` | transformações (Synapse), DDL e DML (Azure SQL) |
| `olap/` | consultas OLAP e evidências |
| `docs/` | documentação de apoio |
| `tests/` | testes automatizados |

## Fonte de dados

Tabela Iceberg pública mantida pela Backblaze, lida com as credenciais somente leitura que
ela mesma divulga (`config/fonte_dados.json`). Janela padrão: 2021-07 a 2026-06,
20 trimestres fechados e cerca de 493 milhões de linhas.

> Em construção: tecnologias, detalhamento técnico e instruções de execução.
