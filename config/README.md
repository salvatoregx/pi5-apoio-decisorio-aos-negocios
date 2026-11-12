# config

| Arquivo | Conteúdo |
|---|---|
| `fonte_dados.json` | endpoint, bucket e chaves **públicas, somente leitura**, divulgadas pela Backblaze |
| `datacenters.json` | localização dos datacenters. A Backblaze não publica código → cidade; o mapeamento foi inferido do código IATA, e `sac0`/`sac2` (Sacramento ou Stockton) não foram confirmados |
| `catalogo_fabricantes.csv` | um modelo por linha: família, gravação, ar/hélio, RPM, interface, potência, faixa de temperatura, MTBF, AFR declarado, carga de trabalho, garantia |
| `catalogo_fabricantes_fontes.csv` | fontes das especificações (modelo × URL, relação 1:n), com campos sustentados e data de acesso |

Sobre o catálogo (situação em 16/09/2026):

- Os 100 modelos da janela foram pesquisados em datasheets e manuais oficiais (164 fontes).
- Há potência para 88 modelos, o que cobre 98,9% dos dias-disco. Campos sem fonte ficam vazios,
  e a coluna `observacoes` explica o critério de cada medida.
- `criterio_potencia_operacao` indica se a potência é `típica` (71,9% dos dias-disco), `máxima`
  (26,8%; os datasheets Seagate Exos X10–X24 só publicam o máximo) ou `média notebook (MobileMark)`
  (0,3%, SSDs de boot). Estimativas de energia precisam considerar essa diferença.
