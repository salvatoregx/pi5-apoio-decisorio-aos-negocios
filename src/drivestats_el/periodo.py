"""Meses da janela de análise e fatias de dias dentro de cada mês."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, timedelta

_FORMATO_MES = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


@dataclass(frozen=True)
class Parte:
    """Fatia de um mês: [inicio, fim) em dias, gravada como um arquivo Parquet."""

    nome: str
    inicio: date
    fim: date


def validar_mes(ano_mes: str) -> str:
    if not _FORMATO_MES.match(ano_mes):
        raise ValueError(f"Mês inválido: {ano_mes!r} (esperado AAAA-MM)")
    return ano_mes


def primeiro_dia(ano_mes: str) -> date:
    ano, mes = map(int, validar_mes(ano_mes).split("-"))
    return date(ano, mes, 1)


def proximo_mes(ano_mes: str) -> str:
    dia = primeiro_dia(ano_mes)
    return f"{dia.year + 1:04d}-01" if dia.month == 12 else f"{dia.year:04d}-{dia.month + 1:02d}"


def meses(inicio: str, fim: str) -> list[str]:
    """Meses de `inicio` a `fim`, inclusive, no formato AAAA-MM."""
    if primeiro_dia(inicio) > primeiro_dia(fim):
        raise ValueError(f"Início ({inicio}) depois do fim ({fim})")
    saida = [inicio]
    while saida[-1] != fim:
        saida.append(proximo_mes(saida[-1]))
    return saida


def partes_do_mes(ano_mes: str, dias_por_parte: int) -> list[Parte]:
    """Divide o mês em fatias de `dias_por_parte` dias; a última termina no dia 1 do mês seguinte."""
    if dias_por_parte < 1:
        raise ValueError("dias_por_parte precisa ser positivo")
    inicio = primeiro_dia(ano_mes)
    fim_mes = primeiro_dia(proximo_mes(ano_mes))
    partes = []
    while inicio < fim_mes:
        fim = min(inicio + timedelta(days=dias_por_parte), fim_mes)
        partes.append(Parte(f"parte_{inicio.day:02d}", inicio, fim))
        inicio = fim
    return partes
