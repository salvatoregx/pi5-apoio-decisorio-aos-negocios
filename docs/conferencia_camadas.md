# Conferência entre as camadas

Executada em 20/11/2026. Confere se os dias-disco (linhas da fonte) e as falhas chegam iguais da bronze até o
data warehouse. Resumo e interpretação no [README](../README.md#conferência-entre-as-camadas).

| Parte | Onde roda | Script |
|---|---|---|
| 1. Bronze × gold | Synapse serverless, banco `pi5` | [`90_conferencia_gold.sql`](../sql/transformacao/gold/90_conferencia_gold.sql) |
| 2. Staging × DW | Azure SQL, banco `dw` | [`11_conferencia_dw.sql`](../sql/dml/11_conferencia_dw.sql) |

## 1. Bronze × gold (Synapse)

### Totais por tabela

| Tabela | Dias-disco | Falhas |
|---|---:|---:|
| `bronze.drivestats` | 493.160.806 | 20.310 |
| `gold.disco_mes` | 493.160.806 | 20.310 |
| `gold.modelo` | 493.160.806 | 20.310 |
| `gold.fato_confiabilidade_mensal` | 493.160.806 | 20.310 |
| `gold.fato_confiabilidade_faixas` | 493.160.806 | 20.310 |
| `gold.fato_temperatura_dc_dia` | 493.160.806 | 20.310 |

Todas as tabelas da gold têm os mesmos totais da bronze. Como a gold é calculada a partir da silver, a
silver não descartou nenhuma linha (zero duplicatas).

### Mês a mês: bronze × `fato_confiabilidade_mensal`

| Mês | Linhas na bronze | Dias-disco na fato | Diferença |
|---|---:|---:|---:|
| 2021-07 | 5.690.135 | 5.690.135 | 0 |
| 2021-08 | 5.889.156 | 5.889.156 | 0 |
| 2021-09 | 5.815.930 | 5.815.930 | 0 |
| 2021-10 | 6.070.194 | 6.070.194 | 0 |
| 2021-11 | 5.965.879 | 5.965.879 | 0 |
| 2021-12 | 6.349.182 | 6.349.182 | 0 |
| 2022-01 | 6.415.842 | 6.415.842 | 0 |
| 2022-02 | 5.866.755 | 5.866.755 | 0 |
| 2022-03 | 6.562.663 | 6.562.663 | 0 |
| 2022-04 | 6.394.694 | 6.394.694 | 0 |
| 2022-05 | 6.669.850 | 6.669.850 | 0 |
| 2022-06 | 6.359.892 | 6.359.892 | 0 |
| 2022-07 | 6.820.847 | 6.820.847 | 0 |
| 2022-08 | 6.953.231 | 6.953.231 | 0 |
| 2022-09 | 6.817.679 | 6.817.679 | 0 |
| 2022-10 | 7.182.806 | 7.182.806 | 0 |
| 2022-11 | 7.012.134 | 7.012.134 | 0 |
| 2022-12 | 7.301.369 | 7.301.369 | 0 |
| 2023-01 | 7.346.169 | 7.346.169 | 0 |
| 2023-02 | 6.708.061 | 6.708.061 | 0 |
| 2023-03 | 7.400.762 | 7.400.762 | 0 |
| 2023-04 | 6.916.853 | 6.916.853 | 0 |
| 2023-05 | 7.546.065 | 7.546.065 | 0 |
| 2023-06 | 7.372.238 | 7.372.238 | 0 |
| 2023-07 | 7.698.485 | 7.698.485 | 0 |
| 2023-08 | 8.056.700 | 8.056.700 | 0 |
| 2023-09 | 7.846.801 | 7.846.801 | 0 |
| 2023-10 | 8.291.842 | 8.291.842 | 0 |
| 2023-11 | 8.139.112 | 8.139.112 | 0 |
| 2023-12 | 8.360.045 | 8.360.045 | 0 |
| 2024-01 | 8.466.958 | 8.466.958 | 0 |
| 2024-02 | 8.008.837 | 8.008.837 | 0 |
| 2024-03 | 8.713.418 | 8.713.418 | 0 |
| 2024-04 | 8.557.813 | 8.557.813 | 0 |
| 2024-05 | 8.854.571 | 8.854.571 | 0 |
| 2024-06 | 8.609.885 | 8.609.885 | 0 |
| 2024-07 | 9.004.260 | 9.004.260 | 0 |
| 2024-08 | 9.038.446 | 9.038.446 | 0 |
| 2024-09 | 8.780.281 | 8.780.281 | 0 |
| 2024-10 | 9.083.537 | 9.083.537 | 0 |
| 2024-11 | 8.888.459 | 8.888.459 | 0 |
| 2024-12 | 9.373.296 | 9.373.296 | 0 |
| 2025-01 | 9.458.440 | 9.458.440 | 0 |
| 2025-02 | 8.663.739 | 8.663.739 | 0 |
| 2025-03 | 9.677.807 | 9.677.807 | 0 |
| 2025-04 | 9.428.618 | 9.428.618 | 0 |
| 2025-05 | 9.760.643 | 9.760.643 | 0 |
| 2025-06 | 9.618.781 | 9.618.781 | 0 |
| 2025-07 | 9.992.627 | 9.992.627 | 0 |
| 2025-08 | 10.043.800 | 10.043.800 | 0 |
| 2025-09 | 9.808.024 | 9.808.024 | 0 |
| 2025-10 | 10.348.017 | 10.348.017 | 0 |
| 2025-11 | 10.105.084 | 10.105.084 | 0 |
| 2025-12 | 10.488.607 | 10.488.607 | 0 |
| 2026-01 | 10.463.270 | 10.463.270 | 0 |
| 2026-02 | 9.483.733 | 9.483.733 | 0 |
| 2026-03 | 10.650.481 | 10.650.481 | 0 |
| 2026-04 | 10.430.946 | 10.430.946 | 0 |
| 2026-05 | 10.899.825 | 10.899.825 | 0 |
| 2026-06 | 10.637.232 | 10.637.232 | 0 |
| **Total (60 meses)** | **493.160.806** | **493.160.806** | **0** |

### Localização por ano (datacenter imputado e sem local)

| Ano | Dias-disco | Imputados (último datacenter conhecido) | % imputado | Sem nenhum local | % sem local |
|---|---:|---:|---:|---:|---:|
| 2021 | 35.780.476 | 35.780.476 | 100,00% | 1.325.734 | 3,71% |
| 2022 | 80.357.762 | 80.357.762 | 100,00% | 1.773.219 | 2,21% |
| 2023 | 91.683.133 | 43.290.148 | 47,22% | 318.500 | 0,35% |
| 2024 | 105.379.761 | 0 | 0,00% | 0 | 0,00% |
| 2025 | 117.394.187 | 0 | 0,00% | 0 | 0,00% |
| 2026 | 62.565.487 | 0 | 0,00% | 0 | 0,00% |

A localização só existe na fonte a partir de 2023. Os dias-disco sem nenhum local são de discos que saíram
da frota antes disso (viés de sobrevivência). Esta contagem é da gold; o datacenter vazio da fonte só vai
para `desconhecido` na carga do DW (ver README, Limitações).

## 2. Staging × DW (Azure SQL)

### Linhas na staging e nas tabelas finais

| Tabela | Linhas na staging | Linhas no DW |
|---|---:|---:|
| `dim_modelo` | 100 | 100 |
| `dim_disco` | 419.891 | 419.891 |
| `fato_confiabilidade_mensal` | 10.763 | 10.366 |
| `fato_confiabilidade_faixas` | 47.258 | 47.258 |
| `fato_temperatura_dc_dia` | 20.180 | 18.722 |

A `fato_confiabilidade_mensal` e a `fato_temperatura_dc_dia` ficam com menos linhas no DW porque a carga
junta o datacenter vazio da fonte e o `desconhecido` na mesma chave (`GROUP BY` antes do `MERGE`). Os totais
da tabela abaixo mostram que nada se perdeu.

### Dias-disco e falhas nas tabelas do DW

| Tabela | Dias-disco | Falhas |
|---|---:|---:|
| `fato_confiabilidade_mensal` | 493.160.806 | 20.310 |
| `fato_confiabilidade_faixas` | 493.160.806 | 20.310 |
| `fato_temperatura_dc_dia` | 493.160.806 | 20.310 |
| `dim_disco` | 493.160.806 | 20.271 |

Na `dim_disco`, a coluna de falhas conta discos que falharam (20.271); a diferença para os 20.310 registros
de falha corresponde a discos com mais de uma falha registrada.
