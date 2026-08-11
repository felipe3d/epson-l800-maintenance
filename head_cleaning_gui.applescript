#!/usr/bin/osascript
(*
Epson L800 — Head Cleaning via Epson Printer Utility 4
Uso: osascript head_cleaning_gui.applescript [clean|flush|nozzle] [vezes]

Coordenadas:
  Head Cleaning  → (1469, 1294)  Nozzle Check → (1351, 1294)
  Power Flushing → (1233, 1415)  Start/Finish → canto inf. direito
*)

on run argv
	set act to "Head Cleaning"
	set reps to 1
	
	if (count of argv) ≥ 1 then
		if item 1 of argv = "flush" then
			set act to "Power Ink Flushing"
		else if item 1 of argv = "nozzle" then
			set act to "Nozzle Check"
		else if item 1 of argv = "clean" then
			set act to "Head Cleaning"
		end if
	end if
	
	if (count of argv) ≥ 2 then
		try
			set reps to (item 2 of argv) as integer
			if reps > 5 then set reps to 5
			if reps < 1 then set reps to 1
		end try
	end if
	
	set wait_sec to 180
	if act contains "Flushing" then set wait_sec to 300
	if act contains "Nozzle" then set wait_sec to 30
	
	log "Epson L800 — " & act & " × " & reps
	
	try
		tell application "Epson Printer Utility 4" to activate
	on error
		do shell script "open '/Library/Printers/EPSON/InkjetPrinter2/Utility/UT4/Epson Printer Utility 4.app'"
		delay 3
	end try
	
	repeat with cycle from 1 to reps
		log "Ciclo " & cycle & " de " & reps
		my dismiss_dialog()
		
		set lbl to act
		tell application "System Events"
			tell process "Epson Printer Utility 4"
				set allElems to entire contents of window 1
				set btnX to 0
				set btnY to 0
				repeat with elem in allElems
					try
						set r to role of elem
						set v to ""
						try
							set v to value of elem
						end try
						if r is "AXStaticText" and v contains lbl then
							set p to position of elem
							set btnX to (item 1 of p) + 17
							set btnY to (item 2 of p) - 68
							exit repeat
						end if
					end try
				end repeat
				if btnX = 0 then
					log "ERRO: botão " & lbl & " não encontrado"
					return
				end if
				repeat with elem in allElems
					try
						if role of elem is "AXButton" then
							set p to position of elem
							if (item 1 of p) ≥ btnX - 25 and (item 1 of p) ≤ btnX + 25 then
								if (item 2 of p) ≥ btnY - 12 and (item 2 of p) ≤ btnY + 12 then
									click elem
									exit repeat
								end if
							end if
						end if
					end try
				end repeat
			end tell
		end tell
		
		delay 3
		my click_corner_button()
		log act & " iniciado — aguardando " & wait_sec & "s"
		delay wait_sec
		my dismiss_dialog()
		delay 2
	end repeat
	
	log "Todos os " & reps & " ciclos concluídos!"
end run

on dismiss_dialog()
	tell application "System Events"
		tell process "Epson Printer Utility 4"
			try
				set allElems to entire contents of window 1
				repeat with elem in allElems
					try
						set v to value of elem
						if v contains "cleaning cycle" or v contains "finished" or v contains "Print Nozzle" then
							my click_corner_button()
							return
						end if
					end try
				end repeat
			end try
		end tell
	end tell
end dismiss_dialog

on click_corner_button()
	tell application "System Events"
		tell process "Epson Printer Utility 4"
			set allElems to every UI element of window 1
			repeat with elem in allElems
				try
					if role of elem is "AXButton" then
						set s to size of elem
						set p to position of elem
						if (item 1 of s) > 40 and (item 2 of p) > 1400 then
							click elem
							return
						end if
					end if
				end try
			end repeat
		end tell
	end tell
end click_corner_button
