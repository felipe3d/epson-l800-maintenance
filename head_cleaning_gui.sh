#!/usr/bin/env bash
# =============================================================================
# Epson L800 — Head Cleaning via Epson Printer Utility 4 (macOS GUI automation)
# =============================================================================
# Controla o Epson Printer Utility 4 via AppleScript para executar N ciclos
# consecutivos de limpeza de cabeça com intervalo controlado entre eles.
#
# Uso: ./head_cleaning_gui.sh [clean|flush|nozzle] [vezes]
#   clean   — Head Cleaning (padrão)
#   flush   — Power Ink Flushing
#   nozzle  — Nozzle Check
#
#   vezes   — número de ciclos consecutivos (padrão: 1, máximo: 5)
#
# Exemplos:
#   ./head_cleaning_gui.sh clean      → 1 limpeza normal
#   ./head_cleaning_gui.sh clean 3    → 3 limpezas normais em sequência
#   ./head_cleaning_gui.sh flush 2    → 2 Power Cleaning em sequência
#   ./head_cleaning_gui.sh nozzle     → 1 teste de bicos
# =============================================================================

set -euo pipefail

APP_PATH="/Library/Printers/EPSON/InkjetPrinter2/Utility/UT4/Epson Printer Utility 4.app"
ACTION="${1:-clean}"
COUNT="${2:-1}"

# Valida COUNT
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ] || [ "$COUNT" -gt 5 ]; then
    echo "❌ Número de ciclos inválido: '$COUNT'. Use entre 1 e 5."
    exit 1
fi

# Mapeia ação para o label do botão (texto ao lado do ícone)
case "$ACTION" in
  clean)
    BTN_LABEL="Head Cleaning"
    CYCLE_WAIT=180  # 3 min para Head Cleaning
    ;;
  flush)
    BTN_LABEL="Power Ink Flushing"
    CYCLE_WAIT=300  # 5 min para Power Flushing
    ;;
  nozzle)
    BTN_LABEL="Nozzle Check"
    CYCLE_WAIT=30   # 30s para Nozzle Check
    ;;
  *)
    echo "Uso: $0 [clean|flush|nozzle] [vezes]"
    echo "  clean   — Head Cleaning (padrão)"
    echo "  flush   — Power Ink Flushing"
    echo "  nozzle  — Nozzle Check"
    echo "  vezes   — número de ciclos (1-5, padrão: 1)"
    exit 1
    ;;
esac

echo "🔧 Epson L800 — $BTN_LABEL × $COUNT"
echo "   Aguardo entre ciclos: ${CYCLE_WAIT}s"
echo ""

# Abre o app se não estiver rodando
if ! pgrep -x "Epson Printer Utility 4" >/dev/null 2>&1; then
    echo "   Abrindo Epson Printer Utility 4..."
    open "$APP_PATH"
    sleep 4
fi

# =============================================================================
# Função: aguarda o fim do ciclo monitorando a janela
# =============================================================================
wait_for_cycle_end() {
    local max_wait=$((CYCLE_WAIT + 60))  # tolerância de 1 min
    local waited=0
    local step=5

    echo "   ⏳ Aguardando fim do ciclo (timeout: ${max_wait}s)..."
    
    while [ "$waited" -lt "$max_wait" ]; do
        sleep "$step"
        waited=$((waited + step))

        # Verifica se apareceu a mensagem de conclusão
        local check=$(osascript -e '
            tell application "System Events"
                tell process "Epson Printer Utility 4"
                    try
                        set allElems to entire contents of window 1
                        repeat with elem in allElems
                            try
                                set r to role of elem
                                set v to ""
                                try
                                    set v to value of elem
                                end try
                                if r is "AXStaticText" and v contains "cleaning cycle" then
                                    return "DONE"
                                end if
                            end try
                        end repeat
                    end try
                end tell
            end tell
            return "WAITING"
        ' 2>/dev/null || echo "WAITING")

        if [ "$check" = "DONE" ]; then
            echo "   ✅ Ciclo finalizado (${waited}s)"
            sleep 1
            return 0
        fi

        # Feedback progresso
        if [ $((waited % 30)) -eq 0 ]; then
            echo "   ... ${waited}s aguardados"
        fi
    done

    echo "   ⚠️  Timeout após ${waited}s — continuando mesmo assim"
    return 0
}

# =============================================================================
# Função: clica no botão Finish para fechar a tela de conclusão
# =============================================================================
click_finish() {
    osascript -e '
        tell application "System Events"
            tell process "Epson Printer Utility 4"
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        set r to role of elem
                        set v to ""
                        try
                            set v to value of elem
                        end try
                        if r is "AXStaticText" and (v contains "cleaning cycle" or v contains "finished") then
                            -- Acha o botão Finish próximo (canto inf. direito)
                            set allElems2 to entire contents of window 1
                            repeat with e2 in allElems2
                                try
                                    set r2 to role of e2
                                    set v2 to ""
                                    try
                                        set v2 to value of e2
                                    end try
                                    if r2 is "AXButton" and (v2 is "Finish" or v2 is "OK") then
                                        click e2
                                        return "OK"
                                    end if
                                    if r2 is "AXButton" then
                                        set p to position of e2
                                        set s to size of e2
                                        if (item 1 of s) > 50 and (item 2 of p) > 1400 then
                                            click e2
                                            return "OK"
                                        end if
                                    end if
                                end try
                            end repeat
                        end if
                    end try
                end repeat
                -- Fallback: clica no último botão grande
                set lastBtn to 0
                set allElems2 to entire contents of window 1
                repeat with e2 in allElems2
                    try
                        set r2 to role of e2
                        if r2 is "AXButton" then
                            set p to position of e2
                            set s to size of e2
                            if (item 1 of s) > 50 and (item 2 of p) > 1400 then
                                set lastBtn to e2
                            end if
                        end if
                    end try
                end repeat
                if lastBtn is not 0 then
                    click lastBtn
                    return "OK"
                end if
            end tell
        end tell
        return "FAIL"
    ' 2>/dev/null || echo "FAIL"
}

# =============================================================================
# Função: executa um ciclo completo (clicar botão → Start → esperar → Finish)
# =============================================================================
run_cycle() {
    local cycle_num=$1
    local btn_label="$2"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Ciclo $cycle_num de $COUNT — $btn_label"
    echo "═══════════════════════════════════════════════"
    echo ""

    # --- PASSO 1: Clica no botão da ação (Head Cleaning / Power Flushing / Nozzle Check) ---
    echo "   1) Localizando botão '$btn_label'..."

    local result=$(osascript -e "
        tell application \"System Events\"
            tell process \"Epson Printer Utility 4\"
                set win to window 1
                set allElems to entire contents of win
                
                -- Encontra o StaticText com o label
                set targetX to 0
                set targetY to 0
                repeat with elem in allElems
                    try
                        set r to role of elem
                        set v to \"\"
                        try
                            set v to value of elem
                        end try
                        if r is \"AXStaticText\" and v contains \"$btn_label\" then
                            set p to position of elem
                            set targetX to item 1 of p
                            set targetY to item 2 of p
                            exit repeat
                        end if
                    end try
                end repeat
                
                if targetX is 0 then
                    return \"ERRO: Botão '$btn_label' não encontrado\"
                end if
                
                -- Botão do ícone está ~68px acima do texto
                set btnY to targetY - 68
                set btnX to targetX + 17
                
                set found to false
                repeat with elem in allElems
                    try
                        set r to role of elem
                        if r is \"AXButton\" then
                            set p to position of elem
                            if (item 1 of p) ≥ btnX - 25 and (item 1 of p) ≤ btnX + 25 then
                                if (item 2 of p) ≥ btnY - 12 and (item 2 of p) ≤ btnY + 12 then
                                    click elem
                                    set found to true
                                    exit repeat
                                end if
                            end if
                        end if
                    end try
                end repeat
                
                if not found then
                    return \"ERRO: Ícone do '$btn_label' não encontrado\"
                end if
                
                return \"OK\"
            end tell
        end tell
    " 2>&1)

    if echo "$result" | grep -q "^ERRO"; then
        echo "   ❌ $result"
        return 1
    fi
    echo "   ✅ Botão clicado"

    # --- PASSO 2: Aguarda a tela carregar e clica em Start ---
    sleep 3
    echo "   2) Clicando Start..."

    result=$(osascript -e '
        tell application "System Events"
            tell process "Epson Printer Utility 4"
                set found to false
                set allElems to entire contents of window 1
                -- Procura o botão Start pelo texto
                repeat with elem in allElems
                    try
                        set r to role of elem
                        set v to ""
                        try
                            set v to value of elem
                        end try
                        if r is "AXButton" and (v is "Start" or v contains "Start") then
                            click elem
                            set found to true
                            exit repeat
                        end if
                    end try
                end repeat
                if not found then
                    -- Fallback: clica no primeiro botão grande no canto inferior
                    set lastBtn to 0
                    set allElems2 to entire contents of window 1
                    repeat with e2 in allElems2
                        try
                            set r2 to role of e2
                            if r2 is "AXButton" then
                                set p to position of e2
                                set s to size of e2
                                if (item 1 of s) > 40 and (item 2 of p) > 1400 then
                                    set lastBtn to e2
                                end if
                            end if
                        end try
                    end repeat
                    if lastBtn is not 0 then
                        click lastBtn
                        set found to true
                    end if
                end if
                if found then
                    return "OK"
                else
                    return "ERRO"
                end if
            end tell
        end tell
    ' 2>&1)

    if echo "$result" | grep -q "^ERRO"; then
        echo "   ❌ Botão Start não encontrado"
        return 1
    fi
    echo "   ✅ Start clicado — ciclo iniciado"

    # --- PASSO 3: Aguarda o fim do ciclo ---
    echo ""
    wait_for_cycle_end

    # --- PASSO 4: Clica em Finish para voltar à tela principal ---
    if [ "$cycle_num" -lt "$COUNT" ]; then
        echo ""
        echo "   3) Fechando tela de conclusão..."
        click_finish > /dev/null
        sleep 2
        echo "   ✅ Pronto para próximo ciclo"
    fi

    return 0
}

# =============================================================================
# LOOP PRINCIPAL
# =============================================================================
for i in $(seq 1 "$COUNT"); do
    run_cycle "$i" "$BTN_LABEL" || {
        echo "❌ Falha no ciclo $i. Abortando."
        exit 1
    }

    # Intervalo entre ciclos (se não for o último)
    if [ "$i" -lt "$COUNT" ]; then
        echo ""
        echo "   ⏱️  Aguardando ${CYCLE_WAIT}s entre ciclos..."
        sleep "$CYCLE_WAIT"
    fi
done

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ Todos os $COUNT ciclos de $BTN_LABEL concluídos!"
echo "═══════════════════════════════════════════════"
echo ""
echo "   O app Epson Printer Utility 4 está aberto."
echo "   Você pode fechá-lo manualmente se desejar."
