"""Montagem do ambiente de extração e execução de vários meses em paralelo.

Cada processo abre a própria conexão DuckDB e a própria leitura da fonte. Os meses são
independentes e o controle é um arquivo por mês, então os processos não disputam nada
além de rede e memória: o pico total fica perto de `paralelo x ETL_MEMORIA`.
"""

from __future__ import annotations

import logging
import os
import shutil
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass
from itertools import repeat
from multiprocessing import get_context
from pathlib import Path

from pi5 import extracao
from pi5.armazenamento import Armazenamento, ArmazenamentoLake, ArmazenamentoLocal
from pi5.conexao import conectar
from pi5.configuracao import DIR_DADOS, ConfigIceberg, ConfigLake, Recursos
from pi5.fonte import FonteIceberg

DESTINOS = ("auto", "local", "lake")
FORMATO_LOG = "%(asctime)s %(levelname)s [%(process)d] %(message)s"


@dataclass(frozen=True)
class Opcoes:
    destino: str = "auto"
    forcar: bool = False


@dataclass(frozen=True)
class Ambiente:
    destino: Armazenamento
    dir_staging: Path
    limpar_staging: bool


def preparar_destino(tipo: str) -> Ambiente:
    """Lake grava via staging local (limpo após cada mês); destino local grava no lugar."""
    if tipo not in DESTINOS:
        raise ValueError(f"Destino inválido: {tipo}")
    lake = ConfigLake.do_ambiente()
    if tipo == "lake" and lake is None:
        raise SystemExit("Destino lake exige a variável PI5_ADLS_CONTA.")
    if tipo == "local" or lake is None:
        bronze = DIR_DADOS / "bronze"
        return Ambiente(ArmazenamentoLocal(bronze), bronze, limpar_staging=False)
    return Ambiente(ArmazenamentoLake(lake), DIR_DADOS / "staging", limpar_staging=True)


def configurar_log(nivel: int = logging.INFO) -> None:
    logging.basicConfig(level=nivel, format=FORMATO_LOG, force=True)
    # O SDK do Azure registra cada requisição HTTP em INFO.
    logging.getLogger("azure").setLevel(logging.WARNING)


def extrair_meses(meses: list[str], opcoes: Opcoes) -> extracao.Resumo:
    recursos = Recursos.do_ambiente()
    iceberg = ConfigIceberg.do_arquivo()
    ambiente = preparar_destino(opcoes.destino)
    dir_temp = DIR_DADOS / "tmp" / f"processo-{os.getpid()}"
    con = conectar(recursos, dir_temp, iceberg)
    try:
        return extracao.executar(
            con,
            FonteIceberg(con, iceberg),
            ambiente.destino,
            meses,
            ambiente.dir_staging,
            recursos,
            forcar=opcoes.forcar,
            limpar_staging=ambiente.limpar_staging,
        )
    finally:
        con.close()
        shutil.rmtree(dir_temp, ignore_errors=True)


def dividir(meses: list[str], grupos: int) -> list[list[str]]:
    """Distribui os meses alternadamente, para os anos recentes (mais discos) não caírem num só grupo."""
    return [g for i in range(grupos) if (g := meses[i::grupos])]


def combinar(resumos: list[extracao.Resumo]) -> extracao.Resumo:
    total = extracao.Resumo()
    for resumo in resumos:
        for campo in ("extraidos", "atualizados", "divergentes", "sem_dados"):
            getattr(total, campo).extend(getattr(resumo, campo))
    for campo in ("extraidos", "atualizados", "divergentes", "sem_dados"):
        getattr(total, campo).sort()
    return total


def extrair(meses: list[str], opcoes: Opcoes, paralelo: int = 1) -> extracao.Resumo:
    if paralelo <= 1:
        return extrair_meses(meses, opcoes)
    grupos = dividir(meses, paralelo)
    # spawn: processos novos, sem herdar estado de threads do DuckDB do processo pai.
    with ProcessPoolExecutor(len(grupos), mp_context=get_context("spawn"), initializer=configurar_log) as pool:
        return combinar(list(pool.map(extrair_meses, grupos, repeat(opcoes))))
