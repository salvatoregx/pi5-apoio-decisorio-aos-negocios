"""Registro de cada mês extraído, gravado no próprio destino (`_controle/AAAA-MM.json`).

Um arquivo por mês: execuções paralelas sobre meses diferentes não disputam o mesmo arquivo,
e o registro fica junto dos dados, valendo para qualquer máquina que rode a extração.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field

from drivestats_el.armazenamento import Armazenamento

DIRETORIO = "_controle"


@dataclass
class RegistroMes:
    ano_mes: str
    status: str  # "ok" ou "divergente"
    snapshot: str
    arquivos_fonte: int
    linhas_fonte: int
    linhas_gravadas: int
    bytes_gravados: int
    duracao_s: float
    extraido_em: str
    partes: list[str] = field(default_factory=list)


def _caminho(ano_mes: str) -> str:
    return f"{DIRETORIO}/{ano_mes}.json"


def ler(destino: Armazenamento, ano_mes: str) -> RegistroMes | None:
    texto = destino.ler_texto(_caminho(ano_mes))
    return RegistroMes(**json.loads(texto)) if texto else None


def gravar(destino: Armazenamento, registro: RegistroMes) -> None:
    destino.gravar_texto(_caminho(registro.ano_mes), json.dumps(asdict(registro), indent=2, ensure_ascii=False))


def listar(destino: Armazenamento) -> list[RegistroMes]:
    meses = sorted(c.removeprefix(f"{DIRETORIO}/").removesuffix(".json") for c in destino.listar(DIRETORIO))
    return [r for m in meses if (r := ler(destino, m))]
