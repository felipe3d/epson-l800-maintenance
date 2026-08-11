#!/usr/bin/env bash
# =============================================================================
# Epson L800 — Head Cleaning via CUPS command file (sem app Epson!)
# =============================================================================
# Envia comandos de manutenção diretamente para o filtro commandtoescp
# do driver Epson, sem precisar do Epson Printer Utility 4.
#
# Uso: ./head_cleaning.sh [clean|test|report] [vezes]
#   clean  — Head Cleaning (padrão)
#   test   — Print Self Test Page (Nozzle Check)
#   report — Report ink levels
#
#   vezes  — número de ciclos (1-5, padrão: 1)
#
# Exemplos:
#   ./head_cleaning.sh clean        → 1 limpeza normal
#   ./head_cleaning.sh clean 3      → 3 limpezas em sequência
#   ./head_cleaning.sh test         → 1 teste de bicos
# =============================================================================

set -euo pipefail

PRINTER="${PRINTER:-EPSON_L800}"
ACTION="${1:-clean}"
COUNT="${2:-1}"

# Valida COUNT
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ] || [ "$COUNT" -gt 5 ]; then
    echo "❌ Número inválido: '$COUNT'. Use 1-5." >&2
    exit 1
fi

case "$ACTION" in
  clean)
    CMD="Clean all"
    LABEL="Head Cleaning"
    WAIT=180
    ;;
  test)
    CMD="PrintSelfTestPage"
    LABEL="Nozzle Test"
    WAIT=30
    ;;
  report)
    CMD="ReportLevels"
    LABEL="Ink Levels"
    WAIT=5
    ;;
  *)
    echo "Uso: $0 [clean|test|report] [vezes]" >&2
    exit 1
    ;;
esac

echo "🔧 Epson L800 — $LABEL × $COUNT"
echo

for i in $(seq 1 "$COUNT"); do
    echo "═══════════════════════════════════════════════"
    echo "  Ciclo $i de $COUNT — $LABEL"
    echo "═══════════════════════════════════════════════"

    # Cria o CUPS command file
    TMPFILE=$(mktemp /tmp/epson_XXXXXX) || { echo "❌ Erro ao criar temp file"; exit 1; }
    echo "#CUPS-COMMAND" > "$TMPFILE"
    echo "$CMD" >> "$TMPFILE"

    echo "   Comando: $CMD"
    
    # Envia via lp
    JOB_OUTPUT=$(lp -d "$PRINTER" -t "$LABEL $i" "$TMPFILE" 2>&1) || {
        echo "❌ Falha ao enviar job: $JOB_OUTPUT"
        rm -f "$TMPFILE"
        exit 1
    }
    echo "   Job enviado: $JOB_OUTPUT"
    rm -f "$TMPFILE"

    # Aguarda processamento
    sleep 3
    echo "   ⏳ Aguardando $WAIT segundos..."
    sleep "$WAIT"

    # Próximo ciclo
    if [ "$i" -lt "$COUNT" ]; then
        echo "   Intervalo entre ciclos: ${WAIT}s"
        sleep 10
    fi
done

echo
echo "✅ $COUNT × $LABEL concluído!"
echo "   Use './head_cleaning.sh test' para verificar os bicos."
