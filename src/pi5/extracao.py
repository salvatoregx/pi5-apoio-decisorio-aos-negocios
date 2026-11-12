"""Etapas E e L: cópia fiel da fonte para a bronze, mês a mês, com conciliação.

- Cada mês é gravado em fatias de dias (um Parquet por fatia), para limitar memória.
- Um mês só é refeito se não estiver no destino, se falhou na conciliação ou se a
  contagem de linhas na fonte mudou desde a última extração.
- Conciliação: linhas gravadas devem ser iguais às linhas do manifesto Iceberg.
- A bronze mantém os nomes de colunas originais; renomear e limpar fica para o T.
"""

from __future__ import annotations

import logging
import shutil
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import duckdb

from pi5 import controle
from pi5.armazenamento import Armazenamento
from pi5.conexao import literal
from pi5.configuracao import Recursos
from pi5.fonte import ContagemMes, Fonte, colunas_extraidas, validar_colunas
from pi5.periodo import partes_do_mes

log = logging.getLogger(__name__)


@dataclass
class Resumo:
    extraidos: list[str] = field(default_factory=list)
    atualizados: list[str] = field(default_factory=list)
    divergentes: list[str] = field(default_factory=list)
    sem_dados: list[str] = field(default_factory=list)


def gravar_mes(
    con: duckdb.DuckDBPyConnection, fonte: Fonte, colunas: list[str], ano_mes: str, dir_mes: Path, recursos: Recursos
) -> tuple[int, list[Path]]:
    """Grava as fatias do mês em `dir_mes`, a partir de um diretório limpo. Devolve (linhas, arquivos)."""
    if dir_mes.exists():
        shutil.rmtree(dir_mes)
    dir_mes.mkdir(parents=True)
    selecao = ", ".join(f'"{c}"' for c in colunas)
    linhas, arquivos = 0, []
    for parte in partes_do_mes(ano_mes, recursos.dias_por_parte):
        destino = dir_mes / f"{parte.nome}.parquet"
        temporario = destino.with_name(destino.name + ".tmp")
        (gravadas,) = con.execute(f"""
            COPY (
                SELECT {selecao}
                FROM {fonte.relacao()}
                WHERE date >= DATE '{parte.inicio}' AND date < DATE '{parte.fim}'
            )
            TO {literal(temporario)}
            (FORMAT parquet, COMPRESSION zstd, ROW_GROUP_SIZE {recursos.linhas_por_row_group})
        """).fetchone()
        temporario.replace(destino)
        linhas += gravadas
        arquivos.append(destino)
    return linhas, arquivos


def _atualizado(registro: controle.RegistroMes | None, contagem: ContagemMes, presentes: set[str]) -> bool:
    return (
        registro is not None
        and registro.status == "ok"
        and registro.linhas_fonte == contagem.linhas
        and set(registro.partes) <= presentes
    )


def executar(
    con: duckdb.DuckDBPyConnection,
    fonte: Fonte,
    destino: Armazenamento,
    meses: list[str],
    dir_staging: Path,
    recursos: Recursos,
    forcar: bool = False,
    limpar_staging: bool = True,
) -> Resumo:
    """Extrai os meses para `dir_staging` e publica cada um no destino.

    `limpar_staging=False` quando o destino é o próprio diretório local de staging.
    """
    colunas = colunas_extraidas()
    validar_colunas(fonte, colunas)
    contagens = fonte.contagem_por_mes()
    log.info("fonte: %s", fonte.identificador)
    resumo = Resumo()

    for ano_mes in meses:
        contagem = contagens.get(ano_mes)
        if contagem is None:
            log.info("%s: sem dados na fonte", ano_mes)
            resumo.sem_dados.append(ano_mes)
            continue
        prefixo = f"ano_mes={ano_mes}"
        if not forcar and _atualizado(controle.ler(destino, ano_mes), contagem, destino.listar(prefixo)):
            log.info("%s: já atualizado (%s linhas)", ano_mes, f"{contagem.linhas:,}")
            resumo.atualizados.append(ano_mes)
            continue

        inicio = time.monotonic()
        dir_mes = dir_staging / prefixo
        linhas, arquivos = gravar_mes(con, fonte, colunas, ano_mes, dir_mes, recursos)
        tamanho = destino.publicar(prefixo, arquivos)
        if limpar_staging:
            shutil.rmtree(dir_mes)

        status = "ok" if linhas == contagem.linhas else "divergente"
        registro = controle.RegistroMes(
            ano_mes=ano_mes,
            status=status,
            snapshot=fonte.identificador,
            arquivos_fonte=contagem.arquivos,
            linhas_fonte=contagem.linhas,
            linhas_gravadas=linhas,
            bytes_gravados=tamanho,
            duracao_s=round(time.monotonic() - inicio, 1),
            extraido_em=datetime.now().isoformat(timespec="seconds"),
            partes=[f"{prefixo}/{a.name}" for a in arquivos],
        )
        controle.gravar(destino, registro)
        (resumo.extraidos if status == "ok" else resumo.divergentes).append(ano_mes)
        if status == "ok":
            log.info("%s: %s linhas em %ss", ano_mes, f"{linhas:,}", registro.duracao_s)
        else:
            log.warning("%s: DIVERGENTE, fonte %s x gravadas %s", ano_mes, f"{contagem.linhas:,}", f"{linhas:,}")
    return resumo
