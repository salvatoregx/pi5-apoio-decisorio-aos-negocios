# olap

Operações OLAP sobre o DW (Azure SQL Database).

- `consultas/`: uma consulta por arquivo, nomeada pela operação e pela pergunta de negócio
  (`rollup_afr_fabricante_ano.sql`, `slice_temperatura_datacenter.sql`).
- `evidencias/`: resultado de cada consulta (CSV) e captura de tela da execução.

Operações esperadas: roll-up, drill-down, slice, dice e pivot.
