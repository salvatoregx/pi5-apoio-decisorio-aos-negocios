# Nomes dos recursos e funções compartilhadas pelos scripts de infra. Uso: source infra/comum.sh
#
# Os nomes globais (storage, Synapse, SQL) recebem um sufixo derivado da assinatura:
# são únicos no Azure e iguais em toda execução, o que deixa os scripts idempotentes.
# shellcheck disable=SC2034  # variáveis usadas pelos scripts que carregam este arquivo

PREFIXO="${PREFIXO:-pi5}"
# Assinaturas Azure for Students só criam servidores SQL (e, portanto, Synapse) em
# algumas regiões. Ver infra/README.md.
LOCAL="${LOCAL:-brazilsouth}"
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
#
# Tenta criar sempre e aceita "já existe". Consultar antes não é confiável: depois que um recurso
# é apagado, a atribuição antiga continua listada por um tempo e não vale para um recurso novo
# com o mesmo nome.
# Marca PAPEL_CRIADO=true quando cria a atribuição: o Azure leva alguns minutos para aplicá-la.
PAPEL_CRIADO=false
atribuir_papel() {
  local principal="$1" tipo="$2" papel="$3" escopo="$4" saida
  if [[ -z "$principal" || -z "$escopo" ]]; then
    echo "atribuir_papel: principal ou escopo vazio ($papel)" >&2
    return 1
  fi
  if saida="$(az role assignment create --assignee-object-id "$principal" --assignee-principal-type "$tipo" \
    --role "$papel" --scope "$escopo" -o none 2>&1)"; then
    PAPEL_CRIADO=true
  elif [[ "$saida" != *RoleAssignmentExists* && "$saida" != *"already exists"* ]]; then
    echo "$saida" >&2
    return 1
  fi
}
