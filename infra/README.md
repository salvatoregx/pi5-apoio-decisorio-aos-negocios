# infra

Provisionamento do ambiente no Azure (assinatura Azure for Students).

Recursos, todos no grupo `rg-pi5`:

- **ADLS Gen2**: data lake com as camadas `bronze`, `silver` e `gold`.
- **Synapse Analytics**: somente o pool SQL serverless, cobrado por volume lido.
- **Azure SQL Database**: oferta gratuita com pausa automática ao atingir o limite mensal.
