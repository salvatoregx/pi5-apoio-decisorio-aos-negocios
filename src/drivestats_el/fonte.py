"""Fontes de dados da extração.

`FonteIceberg` lê a tabela pública da Backblaze. `FonteParquet` lê arquivos Parquet com o
mesmo esquema e serve para testes e para reprocessar uma cópia local.

Detalhes do Iceberg que importam para a conciliação:
- A tabela tem um metadata.json por versão; vale sempre o de maior número.
- O manifesto também lista arquivos já removidos (status DELETED), que não podem
  entrar na soma de linhas esperadas.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Protocol

import duckdb

from drivestats_el.catalogo_smart import ATRIBUTOS
from drivestats_el.conexao import literal
from drivestats_el.configuracao import ConfigIceberg

COLUNAS_IDENTIFICACAO = [
    "date",
    "serial_number",
    "model",
    "capacity_bytes",
    "failure",
    "datacenter",
    "cluster_id",
    "vault_id",
    "pod_id",
    "pod_slot_num",
    "is_legacy_format",
]

_VERSAO_METADATA = re.compile(r"^v?(\d+)[-.]")


@dataclass(frozen=True)
class ContagemMes:
    linhas: int
    arquivos: int


class Fonte(Protocol):
    identificador: str

    def relacao(self) -> str:
        """Expressão SQL usada no FROM da extração."""
        ...

    def contagem_por_mes(self) -> dict[str, ContagemMes]: ...

    def colunas(self) -> set[str]: ...


def colunas_extraidas() -> list[str]:
    """Identificação do disco + bruto e normalizado dos atributos SMART do catálogo."""
    smart = [c for a in ATRIBUTOS for c in (a.fonte_bruto, a.fonte_normalizado)]
    return COLUNAS_IDENTIFICACAO + smart


def validar_colunas(fonte: Fonte, desejadas: list[str]) -> None:
    ausentes = [c for c in desejadas if c not in fonte.colunas()]
    if ausentes:
        raise RuntimeError(f"Colunas esperadas ausentes na fonte: {ausentes}")


def versao_metadata(caminho: str) -> int:
    nome = caminho.rsplit("/", 1)[-1]
    encontrado = _VERSAO_METADATA.match(nome)
    if not encontrado:
        raise ValueError(f"Nome de metadata Iceberg inesperado: {nome}")
    return int(encontrado.group(1))


def snapshot_mais_recente(arquivos: list[str]) -> str:
    if not arquivos:
        raise RuntimeError("Nenhum metadata.json encontrado na tabela Iceberg.")
    return max(arquivos, key=versao_metadata)


def _colunas(con: duckdb.DuckDBPyConnection, relacao: str) -> set[str]:
    return {linha[0] for linha in con.execute(f"DESCRIBE SELECT * FROM {relacao}").fetchall()}


class FonteIceberg:
    def __init__(self, con: duckdb.DuckDBPyConnection, config: ConfigIceberg):
        self._con = con
        metadados = con.execute(f"SELECT file FROM glob({literal(config.raiz + '/metadata/*.metadata.json')})")
        self.identificador = snapshot_mais_recente([linha[0] for linha in metadados.fetchall()])

    def relacao(self) -> str:
        return f"iceberg_scan({literal(self.identificador)})"

    def contagem_por_mes(self) -> dict[str, ContagemMes]:
        linhas = self._con.execute(f"""
            SELECT regexp_extract(file_path, 'date_month=([0-9]{{4}}-[0-9]{{2}})', 1) AS ano_mes,
                   sum(record_count)::BIGINT,
                   count(*)::BIGINT
            FROM iceberg_metadata({literal(self.identificador)})
            WHERE status <> 'DELETED' AND manifest_content = 'DATA'
            GROUP BY 1
        """).fetchall()
        return {mes: ContagemMes(n, arquivos) for mes, n, arquivos in linhas}

    def colunas(self) -> set[str]:
        return _colunas(self._con, self.relacao())


class FonteParquet:
    def __init__(self, con: duckdb.DuckDBPyConnection, padrao: str):
        self._con = con
        self.identificador = padrao

    def relacao(self) -> str:
        return f"read_parquet({literal(self.identificador)})"

    def contagem_por_mes(self) -> dict[str, ContagemMes]:
        linhas = self._con.execute(f"""
            SELECT strftime(date, '%Y-%m'), count(*), count(DISTINCT filename)
            FROM read_parquet({literal(self.identificador)}, filename = true)
            GROUP BY 1
        """).fetchall()
        return {mes: ContagemMes(n, arquivos) for mes, n, arquivos in linhas}

    def colunas(self) -> set[str]:
        return _colunas(self._con, self.relacao())
