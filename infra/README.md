# infra

Provisionamento do ambiente no Azure (assinatura Azure for Students), com az CLI.

| Recurso | Nome | Uso |
|---|---|---|
| Grupo de recursos | `rg-pi5` | agrupa tudo; apagar o grupo remove o projeto inteiro |
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

## Decisões de segurança

- **Sem senhas nem chaves.** Synapse e Azure SQL aceitam só autenticação Entra ID, e o acesso
  aos dados do lake é por papel (RBAC). A senha SQL que o Synapse exige na criação é gerada
  aleatoriamente e descartada.
- **Firewall aberto, autenticação fechada.** Os integrantes acessam de casa, com IPs dinâmicos.
  O firewall libera qualquer IP, e a proteção fica no login Entra ID.
- **Orçamento.** O script tenta criar um orçamento mensal (US$ 25 por padrão) com alertas por
  e-mail. Algumas assinaturas de estudante não aceitam; nesse caso, acompanhe o crédito em
  <https://www.microsoftazuresponsorships.com/>.
