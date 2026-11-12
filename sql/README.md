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
