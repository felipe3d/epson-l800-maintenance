# Epson L800 — Ferramentas de Manutenção via USB

Conjunto de ferramentas open-source para resetar o contador de waste ink e limpar cabeças de impressão da **Epson L800** (e modelos L-series similares) diretamente via USB no **macOS** (também funciona no Linux).

Sem depender de softwares proprietários Windows, Adjustment Programs baixados da internet com risco de malware, ou chaves pagas de R$50+.

## 🖨️ Funcionalidades

| Função | Script | Comando |
|--------|--------|---------|
| **Resetar contador de waste ink** | `do_reset.py` | Zera todos os contadores de borra de tinta |
| **Ler contadores de waste** | `reset_l800.py` | Exibe valores atuais dos contadores |
| **Limpeza normal (todos bicos)** | `clean_heads.py 1` | Limpeza padrão da cabeça de impressão |
| **Limpeza apenas preto** | `clean_heads.py 2` | Limpeza seletiva dos bicos pretos |
| **Limpeza apenas cores** | `clean_heads.py 3` | Limpeza seletiva dos bicos coloridos |
| **Power Cleaning** | `clean_heads.py 4` | Limpeza profunda (mais tinta, mais eficaz) |
| **Teste de bicos** | `clean_heads.py 5` | Imprime padrão de verificação de jatos |

## 🚀 Como usar

### 1. Pré-requisitos

```bash
# Instalar libusb
brew install libusb

# Criar ambiente virtual com Python 3.11
uv venv --python 3.11 reinkpy-venv

# Instalar dependências (ordem importa para compatibilidade)
uv pip install "pyasn1==0.4.8" "pysnmp-lextudio==6.0.9"
uv pip install "reinkpy[ui,usb,net]@git+https://codeberg.org/atufi/reinkpy" --no-build-isolation
```

### 2. Resetar o contador de waste ink

**⚠️ Atenção:** Verifique o waste ink pad físico (compartimento na parte inferior da impressora). Se estiver encharcado, troque-o antes de resetar o contador para evitar vazamento de tinta.

```bash
cd ~/dev/epson
PYTHONPATH="" sudo reinkpy-venv/bin/python do_reset.py
```

A saída mostra os valores antes e depois do reset. Após executar, **desligue e ligue a impressora**.

### 3. Limpar cabeça de impressão

```bash
cd ~/dev/epson

# Teste de bicos (imprime padrão para conferir)
PYTHONPATH="" sudo reinkpy-venv/bin/python clean_heads.py 5

# Limpeza normal (todos os bicos)
PYTHONPATH="" sudo reinkpy-venv/bin/python clean_heads.py 1

# Power Cleaning (se a limpeza normal não resolver)
PYTHONPATH="" sudo reinkpy-venv/bin/python clean_heads.py 4
```

### 4. Ler status

```bash
PYTHONPATH="" sudo reinkpy-venv/bin/python reset_l800.py
```

## 🔧 Como funciona

### Stack tecnológica

- **[reinkpy](https://codeberg.org/atufi/reinkpy)** — Biblioteca Python open-source que implementa o protocolo IEEE 1284.4 (D4) de comunicação com impressoras Epson
- **[pyusb](https://github.com/pyusb/pyusb) + [libusb](https://libusb.info/)** — Acesso direto ao barramento USB
- **ESC/P2 Remote Mode** — Comandos padrão Epson para manutenção: `CH` (Clean Heads), `NC` (Nozzle Check), `TI` (Timer), `JE` (Job End)

### Protocolo de comunicação

```
[Python/CLI] → [reinkpy/D4] → [USB raw] → [Epson L800 IEEE 1284.4]
```

1. O script encontra a impressora via `idVendor=0x04b8` (Epson)
2. Estabelece sessão D4 (IEEE 1284.4) com o comando `@EJL 1284.4`
3. Abre o canal `EPSON-CTRL` (para comandos de EEPROM/fábrica) ou `EPSON-DATA` (para comandos ESC/P2)
4. Envia comandos Remote Mode ou de leitura/escrita de EEPROM

### Endereços EEPROM da L800

| Endereço | Tipo | Descrição |
|:--------:|:----:|-----------|
| 28-29 | Main | Contador principal de waste ink |
| 30-31 | Main 2 | Contador secundário |
| 32-33, 46-49 | Platen | Contador do platen (borra do papel) |

```python
# Chaves de acesso (já cadastradas no reinkpy)
rkey = 1430     # 0x0596 — read key
wkey = "tvogmpxf"  # write key
wkey1 = "sunflowe"  # write key alternativo
```

## 📁 Estrutura do projeto

```
~/dev/epson/
├── README.md              # Esta documentação
├── do_reset.py            # Script para resetar waste counter
├── clean_heads.py         # Script para limpeza de cabeça (CLI)
├── reset_l800.py          # Script para ler status
├── find_ip.py             # Descoberta de IP (Zeroconf)
├── check_printers.py      # Debug: lista dispositivos
├── .gitignore
├── reinkpy-venv/          # Virtualenv Python
│   └── lib/python3.11/site-packages/reinkpy/
└── epson_print_conf/      # Alternativa SNMP (não funciona na L800)
```

## ⚠️ Avisos importantes

1. **Sempre use `PYTHONPATH=""`** — impede conflitos com o virtualenv global do Hermes Agent
2. **`sudo` é obrigatório** — acesso a USB raw requer privilégios de root no macOS
3. **Power cycle a impressora** após resetar o waste counter
4. **Power Cleaning gasta muita tinta** — use com moderação (apenas se a limpeza normal não resolver 3x)
5. **Entre limpezas, aguarde ~3 min** para a bomba de sucção completar o ciclo
6. **Se a limpeza não resolver**, aguarde 12h (deixa a impressora descansar) e tente novamente

## 🧪 Testado em

- **Impressora:** Epson L800 (2011)
- **Sistema:** macOS Sequoia (ARM)
- **Conexão:** USB direta (não funciona via WiFi — L800 não expõe SNMP)
- **Python:** 3.11.15

## 📚 Referências

- [reinkpy — Código fonte](https://codeberg.org/atufi/reinkpy)
- [epson_print_conf — Alternativa via SNMP](https://github.com/Ircama/epson_print_conf)
- [epson_escp2 — Gerador de comandos ESC/P2](https://github.com/Ircama/epson_escp2)
- [Epson L800 Service Manual](https://mnogochernil.ru/newsroom/wp-content/uploads/2016/08/L800_L801_Service_manual.pdf)
- [Protocolo IEEE 1284.4 (Wikipedia)](https://en.wikipedia.org/wiki/IEEE_1284)

## 📄 Licença

Apache 2.0 — Este projeto é livre para uso, modificação e distribuição.

---

*Feito com ☕ e frustração com impressoras que travam sozinhas.*
