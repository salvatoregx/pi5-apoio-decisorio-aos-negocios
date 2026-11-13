from drivestats_el.conexao import conectar, literal
from drivestats_el.configuracao import Recursos


def test_literal_escapa_aspas():
    assert literal("d'água") == "'d''água'"


def test_conectar_aplica_limites(tmp_path):
    con = conectar(Recursos(memoria="512MB", threads=2), tmp_path / "tmp")
    assert con.execute("SELECT current_setting('threads')").fetchone()[0] == 2
    assert (tmp_path / "tmp").is_dir()
