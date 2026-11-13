# Nomes dos recursos e funções compartilhadas pelos scripts de infra. Uso: source infra/comum.sh
#
# Os nomes globais (storage, Synapse, SQL) recebem um sufixo derivado da assinatura:
# são únicos no Azure e iguais em toda execução, o que deixa os scripts idempotentes.
# shellcheck disable=SC2034  # variáveis usadas pelos scripts que carregam este arquivo

PREFIXO="${PREFIXO:-pi5}"
LOCAL="${LOCAL:-eastus2}"
GRUPO="${GRUPO:-rg-$PREFIXO}"

ASSINATURA="$(az account show --query id -o tsv)"
SUFIXO="$(printf '%s' "$ASSINATURA" | sha256sum | cut -c1-6)"

STORAGE="st${PREFIXO}${SUFIXO}"
CONTAINER_LAKE="lake"
CONTAINER_SYNAPSE="synapse"
SYNAPSE="syn-${PREFIXO}-${SUFIXO}"
SQL_SERVIDOR="sql-${PREFIXO}-${SUFIXO}"
SQL_BANCO="dw"

etapa() { printf '\n== %s\n' "$*"; }

existe() { "$@" --only-show-errors -o none 2>/dev/null; }

# atribuir_papel <object-id> <User|ServicePrincipal|Group> <papel> <escopo>
atribuir_papel() {
  local principal="$1" tipo="$2" papel="$3" escopo="$4"
  if [[ -z "$(az role assignment list --assignee "$principal" --role "$papel" --scope "$escopo" --query '[0].id' -o tsv)" ]]; then
    az role assignment create --assignee-object-id "$principal" --assignee-principal-type "$tipo" \
      --role "$papel" --scope "$escopo" -o none
  fi
}
