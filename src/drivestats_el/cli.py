"""Linha de comando: `uv run drivestats <comando> [opções]`."""

from __future__ import annotations

import argparse
import logging
import sys
import time

from drivestats_el import controle
from drivestats_el.configuracao import DIR_DADOS, PERIODO_FIM, PERIODO_INICIO
from drivestats_el.execucao import DESTINOS, Opcoes, configurar_log, extrair, preparar_destino
from drivestats_el.periodo import meses
from drivestats_el.trava import execucao_exclusiva

log = logging.getLogger("drivestats_el")

AJUDA_AMBIENTE = """\
variáveis de ambiente:
  PI5_ADLS_CONTA      conta do ADLS Gen2; com ela, o destino padrão passa a ser o lake
  PI5_ADLS_CONTAINER  container do lake (padrão: lake)
  ETL_MEMORIA         limite de memória do DuckDB por processo (padrão: 1500MB)
  ETL_THREADS         threads do DuckDB por processo (padrão: 4)
  ETL_DIAS_POR_PARTE  dias por arquivo Parquet (padrão: 7)
"""


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="drivestats",
        description="E e L do Backblaze Drive Stats: Iceberg público -> bronze (local ou ADLS Gen2)",
        epilog=AJUDA_AMBIENTE,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="comando", required=True)

    extrair_ = sub.add_parser("extrair", help="extrai os meses da fonte para a bronze")
    extrair_.add_argument("--inicio", default=PERIODO_INICIO, help="mês inicial AAAA-MM (padrão %(default)s)")
    extrair_.add_argument("--fim", default=PERIODO_FIM, help="mês final AAAA-MM (padrão %(default)s)")
    extrair_.add_argument("--forcar", action="store_true", help="refaz meses já extraídos")
    extrair_.add_argument("--paralelo", type=int, default=1, help="meses processados ao mesmo tempo (padrão 1)")

    status = sub.add_parser("status", help="mostra o controle de extração do destino")

    for comando in (extrair_, status):
        comando.add_argument("--destino", choices=DESTINOS, default="auto", help="padrão: lake se configurado")
    return parser


def _extrair(args: argparse.Namespace) -> int:
    lista = meses(args.inicio, args.fim)
    inicio = time.monotonic()
    rotulo = "mês" if len(lista) == 1 else "meses"
    log.info("extraindo %d %s (%s a %s), %d por vez", len(lista), rotulo, args.inicio, args.fim, max(args.paralelo, 1))
    resumo = extrair(lista, Opcoes(destino=args.destino, forcar=args.forcar), args.paralelo)
    log.info(
        "concluído em %.0fs: %d extraídos, %d já atualizados, %d sem dados, %d divergentes",
        time.monotonic() - inicio,
        len(resumo.extraidos),
        len(resumo.atualizados),
        len(resumo.sem_dados),
        len(resumo.divergentes),
    )
    if resumo.divergentes:
        log.error("meses divergentes da fonte: %s", ", ".join(resumo.divergentes))
        return 1
    return 0


def _status(args: argparse.Namespace) -> int:
    ambiente = preparar_destino(args.destino)
    registros = controle.listar(ambiente.destino)
    print(f"destino: {ambiente.destino.descricao}")
    print(f"{'mês':<8} {'status':<11} {'linhas':>12} {'MB':>8} {'s':>7}")
    for r in registros:
        print(
            f"{r.ano_mes:<8} {r.status:<11} {r.linhas_gravadas:>12,} {r.bytes_gravados / 1e6:>8.1f} {r.duracao_s:>7.1f}"
        )
    total = sum(r.linhas_gravadas for r in registros)
    print(f"{len(registros)} meses, {total:,} linhas")
    return 0


def main(argv: list[str] | None = None) -> None:
    args = _parser().parse_args(argv)
    configurar_log()
    if args.comando == "status":
        sys.exit(_status(args))
    with execucao_exclusiva(DIR_DADOS):
        sys.exit(_extrair(args))
