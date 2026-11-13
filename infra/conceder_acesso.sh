#!/usr/bin/env bash
# Dá acesso ao ambiente para integrantes do grupo ou, com --leitura, para visitantes (ex.: professor).
#
# Uso (Cloud Shell):
#   bash infra/conceder_acesso.sh            usuario1@senacsp.edu.br usuario2@senacsp.edu.br
#   bash infra/conceder_acesso.sh --leitura  professor@senacsp.edu.br
#
# Os e-mails entram só como argumento: nada fica gravado no repositório.
#
# Perfil contribuição: ver os recursos no portal, ler e gravar no lake, administrar o SQL do Synapse.
# Perfil leitura:      ver os recursos no portal, ler o lake, abrir o Synapse Studio.
#
# Acessos dentro dos bancos (Synapse serverless e Azure SQL) são concedidos por T-SQL: o script
# imprime os comandos ao final, para rodar no Synapse Studio e no editor de consultas do Azure SQL.
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=comum.sh
source ./comum.sh

perfil="contribuicao"
if [[ "${1:-}" == "--leitura" ]]; then
  perfil="leitura"
  shift
fi
if [[ $# -eq 0 ]]; then
  echo "Uso: bash infra/conceder_acesso.sh [--leitura] email1 [email2 ...]" >&2
  exit 1
fi

etapa "Conferindo os usuários no diretório"
declare -A ids
faltando=()
for email in "$@"; do
  if id="$(az ad user show --id "$email" --query id -o tsv 2>/dev/null)" && [[ -n "$id" ]]; then
    ids["$email"]="$id"
    echo "ok: $email"
  else
    faltando+=("$email")
  fi
done
if [[ ${#faltando[@]} -gt 0 ]]; then
  printf 'Não encontrado no diretório: %s\n' "${faltando[@]}" >&2
  echo "Nada foi alterado. Corrija os e-mails e rode de novo." >&2
  exit 1
fi

GRUPO_ID="$(az group show -n "$GRUPO" --query id -o tsv)"
STORAGE_ID="$(az storage account show -n "$STORAGE" -g "$GRUPO" --query id -o tsv)"
if [[ "$perfil" == "contribuicao" ]]; then
  papel_lake="Storage Blob Data Contributor"
  papeis_synapse=("Synapse Contributor" "Synapse SQL Administrator")
else
  papel_lake="Storage Blob Data Reader"
  papeis_synapse=("Synapse User")
fi

for email in "$@"; do
  etapa "$email ($perfil)"
  principal="${ids[$email]}"
  atribuir_papel "$principal" User "Reader" "$GRUPO_ID"
  atribuir_papel "$principal" User "$papel_lake" "$STORAGE_ID"
  for papel in "${papeis_synapse[@]}"; do
    if [[ -z "$(az synapse role assignment list --workspace-name "$SYNAPSE" --assignee-object-id "$principal" \
      --role "$papel" --query '[0].id' -o tsv)" ]]; then
      az synapse role assignment create --workspace-name "$SYNAPSE" --role "$papel" \
        --assignee-object-id "$principal" --assignee-principal-type User -o none
    fi
  done
done

etapa "Acesso dentro dos bancos (T-SQL)"
if [[ "$perfil" == "contribuicao" ]]; then
  papeis_sql="db_ddladmin db_datareader db_datawriter"
else
  papeis_sql="db_datareader"
fi
{
  echo "-- Azure SQL: editor de consultas do portal, banco $SQL_BANCO (login com a conta administradora)"
  for email in "$@"; do
    echo "IF USER_ID('$email') IS NULL CREATE USER [$email] FROM EXTERNAL PROVIDER;"
    for papel in $papeis_sql; do
      echo "ALTER ROLE $papel ADD MEMBER [$email];"
    done
  done
  if [[ "$perfil" == "contribuicao" ]]; then
    echo "-- Identidade do Synapse, para a carga da gold (Copy do Synapse Pipelines)"
    echo "IF USER_ID('$SYNAPSE') IS NULL CREATE USER [$SYNAPSE] FROM EXTERNAL PROVIDER;"
    for papel in db_ddladmin db_datareader db_datawriter; do
      echo "ALTER ROLE $papel ADD MEMBER [$SYNAPSE];"
    done
  else
    echo
    echo "-- Synapse serverless: Synapse Studio, banco master (contribuidores já têm acesso pelo papel do Synapse)"
    for email in "$@"; do
      echo "IF SUSER_ID('$email') IS NULL CREATE LOGIN [$email] FROM EXTERNAL PROVIDER;"
    done
    echo "-- Depois, no banco pi5 (quando existir):"
    for email in "$@"; do
      echo "IF USER_ID('$email') IS NULL CREATE USER [$email] FROM LOGIN [$email];"
      echo "ALTER ROLE db_datareader ADD MEMBER [$email];"
      echo "GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::identidade_workspace TO [$email];"
    done
  fi
}

if [[ "$PAPEL_CRIADO" == true ]]; then
  echo
  echo "Papéis novos levam alguns minutos para valer. Peça para sair e entrar de novo no portal e no Synapse Studio."
fi
