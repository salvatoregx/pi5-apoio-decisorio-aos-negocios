#!/usr/bin/env bash
# Cria o ambiente do projeto no Azure. Idempotente: rodar de novo só completa o que faltar.
#
# Uso (Cloud Shell, já autenticado):  bash infra/provisionar.sh
# Variáveis opcionais: PREFIXO (pi5), LOCAL (brazilsouth), GRUPO (rg-pi5), ORCAMENTO_USD (25 por mês)
#
# Recursos:
#   - ADLS Gen2 com os containers "lake" (bronze/silver/gold) e "synapse" (padrão do workspace)
#   - Synapse Analytics, usando só o pool SQL serverless (cobrado por volume lido)
#   - Azure SQL Database na oferta gratuita, com pausa automática ao atingir o limite do mês
#   - Orçamento mensal com alertas por e-mail, quando a assinatura permitir
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=comum.sh
source ./comum.sh

ORCAMENTO_USD="${ORCAMENTO_USD:-25}"
USUARIO_ID="$(az ad signed-in-user show --query id -o tsv)"
USUARIO_UPN="$(az ad signed-in-user show --query userPrincipalName -o tsv)"
USUARIO_EMAIL="$(az ad signed-in-user show --query mail -o tsv)"
USUARIO_EMAIL="${USUARIO_EMAIL:-$USUARIO_UPN}"

etapa "Provedores de recursos"
for provedor in Microsoft.Storage Microsoft.Synapse Microsoft.Sql Microsoft.ContainerInstance Microsoft.ManagedIdentity; do
  az provider register --namespace "$provedor" --wait -o none
done

etapa "Grupo $GRUPO em $LOCAL"
az group create -n "$GRUPO" -l "$LOCAL" -o none

etapa "Data lake $STORAGE"
az storage account create -n "$STORAGE" -g "$GRUPO" -l "$LOCAL" \
  --kind StorageV2 --sku Standard_LRS --hns true \
  --min-tls-version TLS1_2 --allow-blob-public-access false -o none
STORAGE_ID="$(az storage account show -n "$STORAGE" -g "$GRUPO" --query id -o tsv)"
for container in "$CONTAINER_LAKE" "$CONTAINER_SYNAPSE"; do
  az storage container-rm create --storage-account "$STORAGE" -g "$GRUPO" -n "$container" -o none
done
# Leitura e escrita nos dados com a própria conta (az login), sem chaves de acesso.
atribuir_papel "$USUARIO_ID" User "Storage Blob Data Contributor" "$STORAGE_ID"

etapa "Synapse $SYNAPSE (pode levar alguns minutos)"
if ! existe az synapse workspace show -n "$SYNAPSE" -g "$GRUPO"; then
  # A senha SQL é exigida na criação, mas fica sem uso: logo abaixo o acesso passa a ser só Entra ID.
  senha="$(openssl rand -base64 24 | tr -d '/+=')Aa1!"
  az synapse workspace create -n "$SYNAPSE" -g "$GRUPO" -l "$LOCAL" \
    --storage-account "$STORAGE" --file-system "$CONTAINER_SYNAPSE" \
    --sql-admin-login-user "admpi5" --sql-admin-login-password "$senha" --only-show-errors -o none
  unset senha
fi
az synapse sql ad-admin create --workspace-name "$SYNAPSE" -g "$GRUPO" \
  --display-name "$USUARIO_UPN" --object-id "$USUARIO_ID" -o none
az synapse ad-only-auth enable --workspace-name "$SYNAPSE" -g "$GRUPO" -o none
# Os integrantes acessam de casa, com IPs dinâmicos; a proteção fica na autenticação Entra ID.
if ! existe az synapse workspace firewall-rule show -n PermitirTodos --workspace-name "$SYNAPSE" -g "$GRUPO"; then
  az synapse workspace firewall-rule create -n PermitirTodos --workspace-name "$SYNAPSE" -g "$GRUPO" \
    --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 -o none
fi
SYNAPSE_IDENTIDADE="$(az synapse workspace show -n "$SYNAPSE" -g "$GRUPO" --query identity.principalId -o tsv)"
atribuir_papel "$SYNAPSE_IDENTIDADE" ServicePrincipal "Storage Blob Data Contributor" "$STORAGE_ID"

etapa "Azure SQL $SQL_SERVIDOR/$SQL_BANCO (oferta gratuita)"
if ! existe az sql server show -n "$SQL_SERVIDOR" -g "$GRUPO"; then
  az sql server create -n "$SQL_SERVIDOR" -g "$GRUPO" -l "$LOCAL" \
    --enable-ad-only-auth --external-admin-principal-type User \
    --external-admin-name "$USUARIO_UPN" --external-admin-sid "$USUARIO_ID" -o none
fi
if ! existe az sql server firewall-rule show -n PermitirTodos -s "$SQL_SERVIDOR" -g "$GRUPO"; then
  az sql server firewall-rule create -n PermitirTodos -s "$SQL_SERVIDOR" -g "$GRUPO" \
    --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 -o none
fi
if ! existe az sql db show -n "$SQL_BANCO" -s "$SQL_SERVIDOR" -g "$GRUPO"; then
  az sql db create -n "$SQL_BANCO" -s "$SQL_SERVIDOR" -g "$GRUPO" \
    -e GeneralPurpose -f Gen5 -c 2 --compute-model Serverless --backup-storage-redundancy Local \
    --use-free-limit --free-limit-exhaustion-behavior AutoPause -o none
fi
# A pausa por inatividade fica no padrão de 60 min: com a oferta gratuita pausando ao esgotar a
# cota (AutoPause), o Azure não aceita outro valor (erro ProvisioningDisabled).

etapa "Orçamento de US\$ $ORCAMENTO_USD por mês, alertas para $USUARIO_EMAIL"
corpo="$(cat <<JSON
{
  "properties": {
    "category": "Cost",
    "amount": $ORCAMENTO_USD,
    "timeGrain": "Monthly",
    "timePeriod": {"startDate": "$(date -u +%Y-%m-01)T00:00:00Z"},
    "filter": {"dimensions": {"name": "ResourceGroupName", "operator": "In", "values": ["$GRUPO"]}},
    "notifications": {
      "real_50": {"enabled": true, "operator": "GreaterThan", "threshold": 50, "thresholdType": "Actual", "contactEmails": ["$USUARIO_EMAIL"]},
      "real_80": {"enabled": true, "operator": "GreaterThan", "threshold": 80, "thresholdType": "Actual", "contactEmails": ["$USUARIO_EMAIL"]},
      "previsto_100": {"enabled": true, "operator": "GreaterThan", "threshold": 100, "thresholdType": "Forecasted", "contactEmails": ["$USUARIO_EMAIL"]}
    }
  }
}
JSON
)"
if ! az rest --method put \
  --url "https://management.azure.com/subscriptions/$ASSINATURA/providers/Microsoft.Consumption/budgets/orcamento-$PREFIXO?api-version=2023-05-01" \
  --body "$corpo" -o none 2>/dev/null; then
  echo "Aviso: a assinatura não aceitou o orçamento. Acompanhe o crédito em https://www.microsoftazuresponsorships.com/"
fi

etapa "Pronto"
cat <<FIM
Data lake:  https://$STORAGE.dfs.core.windows.net/$CONTAINER_LAKE
Synapse:    https://web.azuresynapse.net (workspace $SYNAPSE)
            SQL serverless: $SYNAPSE-ondemand.sql.azuresynapse.net
Azure SQL:  $SQL_SERVIDOR.database.windows.net, banco $SQL_BANCO

Para extrair localmente direto para o lake:
  export PI5_ADLS_CONTA=$STORAGE
  uv run drivestats extrair --paralelo 2
FIM
