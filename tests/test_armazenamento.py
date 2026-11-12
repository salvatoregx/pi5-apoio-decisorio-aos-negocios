from dataclasses import dataclass

from azure.core.exceptions import ResourceNotFoundError

from pi5.armazenamento import ArmazenamentoLake, ArmazenamentoLocal
from pi5.configuracao import ConfigLake


def test_local_texto_ida_e_volta(tmp_path):
    destino = ArmazenamentoLocal(tmp_path)
    assert destino.ler_texto("_controle/2024-01.json") is None
    destino.gravar_texto("_controle/2024-01.json", '{"ok": true}')
    assert destino.ler_texto("_controle/2024-01.json") == '{"ok": true}'


def test_local_publicar_copia_e_remove_sobras(tmp_path):
    destino = ArmazenamentoLocal(tmp_path / "bronze")
    staging = tmp_path / "staging"
    staging.mkdir()
    (staging / "parte_01.parquet").write_bytes(b"abc")
    sobra = tmp_path / "bronze" / "ano_mes=2024-01" / "parte_29.parquet"
    sobra.parent.mkdir(parents=True)
    sobra.write_bytes(b"velho")

    total = destino.publicar("ano_mes=2024-01", [staging / "parte_01.parquet"])

    assert total == 3
    assert destino.listar("ano_mes=2024-01") == {"ano_mes=2024-01/parte_01.parquet"}


def test_local_publicar_no_proprio_destino(tmp_path):
    destino = ArmazenamentoLocal(tmp_path)
    arquivo = tmp_path / "ano_mes=2024-01" / "parte_01.parquet"
    arquivo.parent.mkdir()
    arquivo.write_bytes(b"abcd")
    assert destino.publicar("ano_mes=2024-01", [arquivo]) == 4
    assert arquivo.read_bytes() == b"abcd"


def test_local_listar_prefixo_inexistente(tmp_path):
    assert ArmazenamentoLocal(tmp_path).listar("ano_mes=1999-01") == set()


# Dublê mínimo do FileSystemClient do SDK, só com o que o ArmazenamentoLake usa.
@dataclass
class _Caminho:
    name: str
    is_directory: bool = False


class _Arquivo:
    def __init__(self, fs, caminho):
        self.fs, self.caminho = fs, caminho

    def upload_data(self, dados, overwrite, **_):
        self.fs.arquivos[self.caminho] = dados if isinstance(dados, bytes) else dados.read()

    def download_file(self):
        if self.caminho not in self.fs.arquivos:
            raise ResourceNotFoundError("ausente")
        conteudo = self.fs.arquivos[self.caminho]
        return type("Download", (), {"readall": lambda _: conteudo})()


class _Diretorio:
    def __init__(self, fs, caminho):
        self.fs, self.caminho = fs, caminho

    def delete_directory(self):
        removidos = [c for c in self.fs.arquivos if c.startswith(self.caminho + "/")]
        if not removidos:
            raise ResourceNotFoundError("ausente")
        for c in removidos:
            del self.fs.arquivos[c]


class _FileSystemFalso:
    def __init__(self):
        self.arquivos: dict[str, bytes] = {}

    def get_file_client(self, caminho):
        return _Arquivo(self, caminho)

    def get_directory_client(self, caminho):
        return _Diretorio(self, caminho)

    def get_paths(self, path, recursive):
        caminhos = [_Caminho(c) for c in self.arquivos if c.startswith(path + "/")]
        if not caminhos:
            raise ResourceNotFoundError("ausente")
        return caminhos


def _lake():
    fs = _FileSystemFalso()
    return ArmazenamentoLake(ConfigLake(conta="stpi5"), cliente=fs), fs


def test_lake_publicar_substitui_o_mes(tmp_path):
    lake, fs = _lake()
    fs.arquivos["bronze/drivestats/ano_mes=2024-01/parte_29.parquet"] = b"velho"
    novo = tmp_path / "parte_01.parquet"
    novo.write_bytes(b"abc")

    assert lake.publicar("ano_mes=2024-01", [novo]) == 3
    assert fs.arquivos == {"bronze/drivestats/ano_mes=2024-01/parte_01.parquet": b"abc"}
    assert lake.listar("ano_mes=2024-01") == {"ano_mes=2024-01/parte_01.parquet"}


def test_lake_texto_e_ausentes():
    lake, _ = _lake()
    assert lake.ler_texto("_controle/2024-01.json") is None
    assert lake.listar("ano_mes=2024-01") == set()
    lake.gravar_texto("_controle/2024-01.json", "{}")
    assert lake.ler_texto("_controle/2024-01.json") == "{}"
