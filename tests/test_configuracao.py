import json

from drivestats_el.configuracao import ConfigIceberg, ConfigLake, Recursos


def test_recursos_do_ambiente(monkeypatch):
    monkeypatch.setenv("ETL_MEMORIA", "4GB")
    monkeypatch.setenv("ETL_THREADS", "8")
    recursos = Recursos.do_ambiente()
    assert (recursos.memoria, recursos.threads, recursos.dias_por_parte) == ("4GB", 8, 7)


def test_iceberg_remove_esquema_do_endpoint(tmp_path):
    arquivo = tmp_path / "fonte.json"
    arquivo.write_text(
        json.dumps(
            {
                "bucket": "b",
                "prefixo": "p",
                "s3": {"key_id": "k", "secret": "s", "endpoint": "https://s3.exemplo.com", "regiao": "r"},
            }
        )
    )
    config = ConfigIceberg.do_arquivo(arquivo)
    assert config.endpoint == "s3.exemplo.com"
    assert config.raiz == "s3://b/p"


def test_lake_desligado_sem_conta(monkeypatch):
    monkeypatch.delenv("PI5_ADLS_CONTA", raising=False)
    assert ConfigLake.do_ambiente() is None


def test_lake_do_ambiente(monkeypatch):
    monkeypatch.setenv("PI5_ADLS_CONTA", "stpi5")
    lake = ConfigLake.do_ambiente()
    assert lake.url == "https://stpi5.dfs.core.windows.net"
    assert (lake.container, lake.diretorio) == ("lake", "bronze/drivestats")
