"""Destino da camada bronze: diretório local ou ADLS Gen2.

Os caminhos são sempre relativos à raiz do destino e usam "/" (ex.: `ano_mes=2024-01/parte_01.parquet`).
"""

from __future__ import annotations

import shutil
from contextlib import suppress
from pathlib import Path
from typing import TYPE_CHECKING, Protocol

from drivestats_el.configuracao import ConfigLake

if TYPE_CHECKING:
    from azure.storage.filedatalake import FileSystemClient


class Armazenamento(Protocol):
    descricao: str

    def listar(self, prefixo: str) -> set[str]:
        """Arquivos sob o prefixo, com caminho relativo à raiz. Prefixo inexistente devolve vazio."""
        ...

    def ler_texto(self, caminho: str) -> str | None: ...

    def gravar_texto(self, caminho: str, conteudo: str) -> None: ...

    def publicar(self, prefixo: str, arquivos: list[Path]) -> int:
        """Substitui o conteúdo do prefixo pelos arquivos informados. Devolve o total de bytes."""
        ...


class ArmazenamentoLocal:
    def __init__(self, raiz: Path):
        self.raiz = raiz
        self.descricao = str(raiz)

    def listar(self, prefixo: str) -> set[str]:
        base = self.raiz / prefixo
        if not base.exists():
            return set()
        return {p.relative_to(self.raiz).as_posix() for p in base.rglob("*") if p.is_file()}

    def ler_texto(self, caminho: str) -> str | None:
        arquivo = self.raiz / caminho
        return arquivo.read_text(encoding="utf-8") if arquivo.exists() else None

    def gravar_texto(self, caminho: str, conteudo: str) -> None:
        arquivo = self.raiz / caminho
        arquivo.parent.mkdir(parents=True, exist_ok=True)
        temporario = arquivo.with_name(arquivo.name + ".tmp")
        temporario.write_text(conteudo, encoding="utf-8")
        temporario.replace(arquivo)

    def publicar(self, prefixo: str, arquivos: list[Path]) -> int:
        destino = self.raiz / prefixo
        destino.mkdir(parents=True, exist_ok=True)
        nomes = {a.name for a in arquivos}
        for antigo in destino.iterdir():
            if antigo.is_file() and antigo.name not in nomes:
                antigo.unlink()
        for arquivo in arquivos:
            # A extração local grava direto no destino; só copia quando vem de outro lugar.
            if arquivo.resolve() != (destino / arquivo.name).resolve():
                shutil.copy2(arquivo, destino / arquivo.name)
        return sum((destino / nome).stat().st_size for nome in nomes)


class ArmazenamentoLake:
    """ADLS Gen2 com autenticação do DefaultAzureCredential.

    Na máquina local usa o `az login`; no contêiner do Azure, a identidade gerenciada.
    """

    def __init__(self, config: ConfigLake, cliente: FileSystemClient | None = None):
        self.config = config
        self.descricao = f"{config.url}/{config.container}/{config.diretorio}"
        self._fs = cliente or _cliente_file_system(config)

    def _caminho(self, relativo: str) -> str:
        return f"{self.config.diretorio}/{relativo}".strip("/")

    def listar(self, prefixo: str) -> set[str]:
        from azure.core.exceptions import ResourceNotFoundError

        base = self.config.diretorio + "/"
        try:
            caminhos = self._fs.get_paths(path=self._caminho(prefixo), recursive=True)
            return {p.name.removeprefix(base) for p in caminhos if not p.is_directory}
        except ResourceNotFoundError:
            return set()

    def ler_texto(self, caminho: str) -> str | None:
        from azure.core.exceptions import ResourceNotFoundError

        try:
            return self._fs.get_file_client(self._caminho(caminho)).download_file().readall().decode("utf-8")
        except ResourceNotFoundError:
            return None

    def gravar_texto(self, caminho: str, conteudo: str) -> None:
        self._fs.get_file_client(self._caminho(caminho)).upload_data(conteudo.encode("utf-8"), overwrite=True)

    def publicar(self, prefixo: str, arquivos: list[Path]) -> int:
        from azure.core.exceptions import ResourceNotFoundError

        with suppress(ResourceNotFoundError):
            self._fs.get_directory_client(self._caminho(prefixo)).delete_directory()
        total = 0
        for arquivo in arquivos:
            cliente = self._fs.get_file_client(self._caminho(f"{prefixo}/{arquivo.name}"))
            with arquivo.open("rb") as dados:
                cliente.upload_data(dados, overwrite=True, length=arquivo.stat().st_size, max_concurrency=4)
            total += arquivo.stat().st_size
        return total


def _cliente_file_system(config: ConfigLake) -> FileSystemClient:
    from azure.identity import DefaultAzureCredential
    from azure.storage.filedatalake import DataLakeServiceClient

    servico = DataLakeServiceClient(config.url, credential=DefaultAzureCredential())
    return servico.get_file_system_client(config.container)


def abrir(lake: ConfigLake | None, dir_local: Path) -> Armazenamento:
    """Lake quando configurado (PI5_ADLS_CONTA); senão, diretório local."""
    return ArmazenamentoLake(lake) if lake else ArmazenamentoLocal(dir_local)
