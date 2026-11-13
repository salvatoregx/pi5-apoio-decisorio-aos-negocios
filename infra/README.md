# infra

Provisionamento do ambiente no Azure (assinatura Azure for Students), com az CLI.

| Recurso | Nome | Uso |
|---|---|---|
| Grupo de recursos | `rg-pi5` (Brazil South) | agrupa tudo; apagar o grupo remove o projeto inteiro |
| ADLS Gen2 | `stpi5<sufixo>` | container `lake` com `bronze/`, `silver/` e `gold/`; container `synapse`, padrão do workspace |
| Synapse Analytics | `syn-pi5-<sufixo>` | só o pool SQL serverless, cobrado por volume lido |
| Azure SQL Database | `sql-pi5-<sufixo>` / `dw` | DW na oferta gratuita, com pausa automática ao atingir o limite do mês |

O sufixo vem da assinatura: os nomes são únicos no Azure e iguais em toda execução.

## Como provisionar

No [Cloud Shell](https://shell.azure.com) (Bash), que já entra autenticado:

```bash
git clone https://github.com/salvatoregx/pi5-apoio-decisorio-aos-negocios
bash pi5-apoio-decisorio-aos-negocios/infra/provisionar.sh
```

O script é idempotente: se algo falhar no meio, basta rodar de novo. Ao final, ele mostra
os endereços do lake, do Synapse e do Azure SQL.

## Região

A região padrão é **Brazil South** (`LOCAL=brazilsouth`), mais próxima dos integrantes.

Assinaturas Azure for Students só têm acesso a um conjunto limitado de regiões para o Azure SQL,
e o Synapse depende dele. Em East US 2 a criação falhou com `SqlServerRegionDoesNotAllowProvisioning`.
Em 13/11/2026, criando um servidor SQL vazio de teste em cada região, a assinatura do projeto
aceitou Brazil South, Central US, West US 3, Canada Central e Sweden Central, e recusou
East US, East US 2, West US 2, UK South e North Europe. A restrição varia por assinatura;
para usar outra região, teste antes da mesma forma:

```bash
OID=$(az ad signed-in-user show --query id -o tsv); UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
az group create -n rg-teste-regiao -l brazilsouth -o none
for r in brazilsouth centralus; do
  n="sqlteste$RANDOM"
  if az sql server create -n "$n" -g rg-teste-regiao -l "$r" --enable-ad-only-auth --external-admin-principal-type User \
       --external-admin-name "$UPN" --external-admin-sid "$OID" -o none 2>/dev/null; then
    echo "$r: aceita"; az sql server delete -n "$n" -g rg-teste-regiao -y -o none
  else
    echo "$r: bloqueada"
  fi
done
az group delete -n rg-teste-regiao -y --no-wait
```

Referência: [Resolve capacity errors with Azure SQL](https://learn.microsoft.com/azure/azure-sql/capacity-errors-troubleshoot),
seção *Azure Program regions*.

## Decisões de segurança

- **Sem senhas nem chaves.** Synapse e Azure SQL aceitam só autenticação Entra ID, e o acesso
  aos dados do lake é por papel (RBAC). A senha SQL que o Synapse exige na criação é gerada
  aleatoriamente e descartada.
- **Firewall aberto, autenticação fechada.** Os integrantes acessam de casa, com IPs dinâmicos.
  O firewall libera qualquer IP, e a proteção fica no login Entra ID.
- **Orçamento.** O script tenta criar um orçamento mensal (US$ 25 por padrão) com alertas por
  e-mail. Algumas assinaturas de estudante não aceitam; nesse caso, acompanhe o crédito em
  <https://www.microsoftazuresponsorships.com/>.
