import pytest

from pi5 import controle, execucao
from pi5.armazenamento import ArmazenamentoLocal
from pi5.cli import main
from pi5.extracao import Resumo


def test_dividir_alterna_meses():
    meses = ["2024-01", "2024-02", "2024-03", "2024-04", "2024-05"]
    assert execucao.dividir(meses, 2) == [["2024-01", "2024-03", "2024-05"], ["2024-02", "2024-04"]]
    assert execucao.dividir(meses[:1], 4) == [["2024-01"]]


def test_combinar_ordena():
    total = execucao.combinar([Resumo(extraidos=["2024-03"]), Resumo(extraidos=["2024-01"], sem_dados=["2023-12"])])
    assert total.extraidos == ["2024-01", "2024-03"]
    assert total.sem_dados == ["2023-12"]


@pytest.fixture
def dados(tmp_path, monkeypatch):
    monkeypatch.setattr(execucao, "DIR_DADOS", tmp_path)
    monkeypatch.delenv("PI5_ADLS_CONTA", raising=False)
    return tmp_path


def test_destino_auto_sem_lake_e_local(dados):
    ambiente = execucao.preparar_destino("auto")
    assert isinstance(ambiente.destino, ArmazenamentoLocal)
    assert ambiente.dir_staging == dados / "bronze"
    assert not ambiente.limpar_staging


def test_destino_lake_exige_conta(dados):
    with pytest.raises(SystemExit, match="PI5_ADLS_CONTA"):
        execucao.preparar_destino("lake")


def test_destino_auto_com_lake(dados, monkeypatch):
    monkeypatch.setenv("PI5_ADLS_CONTA", "stpi5")
    monkeypatch.setattr(execucao, "ArmazenamentoLake", lambda config: ("lake", config.conta))
    ambiente = execucao.preparar_destino("auto")
    assert ambiente.destino == ("lake", "stpi5")
    assert ambiente.limpar_staging


def test_status_lista_controle(dados, capsys):
    destino = ArmazenamentoLocal(dados / "bronze")
    controle.gravar(destino, controle.RegistroMes("2024-01", "ok", "snap", 1, 93, 93, 1000, 1.5, "2024-02-01T00:00"))
    with pytest.raises(SystemExit) as saida:
        main(["status", "--destino", "local"])
    assert saida.value.code == 0
    assert "2024-01  ok" in capsys.readouterr().out
