"""Catálogo dos atributos SMART trazidos para o pipeline.

Significados: smartmontools drivedb.h e Wikipedia (S.M.A.R.T.); preditores de
falha: Backblaze, "What SMART Stats Indicate Hard Drive Failures" (2016).

Critério de seleção: atributos com pelo menos 1% de valores não nulos em algum ano
da janela 2021-07..2026-06 (medido nos metadados Parquet da fonte). Os demais
(~50 atributos) aparecem em menos de 1% das linhas e ficam fora da extração.

Cada atributo gera duas colunas na camada silver:
    smart_<id com 3 dígitos>_<nome>_bruto       <- smart_<id>_raw
    smart_<id com 3 dígitos>_<nome>_normalizado <- smart_<id>_normalized
O valor "normalizado" é a escala do fabricante (em geral 1..253, maior = melhor);
o "bruto" é o contador/medida propriamente dita, cuja codificação pode variar por fabricante.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class AtributoSmart:
    id: int
    nome: str
    nome_original: str
    descricao: str
    midia: str = "HDD"  # HDD, SSD ou ambos
    fabricantes: str = "vários"
    preditor_falha: bool = False

    @property
    def prefixo(self) -> str:
        return f"smart_{self.id:03d}_{self.nome}"

    @property
    def coluna_bruto(self) -> str:
        return f"{self.prefixo}_bruto"

    @property
    def coluna_normalizado(self) -> str:
        return f"{self.prefixo}_normalizado"

    @property
    def fonte_bruto(self) -> str:
        return f"smart_{self.id}_raw"

    @property
    def fonte_normalizado(self) -> str:
        return f"smart_{self.id}_normalized"


ATRIBUTOS: list[AtributoSmart] = [
    AtributoSmart(
        1,
        "taxa_erros_leitura",
        "Raw Read Error Rate",
        "Taxa de erros de hardware na leitura de dados da superfície. "
        "No bruto da Seagate é um valor composto (não é contagem direta).",
        "ambos",
    ),
    AtributoSmart(
        2,
        "desempenho_throughput",
        "Throughput Performance",
        "Eficiência geral de throughput do disco medida pelo fabricante.",
    ),
    AtributoSmart(
        3,
        "tempo_spin_up",
        "Spin-Up Time",
        "Tempo médio para os pratos atingirem a rotação nominal (bruto geralmente em ms).",
    ),
    AtributoSmart(4, "contagem_start_stop", "Start/Stop Count", "Número de ciclos de partida/parada do motor do eixo."),
    AtributoSmart(
        5,
        "setores_realocados",
        "Reallocated Sectors Count",
        "Quantidade de setores defeituosos remapeados para a área reserva. Crescimento indica degradação da mídia.",
        "ambos",
        preditor_falha=True,
    ),
    AtributoSmart(
        7,
        "taxa_erros_seek",
        "Seek Error Rate",
        "Taxa de erros de posicionamento do cabeçote. No bruto da Seagate é um valor composto.",
    ),
    AtributoSmart(
        8, "desempenho_seek", "Seek Time Performance", "Desempenho médio das operações de posicionamento do cabeçote."
    ),
    AtributoSmart(
        9, "horas_ligado", "Power-On Hours", "Total de horas em que o disco esteve energizado (idade de uso).", "ambos"
    ),
    AtributoSmart(
        10,
        "tentativas_spin_up",
        "Spin Retry Count",
        "Tentativas repetidas de partida do motor até atingir a rotação nominal.",
    ),
    AtributoSmart(
        12, "ciclos_energia", "Power Cycle Count", "Quantidade de ciclos completos de liga/desliga.", "ambos"
    ),
    AtributoSmart(
        18,
        "saude_cabecotes",
        "Head_Health",
        "Autoavaliação de saúde dos cabeçotes (Seagate Exos).",
        fabricantes="Seagate",
    ),
    AtributoSmart(
        22,
        "nivel_helio",
        "Current Helium Level",
        "Nível de hélio interno em discos selados com hélio (normalizado 100 = nível nominal).",
        fabricantes="HGST/WDC",
    ),
    AtributoSmart(
        23,
        "helio_condicao_inferior",
        "Helium Condition Lower",
        "Condição do hélio - limite inferior (específico Toshiba).",
        fabricantes="Toshiba",
    ),
    AtributoSmart(
        24,
        "helio_condicao_superior",
        "Helium Condition Upper",
        "Condição do hélio - limite superior (específico Toshiba).",
        fabricantes="Toshiba",
    ),
    AtributoSmart(
        27,
        "saude_mamr",
        "MAMR_Health_Monitor",
        "Monitor de saúde da gravação assistida por micro-ondas (MAMR) - Toshiba MG09/MG10/MG11.",
        fabricantes="Toshiba",
    ),
    AtributoSmart(
        71,
        "microatuador",
        "Milli_Micro_Actuator",
        "Estado do microatuador de posicionamento do cabeçote "
        "(WDC Ultrastar HC570/HC590; sem documentação do fabricante).",
        fabricantes="WDC",
    ),
    AtributoSmart(
        90,
        "nand_mestre",
        "NAND_Master",
        "Indicador da memória NAND interna do HDD, bruto em formato hexadecimal "
        "(WDC Ultrastar HC570/HC590; sem documentação do fabricante).",
        fabricantes="WDC",
    ),
    AtributoSmart(
        173,
        "nivelamento_desgaste",
        "Wear Leveling Count",
        "Contagem de ciclos de apagamento/nivelamento de desgaste das células flash.",
        "SSD",
    ),
    AtributoSmart(
        174,
        "perdas_energia_inesperadas",
        "Unexpected Power Loss Count",
        "Quantidade de desligamentos sem o procedimento adequado (perda súbita de energia).",
        "SSD",
    ),
    AtributoSmart(
        183,
        "downshift_sata",
        "SATA Downshift Error Count / Runtime Bad Block",
        "Reduções de velocidade do link SATA; em alguns SSDs Samsung representa blocos ruins em execução.",
        "ambos",
    ),
    AtributoSmart(
        184,
        "erros_ponta_a_ponta",
        "End-to-End Error",
        "Erros de paridade na transferência entre cache (DRAM) e mídia.",
        "ambos",
    ),
    AtributoSmart(
        187,
        "erros_incorrigiveis_reportados",
        "Reported Uncorrectable Errors",
        "Erros que não puderam ser recuperados via ECC de hardware.",
        "ambos",
        preditor_falha=True,
    ),
    AtributoSmart(
        188,
        "timeouts_comando",
        "Command Timeout",
        "Operações abortadas por tempo esgotado (alimentação/cabos ou falha interna).",
        preditor_falha=True,
    ),
    AtributoSmart(
        189,
        "escritas_voo_alto",
        "High Fly Writes",
        "Escritas feitas com o cabeçote acima da altura de voo recomendada.",
    ),
    AtributoSmart(
        190,
        "temperatura_fluxo_ar",
        "Airflow Temperature",
        "Temperatura do fluxo de ar interno (em Seagate, bruto em °C; normalizado = 100 - temperatura).",
    ),
    AtributoSmart(191, "erros_sensor_choque", "G-Sense Error Rate", "Erros causados por choque ou vibração externos."),
    AtributoSmart(
        192,
        "recolhimentos_emergencia",
        "Power-off Retract Count",
        "Recolhimentos de emergência do cabeçote por perda de energia.",
    ),
    AtributoSmart(
        193, "ciclos_carga_descarga", "Load/Unload Cycle Count", "Ciclos de estacionamento do cabeçote na rampa."
    ),
    AtributoSmart(
        194,
        "temperatura",
        "Temperature",
        "Temperatura interna do disco em °C (byte menos significativo do bruto).",
        "ambos",
    ),
    AtributoSmart(
        195,
        "ecc_hardware_recuperado",
        "Hardware ECC Recovered",
        "Erros recuperados pelo ECC de hardware. "
        "Bruto específico do fabricante e frequentemente sem significado direto.",
        "ambos",
    ),
    AtributoSmart(
        196,
        "eventos_realocacao",
        "Reallocation Event Count",
        "Quantidade de operações de remapeamento (bem ou malsucedidas).",
        "ambos",
    ),
    AtributoSmart(
        197,
        "setores_pendentes",
        "Current Pending Sector Count",
        "Setores instáveis aguardando remapeamento.",
        "ambos",
        preditor_falha=True,
    ),
    AtributoSmart(
        198,
        "setores_incorrigiveis_offline",
        "Offline Uncorrectable Sector Count",
        "Setores com erro incorrigível detectados em varredura offline.",
        "ambos",
        preditor_falha=True,
    ),
    AtributoSmart(
        199,
        "erros_crc_udma",
        "UltraDMA CRC Error Count",
        "Erros de CRC na transferência pela interface (normalmente cabo/backplane).",
        "ambos",
    ),
    AtributoSmart(
        200,
        "taxa_erros_multizona",
        "Multi_Zone_Error_Rate / Pressure_Limit",
        "Erros encontrados durante a escrita; em discos Seagate com hélio corresponde a Pressure_Limit.",
    ),
    AtributoSmart(
        220,
        "deslocamento_prato",
        "Disk Shift",
        "Deslocamento do prato em relação ao eixo (choque/queda).",
        fabricantes="Toshiba",
    ),
    AtributoSmart(
        222,
        "horas_carregado",
        "Loaded Hours",
        "Horas com o cabeçote posicionado sobre os pratos (em operação).",
        fabricantes="Toshiba",
    ),
    AtributoSmart(
        223,
        "tentativas_carga_descarga",
        "Load/Unload Retry Count",
        "Tentativas repetidas de carregar/descarregar o cabeçote.",
    ),
    AtributoSmart(
        224, "friccao_carga", "Load Friction", "Resistência mecânica ao carregar o cabeçote.", fabricantes="Toshiba"
    ),
    AtributoSmart(
        226, "tempo_carga", "Load-in Time", "Tempo total de carregamento do cabeçote.", fabricantes="Toshiba"
    ),
    AtributoSmart(
        231,
        "vida_restante_ssd",
        "SSD_Life_Left / Temperature_Celsius",
        "Em SSDs, vida útil restante estimada (normalizado 100 = novo); em alguns HDDs é temperatura.",
        "SSD",
    ),
    AtributoSmart(
        240,
        "horas_voo_cabecote",
        "Head Flying Hours",
        "Horas de voo do cabeçote. "
        "Na Seagate o bruto empacota 32 bits de horas + 24 bits de ms: horas = bruto & 0xFFFFFFFF.",
    ),
    AtributoSmart(
        241,
        "total_lbas_escritos",
        "Total LBAs Written",
        "Total de blocos lógicos escritos. "
        "Unidade varia: LBA (em geral 512 bytes) em HDDs; alguns SSDs usam 1 GiB ou 32 MiB.",
        "ambos",
    ),
    AtributoSmart(
        242,
        "total_lbas_lidos",
        "Total LBAs Read",
        "Total de blocos lógicos lidos. Unidade varia como no atributo 241.",
        "ambos",
    ),
]

POR_ID = {a.id: a for a in ATRIBUTOS}
