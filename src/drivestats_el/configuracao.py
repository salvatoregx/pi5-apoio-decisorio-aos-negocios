"""Caminhos, parâmetros de execução e leitura dos arquivos de configuração.

Tudo que muda entre ambientes (máquina local, contêiner no Azure) vem de variáveis
de ambiente, com padrões pensados para uma máquina com ~8 GB de RAM.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DIR_CONFIG = Path(os.environ.get("PI5_DIR_CONFIG", RAIZ / "config"))
DIR_DADOS = Path(os.environ.get("PI5_DIR_DADOS", RAIZ / "data"))

# Janela padrão: últimos 5 anos completos disponíveis (20 trimestres fechados).
PERIODO_INICIO = "2021-07"
PERIODO_FIM = "2026-06"


@dataclass(frozen=True)
class Recursos:
    """Limites do DuckDB e tamanho das fatias de extração.

    Acima de `memoria` o DuckDB transborda para disco; buffers do escritor Parquet
    ficam fora desse limite, então o pico real do processo é maior.
    """

    memoria: str = "1500MB"
    threads: int = 4
    dias_por_parte: int = 7
    linhas_por_row_group: int = 250_000

    @classmethod
    def do_ambiente(cls) -> Recursos:
        return cls(
            memoria=os.environ.get("ETL_MEMORIA", cls.memoria),
            threads=int(os.environ.get("ETL_THREADS", cls.threads)),
            dias_por_parte=int(os.environ.get("ETL_DIAS_POR_PARTE", cls.dias_por_parte)),
        )


@dataclass(frozen=True)
class ConfigIceberg:
    """Acesso à tabela Iceberg da Backblaze (S3 compatível, somente leitura)."""

    bucket: str
    prefixo: str
    endpoint: str
    regiao: str
    key_id: str
    secret: str

    @property
    def raiz(self) -> str:
        return f"s3://{self.bucket}/{self.prefixo}"

    @classmethod
    def do_arquivo(cls, caminho: Path | None = None) -> ConfigIceberg:
        dados = json.loads((caminho or DIR_CONFIG / "fonte_dados.json").read_text(encoding="utf-8"))
        s3 = dados["s3"]
        return cls(
            bucket=dados["bucket"],
            prefixo=dados["prefixo"],
            endpoint=s3["endpoint"].removeprefix("https://").removeprefix("http://"),
            regiao=s3["regiao"],
            key_id=s3["key_id"],
            secret=s3["secret"],
        )


@dataclass(frozen=True)
class ConfigLake:
    """Destino no ADLS Gen2. A autenticação fica a cargo do DefaultAzureCredential."""

    conta: str
    container: str = "lake"
    diretorio: str = "bronze/drivestats"

    @property
    def url(self) -> str:
        return f"https://{self.conta}.dfs.core.windows.net"

    @classmethod
    def do_ambiente(cls) -> ConfigLake | None:
        conta = os.environ.get("PI5_ADLS_CONTA")
        if not conta:
            return None
        return cls(
            conta=conta,
            container=os.environ.get("PI5_ADLS_CONTAINER", cls.container),
            diretorio=os.environ.get("PI5_ADLS_DIRETORIO", cls.diretorio),
        )
