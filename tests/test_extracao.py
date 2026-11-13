import duckdb
import pytest

from drivestats_el import controle, extracao
from drivestats_el.armazenamento import ArmazenamentoLocal
from drivestats_el.conexao import literal
from drivestats_el.configuracao import Recursos
from drivestats_el.fonte import COLUNAS_IDENTIFICACAO, FonteParquet, colunas_extraidas

RECURSOS = Recursos(memoria="512MB", threads=2, dias_por_parte=10)


def _gerar_fonte(con, arquivo, mes, dias, discos=3):
    """Parquet com o esquema da fonte: `discos` linhas por dia, SMART nulos exceto temperatura."""
    smart = [c for c in colunas_extraidas() if c not in COLUNAS_IDENTIFICACAO]
    colunas_smart = ", ".join(f"{'40' if c == 'smart_194_raw' else 'NULL'}::BIGINT AS {c}" for c in smart)
    con.execute(f"""
        COPY (
            SELECT DATE '{mes}-01' + INTERVAL (d) DAY AS date, 'SN' || s AS serial_number, 'ST16000NM001G' AS model,
                   16000900661248 AS capacity_bytes, 0 AS failure, 'phx1' AS datacenter, 1 AS cluster_id,
                   1000 AS vault_id, 0 AS pod_id, s AS pod_slot_num, false AS is_legacy_format, {colunas_smart}
            FROM range({dias}) t(d), range({discos}) u(s)
        ) TO {literal(arquivo)} (FORMAT parquet)
    """)


@pytest.fixture
def cenario(tmp_path):
    con = duckdb.connect()
    origem = tmp_path / "origem"
    origem.mkdir()
    _gerar_fonte(con, origem / "2024-01.parquet", "2024-01", 31)
    _gerar_fonte(con, origem / "2024-02.parquet", "2024-02", 29)
    fonte = FonteParquet(con, str(origem / "*.parquet"))
    destino = ArmazenamentoLocal(tmp_path / "bronze")

    def rodar(meses=("2024-01", "2024-02"), **kwargs):
        return extracao.executar(con, fonte, destino, list(meses), tmp_path / "staging", RECURSOS, **kwargs)

    return rodar, destino, origem, con


def test_extrai_concilia_e_registra(cenario):
    rodar, destino, *_ = cenario
    resumo = rodar()

    assert resumo.extraidos == ["2024-01", "2024-02"]
    janeiro = controle.ler(destino, "2024-01")
    assert (janeiro.status, janeiro.linhas_fonte, janeiro.linhas_gravadas) == ("ok", 93, 93)
    # fatias de 10 dias: 01, 11, 21 e 31
    assert destino.listar("ano_mes=2024-01") == {f"ano_mes=2024-01/parte_{d}.parquet" for d in ("01", "11", "21", "31")}


def test_bronze_mantem_colunas_originais(cenario):
    rodar, destino, _, con = cenario
    rodar(meses=["2024-02"])
    arquivos = literal(destino.raiz / "ano_mes=2024-02" / "*.parquet")
    # hive_partitioning desligado: só as colunas gravadas, sem a derivada do nome da pasta
    descricao = con.execute(f"DESCRIBE SELECT * FROM read_parquet({arquivos}, hive_partitioning = false)")
    colunas = [c[0] for c in descricao.fetchall()]
    assert colunas == colunas_extraidas()


def test_segunda_execucao_pula_meses_atualizados(cenario):
    rodar, *_ = cenario
    rodar()
    resumo = rodar()
    assert resumo.atualizados == ["2024-01", "2024-02"]
    assert resumo.extraidos == []


def test_forcar_refaz(cenario):
    rodar, *_ = cenario
    rodar()
    assert rodar(meses=["2024-01"], forcar=True).extraidos == ["2024-01"]


def test_mudanca_na_fonte_refaz_o_mes(cenario):
    rodar, destino, origem, con = cenario
    rodar()
    _gerar_fonte(con, origem / "2024-02.parquet", "2024-02", 29, discos=4)
    resumo = rodar()
    assert resumo.atualizados == ["2024-01"]
    assert resumo.extraidos == ["2024-02"]
    assert controle.ler(destino, "2024-02").linhas_gravadas == 116


def test_parte_apagada_no_destino_refaz_o_mes(cenario):
    rodar, destino, *_ = cenario
    rodar()
    (destino.raiz / "ano_mes=2024-01" / "parte_11.parquet").unlink()
    assert rodar(meses=["2024-01"]).extraidos == ["2024-01"]


def test_mes_sem_dados_e_staging_limpo(cenario, tmp_path):
    rodar, destino, *_ = cenario
    resumo = rodar(meses=["2023-12", "2024-01"])
    assert resumo.sem_dados == ["2023-12"]
    assert not any((tmp_path / "staging").iterdir())
    assert [r.ano_mes for r in controle.listar(destino)] == ["2024-01"]
