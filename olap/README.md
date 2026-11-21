# olap

Operações OLAP sobre o DW (Azure SQL Database).

- `consultas/`: uma consulta por arquivo, com prefixo de ordem e nome da operação
  (`01_rollup_afr_fabricante_modelo.sql`, `03_slice_afr_temperatura_2025.sql`). O `00` cria a view base
  e o `99` remove views antigas.
- `evidencias/`: resultado de cada consulta (CSV), com o mesmo nome do script.

Operações esperadas: roll-up, drill-down, slice, dice e pivot.
