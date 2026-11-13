from datetime import date
from itertools import pairwise

import pytest

from drivestats_el.periodo import meses, partes_do_mes, proximo_mes


def test_meses_atravessa_virada_de_ano():
    assert meses("2021-11", "2022-02") == ["2021-11", "2021-12", "2022-01", "2022-02"]


def test_meses_um_so():
    assert meses("2024-05", "2024-05") == ["2024-05"]


@pytest.mark.parametrize("inicio, fim", [("2024-13", "2024-12"), ("2024-1", "2024-12"), ("2025-01", "2024-12")])
def test_meses_invalidos(inicio, fim):
    with pytest.raises(ValueError):
        meses(inicio, fim)


def test_proximo_mes_dezembro():
    assert proximo_mes("2023-12") == "2024-01"


def test_partes_cobrem_o_mes_sem_lacunas():
    partes = partes_do_mes("2024-02", 7)  # bissexto
    assert [p.nome for p in partes] == ["parte_01", "parte_08", "parte_15", "parte_22", "parte_29"]
    assert partes[0].inicio == date(2024, 2, 1)
    assert partes[-1].fim == date(2024, 3, 1)
    assert all(a.fim == b.inicio for a, b in pairwise(partes))


def test_parte_unica_quando_fatia_maior_que_o_mes():
    (parte,) = partes_do_mes("2023-04", 31)
    assert (parte.inicio, parte.fim) == (date(2023, 4, 1), date(2023, 5, 1))
