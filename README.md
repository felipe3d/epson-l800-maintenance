# Epson L800 — Ferramentas de Manutenção

Conjunto de ferramentas para resetar o contador de waste ink e limpar cabeças de impressão da **Epson L800** (e L-series similares) no **macOS**.

**Sem softwares Windows, Adjustment Program baixado da internet, ou chaves pagas de R\$50+.**

## 🖨️ Funcionalidades

| Função | Como fazer | Status |
|--------|-----------|--------|
| **Resetar waste ink** | `do_reset.py` | ✅ Funciona via USB/D4 |
| **Ler contadores** | `reset_l800.py` | ✅ Funciona via USB/D4 |
| **Head Cleaning** | `./head_cleaning.sh clean [N]` | ✅ Funciona via CUPS |
| **Power Ink Flushing** | `./head_cleaning.sh clean [N]` (usa `Clean all`) | ✅ Funciona via CUPS |
| **Teste de bicos** | `./head_cleaning.sh test` | ✅ Funciona via CUPS |
| **Report níveis de tinta** | `./head_cleaning.sh report` | ✅ Funciona via CUPS |

## 🚀 Como usar

### Head Cleaning (sem app Epson!)

```bash
cd ~/dev/epson
./head_cleaning.sh clean       # 1 limpeza normal
./head_cleaning.sh clean 3     # 3 limpezas consecutivas
./head_cleaning.sh test        # teste de bicos (nozzle check)
./head_cleaning.sh report      # níveis de tinta
```

Envia comandos de manutenção diretamente via CUPS command file (`application/vnd.cups-command`) — o filtro `commandtoescp` do driver Epson traduz `Clean all` / `PrintSelfTestPage` / `ReportLevels` para ESC/P2 na impressora.

**Não precisa de sudo, Python, reinkpy, libusb, AppleScript, nem do app Epson Printer Utility 4.**

### Resetar waste ink

```bash
cd ~/dev/epson
PYTHONPATH="" sudo reinkpy-venv/bin/python do_reset.py
```

**⚠️** Verifique o waste ink pad físico antes de resetar. Se estiver encharcado, troque-o.

### Ler status / contadores

```bash
PYTHONPATH="" sudo reinkpy-venv/bin/python reset_l800.py
```

## 🔧 Stack

| Camada | Tecnologia | Uso |
|--------|-----------|-----|
| Head Cleaning | CUPS + commandtoescp (driver Epson oficial) | `lp -d PRINTER arquivo.txt` com `#CUPS-COMMAND` |
| Waste Reset | [reinkpy](https://codeberg.org/atufi/reinkpy) + D4/IEEE 1284.4 via USB | `sudo python do_reset.py` |
| USB backend | pyusb + libusb | Comunicação raw |

### Por que não usar clean_heads.py?

O script `clean_heads.py` envia comandos ESC/P2 Remote Mode (`CH`, `NC`) via canal D4 direto no USB, mas a L800 **não processa** esses comandos sem o contexto do driver oficial. O CUPS command file (`head_cleaning.sh`) resolveu o problema usando o filtro proprietário `commandtoescp` da Epson, que prepara o job de manutenção corretamente.

## 📁 Estrutura

```
~/dev/epson/
├── README.md
├── head_cleaning.sh       # 🏆 Head Cleaning via CUPS (sem sudo, sem app)
├── do_reset.py            # Reset waste ink (precisa sudo)
├── reset_l800.py          # Ler contadores / status
├── clean_heads.py         # Alternativa via USB/D4 (não funciona na L800)
├── find_ip.py             # Descoberta de IP via Zeroconf
├── check_printers.py      # Lista dispositivos USB
├── reset_ink_levels.py    # Reset nível de tinta via USB/D4 (experimental)
├── reinkpy-venv/          # Virtualenv Python
└── epson_print_conf/      # Alternativa SNMP (não funciona na L800)
```

## ⚠️ Dicas

1. **Power cycle** a impressora após resetar waste counter
2. **Aguarde ~3 min** entre limpezas para a bomba completar o ciclo
3. Se a limpeza não resolver, aguarde 12h e tente novamente
4. **Códigos de tinta preta L800** (quando o alerta "ink is low" aparecer): QJK-8M3-8SK-WE7N, TQY-9DL-2WA-98EA, L5H-8YL-MGG-2CDJ e vários outros no repositório

## 🧪 Testado em

- **Impressora:** Epson L800 (2011)
- **Sistema:** macOS Sequoia 26.x (ARM)
- **Conexão:** USB

## 📚 Referências

- [reinkpy](https://codeberg.org/atufi/reinkpy) — Protocolo D4/IEEE 1284.4
- [CUPS Command File Format](https://www.cups.org/doc/spec-command.html) — Especificação oficial
- [Epson L800 Service Manual](https://mnogochernil.ru/newsroom/wp-content/uploads/2016/08/L800_L801_Service_manual.pdf)
- [Protocolo IEEE 1284.4](https://en.wikipedia.org/wiki/IEEE_1284)
