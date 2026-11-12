"""Trava para impedir duas execuções simultâneas sobre o mesmo diretório de dados.

Duas extrações em paralelo disputam memória e gravam nos mesmos arquivos.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from filelock import FileLock, Timeout


@contextmanager
def execucao_exclusiva(dir_dados: Path) -> Iterator[None]:
    dir_dados.mkdir(parents=True, exist_ok=True)
    trava = FileLock(dir_dados / ".etl.lock", timeout=0)
    try:
        trava.acquire()
    except Timeout:
        raise SystemExit(f"Outra execução está em andamento ({trava.lock_file}).") from None
    try:
        yield
    finally:
        trava.release()
