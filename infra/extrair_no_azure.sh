#!/usr/bin/env bash
# Roda a extração num contêiner do Azure (ACI), gravando direto no lake.
#
# Uso (Cloud Shell):  bash infra/extrair_no_azure.sh [opções do drivestats extrair]
#   ex.: bash infra/extrair_no_azure.sh --inicio 2021-07 --fim 2026-06
#
# O contêiner clona o repositório público, instala as dependências e roda `drivestats extrair`.
# A autenticação no lake é por identidade gerenciada: nenhuma chave passa pelo contêiner.
# Meses já extraídos são pulados, então rodar de novo só completa o que faltou.
#
# Variáveis opcionais: PARALELO (4), CPU (4), MEMORIA_GB (16), ETL_MEMORIA (2GB por processo),
# REVISAO (main), REPOSITORIO
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=comum.sh
source ./comum.sh

PARALELO="${PARALELO:-4}"
CPU="${CPU:-4}"
MEMORIA_GB="${MEMORIA_GB:-16}"
ETL_MEMORIA="${ETL_MEMORIA:-2GB}"
REVISAO="${REVISAO:-main}"
REPOSITORIO="${REPOSITORIO:-https://github.com/salvatoregx/pi5-apoio-decisorio-aos-negocios}"
IMAGEM="ghcr.io/astral-sh/uv:python3.12-bookworm"
IDENTIDADE="id-${PREFIXO}-extracao"
CONTEINER="aci-${PREFIXO}-extracao"

etapa "Identidade gerenciada $IDENTIDADE"
if ! existe az identity show -n "$IDENTIDADE" -g "$GRUPO"; then
  az identity create -n "$IDENTIDADE" -g "$GRUPO" -l "$LOCAL" -o none
fi
identidade() { az identity show -n "$IDENTIDADE" -g "$GRUPO" --query "$1" -o tsv; }
IDENTIDADE_ID="$(identidade id)"
IDENTIDADE_CLIENTE="$(identidade clientId)"
IDENTIDADE_PRINCIPAL="$(identidade principalId)"
STORAGE_ID="$(az storage account show -n "$STORAGE" -g "$GRUPO" --query id -o tsv)"
atribuir_papel "$IDENTIDADE_PRINCIPAL" ServicePrincipal "Storage Blob Data Contributor" "$STORAGE_ID"
if [[ "$PAPEL_CRIADO" == true ]]; then
  echo "Aguardando a propagação do papel recém-criado (2 min)..."
  sleep 120
fi

etapa "Contêiner $CONTEINER ($CPU vCPU, $MEMORIA_GB GB, $PARALELO meses por vez)"
if existe az container show -n "$CONTEINER" -g "$GRUPO"; then
  az container delete -n "$CONTEINER" -g "$GRUPO" -y -o none
fi
comando="git clone --depth 1 --branch $REVISAO $REPOSITORIO /app && cd /app"
comando+=" && uv sync --locked --no-dev"
comando+=" && uv run --no-dev drivestats extrair --destino lake --paralelo $PARALELO $*"
az container create -n "$CONTEINER" -g "$GRUPO" -l "$LOCAL" \
  --image "$IMAGEM" --os-type Linux --cpu "$CPU" --memory "$MEMORIA_GB" \
  --restart-policy Never --assign-identity "$IDENTIDADE_ID" \
  --environment-variables \
    PI5_ADLS_CONTA="$STORAGE" PI5_ADLS_CONTAINER="$CONTAINER_LAKE" PI5_DIR_DADOS=/dados \
    AZURE_CLIENT_ID="$IDENTIDADE_CLIENTE" ETL_MEMORIA="$ETL_MEMORIA" ETL_THREADS=2 \
  --command-line "/bin/bash -c '$comando'" -o none

etapa "Extração iniciada"
cat <<FIM
Acompanhar o log:     az container logs -n $CONTEINER -g $GRUPO --follow
Situação:             az container show -n $CONTEINER -g $GRUPO --query "containers[0].instanceView.currentState" -o table
Apagar ao terminar:   az container delete -n $CONTEINER -g $GRUPO -y

O contêiner só é cobrado enquanto roda; ao terminar, fica parado até ser apagado.
FIM
