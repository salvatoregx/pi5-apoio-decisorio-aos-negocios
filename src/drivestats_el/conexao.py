"""Conexão DuckDB com os limites de recursos e, opcionalmente, acesso à fonte Iceberg."""

from __future__ import annotations

from pathlib import Path

import duckdb

from drivestats_el.configuracao import ConfigIceberg, Recursos


def literal(valor: object) -> str:
    """Literal SQL entre aspas simples, para caminhos e valores internos."""
    return "'" + str(valor).replace("'", "''") + "'"


def conectar(recursos: Recursos, dir_temp: Path, iceberg: ConfigIceberg | None = None) -> duckdb.DuckDBPyConnection:
    dir_temp.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute(f"SET memory_limit = {literal(recursos.memoria)}")
    con.execute(f"SET threads = {recursos.threads}")
    con.execute(f"SET temp_directory = {literal(dir_temp)}")
    # A ordem das linhas não importa para os COPY da extração, e mantê-la custa memória.
    con.execute("SET preserve_insertion_order = false")
    # Barras de progresso de vários processos se misturam no log.
    con.execute("SET enable_progress_bar = false")
    if iceberg:
        _habilitar_iceberg(con, iceberg)
    return con


def _habilitar_iceberg(con: duckdb.DuckDBPyConnection, iceberg: ConfigIceberg) -> None:
    for extensao in ("httpfs", "iceberg"):
        con.install_extension(extensao)
        con.load_extension(extensao)
    con.execute(f"""
        CREATE OR REPLACE SECRET backblaze (
            TYPE s3,
            KEY_ID {literal(iceberg.key_id)},
            SECRET {literal(iceberg.secret)},
            ENDPOINT {literal(iceberg.endpoint)},
            REGION {literal(iceberg.regiao)},
            URL_STYLE 'path'
        )
    """)
