import duckdb
import pytest

from pi5.conexao import literal
from pi5.fonte import FonteParquet, colunas_extraidas, snapshot_mais_recente, validar_colunas, versao_metadata

BASE = "s3://drivestats-iceberg/drivestats/metadata"


def test_versao_metadata():
    assert versao_metadata(f"{BASE}/00262-ea189fed.metadata.json") == 262
    assert versao_metadata(f"{BASE}/v7.metadata.json") == 7


def test_snapshot_mais_recente_compara_numeros_e_nao_texto():
    arquivos = [f"{BASE}/00099-a.metadata.json", f"{BASE}/00100-b.metadata.json", f"{BASE}/v98.metadata.json"]
    assert snapshot_mais_recente(arquivos).endswith("00100-b.metadata.json")


def test_snapshot_sem_arquivos():
    with pytest.raises(RuntimeError):
        snapshot_mais_recente([])


def test_colunas_extraidas_sem_repeticao():
    colunas = colunas_extraidas()
    assert colunas[:2] == ["date", "serial_number"]
    assert len(colunas) == len(set(colunas)) == 11 + 2 * 44


@pytest.fixture
def fonte_parquet(tmp_path):
    con = duckdb.connect()
    for mes, dias in (("2024-01", 31), ("2024-02", 3)):
        destino = tmp_path / f"{mes}.parquet"
        con.execute(f"""
            COPY (SELECT DATE '{mes}-01' + INTERVAL (d) DAY AS date, 'S' || d AS serial_number
                  FROM range({dias}) t(d))
            TO {literal(destino)} (FORMAT parquet)
        """)
    return FonteParquet(con, str(tmp_path / "*.parquet"))


def test_parquet_conta_linhas_e_arquivos_por_mes(fonte_parquet):
    contagem = fonte_parquet.contagem_por_mes()
    assert {mes: (c.linhas, c.arquivos) for mes, c in contagem.items()} == {"2024-01": (31, 1), "2024-02": (3, 1)}


def test_validar_colunas_aponta_ausentes(fonte_parquet):
    validar_colunas(fonte_parquet, ["date", "serial_number"])
    with pytest.raises(RuntimeError, match="model"):
        validar_colunas(fonte_parquet, ["date", "model"])
