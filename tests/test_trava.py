import pytest

from pi5.trava import execucao_exclusiva


def test_segunda_execucao_e_recusada(tmp_path):
    with execucao_exclusiva(tmp_path), pytest.raises(SystemExit), execucao_exclusiva(tmp_path):
        pass


def test_trava_liberada_ao_sair(tmp_path):
    with execucao_exclusiva(tmp_path):
        pass
    with execucao_exclusiva(tmp_path):
        pass
