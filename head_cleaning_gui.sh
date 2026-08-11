#!/usr/bin/env bash
# =============================================================================
# Epson L800 — Head Cleaning via Epson Printer Utility 4 (macOS GUI automation)
# =============================================================================
# Controla o Epson Printer Utility 4 via AppleScript para executar:
#   - Head Cleaning (limpeza normal)
#   - Power Ink Flushing (limpeza profunda)
#   - Nozzle Check (teste de bicos)
#
# Uso: ./head_cleaning_gui.sh [clean|flush|nozzle]
#   clean   — Head Cleaning (padrão)
#   flush   — Power Ink Flushing
#   nozzle  — Nozzle Check
# =============================================================================

set -euo pipefail

APP_PATH="/Library/Printers/EPSON/InkjetPrinter2/Utility/UT4/Epson Printer Utility 4.app"
ACTION="${1:-clean}"

# Mapeia ação para o label do botão (texto ao lado do ícone)
case "$ACTION" in
  clean)
    BTN_LABEL="Head Cleaning"
    ;;
  flush)
    BTN_LABEL="Power Ink Flushing"
    ;;
  nozzle)
    BTN_LABEL="Nozzle Check"
    ;;
  *)
    echo "Uso: $0 [clean|flush|nozzle]"
    exit 1
    ;;
esac

echo "🔧 Epson L800 — $BTN_LABEL"

# Abre o app se não estiver rodando
if ! pgrep -x "Epson Printer Utility 4" >/dev/null 2>&1; then
    echo "   Abrindo Epson Printer Utility 4..."
    open "$APP_PATH"
    sleep 3
fi

# AppleScript para clicar no botão da ação desejada
# A lógica: encontra o StaticText com o label, pega a posição X,Y dele,
# e clica no botão que está imediatamente acima (mesmo X, Y - 68px ~ altura do ícone)
OSA_SCRIPT=$(cat <<EOF
tell application "System Events"
    tell process "Epson Printer Utility 4"
        set win to window 1
        set allElems to entire contents of win
        
        -- Encontra o StaticText com o label desejado
        set targetX to 0
        set targetY to 0
        repeat with elem in allElems
            try
                set r to role of elem
                set v to ""
                try
                    set v to value of elem
                end try
                if r is "AXStaticText" and v contains "$BTN_LABEL" then
                    set p to position of elem
                    set targetX to item 1 of p
                    set targetY to item 2 of p
                    exit repeat
                end if
            end try
        end repeat
        
        if targetX is 0 then
            return "ERRO: Botão '$BTN_LABEL' não encontrado"
        end if
        
        -- O botão do ícone está ~68px acima do texto
        set btnY to targetY - 68
        set btnX to targetX + 17  -- centraliza no ícone (34px offset)
        
        -- Procura e clica no botão naquela posição
        set found to false
        repeat with elem in allElems
            try
                set r to role of elem
                if r is "AXButton" then
                    set p to position of elem
                    if (item 1 of p) ≥ btnX - 20 and (item 1 of p) ≤ btnX + 20 then
                        if (item 2 of p) ≥ btnY - 10 and (item 2 of p) ≤ btnY + 10 then
                            click elem
                            set found to true
                            exit repeat
                        end if
                    end if
                end if
            end try
        end repeat
        
        if not found then
            return "ERRO: Botão na posição ($btnX, $btnY) não encontrado"
        end if
        
        -- Aguarda a tela da ação carregar
        delay 2
        
        -- Clica no botão Start/OK (primeiro botão no canto inferior direito)
        set startFound to false
        set allElems2 to entire contents of win
        repeat with elem in allElems2
            try
                set r to role of elem
                if r is "AXButton" then
                    set p to position of elem
                    set s to size of elem
                    -- Botão no canto inferior, tamanho ~68-80px largura
                    if (item 1 of s) > 50 and (item 2 of p) > 1400 then
                        click elem
                        set startFound to true
                        exit repeat
                    end if
                end if
            end try
        end repeat
        
        if not startFound then
            return "ERRO: Botão Start não encontrado"
        end if
        
        return "OK: $BTN_LABEL iniciado"
    end tell
end tell
EOF
)

RESULT=$(osascript -e "$OSA_SCRIPT" 2>&1)
echo "   $RESULT"

if echo "$RESULT" | grep -q "^ERRO"; then
    exit 1
fi

echo ""
echo "✅ $BTN_LABEL iniciado com sucesso!"
echo "   Aguarde ~2-3 minutos para o ciclo terminar."
echo "   O app Epson Printer Utility 4 mostrará quando finalizar."
