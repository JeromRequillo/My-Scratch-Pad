;@Ahk2Exe-SetFileVersion 4.1.0.0
;@Ahk2Exe-SetProductVersion 4.1.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "🎯 KeyTap pro v4.0"
TrayRecalcMenu()

; Global Variables
global current_num := "0000000"
global prefix := "AAPI"
global suffix := "S"
global mainGui := "" 
global hotkeyList := [] ; Hahawak sa mga dynamic hotkeys natin [{key: "!B", txt: "text", enabled: true}, ...]
global activeHotkeys := Map() ; Tracker para sa mga kasalukuyang aktibong hotkeys para madaling ma-turn off

; Basahin ang settings sa simula
LoadSettings()
RegisterCustomHotkeys()
return 

; --- FUNCTIONS ---

TrayRecalcMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Open Manager (Alt+F10)", (*) => LaunchGUI())
    Tray.Add() 
    Tray.Add("Exit Application", (*) => ExitApp())
}

LoadSettings() {
    global current_num, prefix, suffix, hotkeyList
    
    current_num := IniRead("settings.ini", "Sequence", "LastNumber", "00000")
    prefix := IniRead("settings.ini", "Settings", "Prefix", "AAPI")
    suffix := IniRead("settings.ini", "Settings", "Suffix", "S")

    ; I-load ang mga dynamic hotkeys mula sa INI file
    hotkeyList := []
    try {
        hkSections := IniRead("settings.ini", "Hotkeys")
        Loop Parse, hkSections, "`n", "`r" {
            if (A_LoopField == "")
                continue
            
            pos := InStr(A_LoopField, "=")
            if (pos > 0) {
                hkKey := SubStr(A_LoopField, 1, pos - 1)
                hkTxt := SubStr(A_LoopField, pos + 1)
                ; Check kung may enabled state na naka-save
                enabledVal := IniRead("settings.ini", "HotkeyState", hkKey, "1")
                hotkeyList.Push({key: hkKey, txt: hkTxt, enabled: (enabledVal == "1")})
            }
        }
    } catch {
        hotkeyList := [
            {key: "!S", txt: "SAMPLE TXT", enabled: true}
        ]
    }
}

RegisterCustomHotkeys() {
    global hotkeyList, activeHotkeys
    
    for hkKey, hkFunc in activeHotkeys {
        try Hotkey(hkKey, "Off")
    }
    activeHotkeys := Map()

    for hk in hotkeyList {
        if (hk.key != "" && hk.txt != "") {
            try {
                boundFunc := CreateHotkeyFunc(hk.txt)
                ; I-register, pero i-on lang kung enabled
                Hotkey(hk.key, boundFunc, hk.enabled ? "On" : "Off")
                activeHotkeys[hk.key] := boundFunc
            } catch as err {
                ; Laktawan kung may error sa format ng key
            }
        }
    }
}

CreateHotkeyFunc(txt) {
    return (*) => SendInput(txt)
}

GenerateInvoice(p := "", n := 0, s := "") {
    global prefix, current_num, suffix
    target_prefix := (p == "") ? prefix : p
    target_num := (n == 0) ? current_num : n
    target_suffix := (s == "") ? suffix : s
    
    formatted_num := Format("{:07}", target_num)
    return target_prefix . formatted_num . target_suffix
}

; --- STATIC HARDCODED HOTKEYS ---

!F9:: {
    Critical()
    invoice_string := GenerateInvoice()
    SendInput(invoice_string)
    
    SoundBeep(750, 50) 
    ToolTip("Sent: " . invoice_string)
    SetTimer(() => ToolTip(), -2000) 
    
    global current_num
    current_num := Number(current_num) + 1
    IniWrite(current_num, "settings.ini", "Sequence", "LastNumber")
}

!F10:: LaunchGUI()

!v:: {
    A_Clipboard := "" 
    Send("^c") 
    if !ClipWait(1) {
        ToolTip("Walang na-copy!")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    CleanAmount := StrReplace(A_Clipboard, ",", "")
    
    if IsNumber(CleanAmount) {
        NetAmount := Number(CleanAmount) / 1.12
        FormattedNet := Round(NetAmount, 2)
        
        A_Clipboard := FormattedNet
        Send("^v") 
        
        ToolTip("VAT Deducted: " . FormattedNet)
        SetTimer(() => ToolTip(), -2000)
    } else {
        ToolTip("Error: Hindi ito numero!")
        SetTimer(() => ToolTip(), -2000)
    }
}


; --- MAIN GUI LAUNCHER ---

LaunchGUI() {
    global mainGui, current_num, prefix, suffix, hotkeyList
    
    LoadSettings() 
    
    if (mainGui != "")
        mainGui.Destroy()
    
    mainGui := Gui("-MaximizeBox", "🎯 KeyTap Pro v4.0")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy()) 
    mainGui.SetFont("s10", "Segoe UI")
    
    tabMenu := mainGui.Add("Tab3", "x10 y10 w480 h400", ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "About"])
    
    ; --- TAB 1: INVOICE CONFIGURATION ---
    tabMenu.UseTab(1)
    
    mainGui.Add("Text", "x30 y55 w90 h20", "Prefix:")
    guiCtrl_Prefix := mainGui.Add("Edit", "x130 y52 w170 h25", prefix)
    guiCtrl_Prefix.OnEvent("Change", UpdatePreview)
    
    mainGui.Add("Text", "x30 y90 w90 h20", "Next Number:")
    guiCtrl_Num := mainGui.Add("Edit", "x130 y87 w110 h25 Number", current_num)
    guiCtrl_Num.OnEvent("Change", UpdatePreview)
    
    btnReset := mainGui.Add("Button", "x245 y86 w55 h26", "Reset")
    btnReset.OnEvent("Click", (*) => (guiCtrl_Num.Value := "0", UpdatePreview()))
    
    mainGui.Add("Text", "x30 y125 w90 h20", "Suffix:")
    guiCtrl_Suffix := mainGui.Add("Edit", "x130 y122 w170 h25", suffix)
    guiCtrl_Suffix.OnEvent("Change", UpdatePreview)
    
    mainGui.SetFont("bold s10", "Segoe UI")
    current_preview := GenerateInvoice()
    guiCtrl_PreviewText := mainGui.Add("Text", "x20 y160 w460 h20 Center +BackgroundTrans", "Preview: " . current_preview)
    
    mainGui.SetFont("Norm s10 cGray", "Segoe UI")
    
    invoiceTxt := "
    (
    💡PAANO GAMITIN ANG INVOICE GENERATOR:

    1. Itakda ang 'Prefix' (unahan), 'Next Number' (gitna), at 'Suffix' (hulihan).

    2. I-click ang [ Save All Changes ] para mai-save ang iyong configuration.

    3. Pindutin ang [ Alt + F9 ] kahit saan para awtomatikong i-type ang Invoice!

    💡 MAHALAGANG PAALALA:

    • Auto-Increment: Sa tuwing pipindutin mo ang Alt + F9, awtomatikong madadagdagan ng +1 ang Next Number at mase-save sa settings.ini.

    • Format Length: Ang system ay gumagamit ng fixed 7-digit padding para sa numero (e.g., '1' ay magiging '0000001') para mapanatili ang tamang haba.

    • Reset Button: I-click ang 'Reset' kung nais mong ibalik sa 0 ang panimulang numero.
    )"
    mainGui.Add("Edit", "x30 y190 w420 h200 +ReadOnly +Wrap +VScroll -WantReturn", invoiceTxt)
    
    mainGui.SetFont("Norm s10 cDefault", "Segoe UI")
    
    ; =========================================================
    ; --- TAB 2: CUSTOM TEXT HOTKEYS (UPDATED) ---
    ; =========================================================
    tabMenu.UseTab(2)

    ; ListView: 3 columns - Status, Shortcut Key, Text Output
    LV := mainGui.Add("ListView", "x20 y50 w440 h155 +Grid -Multi", ["Status", "Shortcut Key", "Text / Name to Output"])
    LV.ModifyCol(1, 55)   ; Status column
    LV.ModifyCol(2, 100)  ; Key column
    LV.ModifyCol(3, 262)  ; Text column

    ; Populate ListView with enabled/disabled status
    for hk in hotkeyList {
        statusTxt := hk.enabled ? "✅ ON" : "⛔ OFF"
        LV.Add(, statusTxt, hk.key, hk.txt)
    }

    ; --- Input Row Label ---
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y215 w80 h18", "Modifier:")
    mainGui.Add("Text", "x108 y215 w40 h18", "Key:")
    mainGui.Add("Text", "x160 y215 w200 h18", "Text to Output:")

    ; --- Modifier Dropdown ---
    ; Display labels map to AHK symbols: Alt=!, Ctrl=^, Shift=+, Ctrl+Alt=^!, Alt+Shift=!+, Ctrl+Shift=^+
    modifierChoices := ["Alt (!)", "Ctrl (^)", "Shift (+)", "Ctrl+Alt (^!)", "Alt+Shift (!+)", "Ctrl+Shift (^+)"]
    ddModifier := mainGui.Add("DropDownList", "x20 y233 w82 h120", modifierChoices)
    ddModifier.Value := 1 ; Default: Alt

    ; --- Key Dropdown (A-Z + F1-F12 + common keys) ---
    keyChoices := []
    Loop 26
        keyChoices.Push(Chr(64 + A_Index)) ; A to Z
    Loop 12
        keyChoices.Push("F" . A_Index)     ; F1 to F12
    for extraKey in ["1","2","3","4","5","6","7","8","9","0","Space","Tab","Enter","Delete","Home","End","PgUp","PgDn","Up","Down","Left","Right"]
        keyChoices.Push(extraKey)

    ddKey := mainGui.Add("DropDownList", "x108 y233 w46 h300", keyChoices)
    ddKey.Value := 1 ; Default: A

    ; --- Text Output Edit ---
    editTxt := mainGui.Add("Edit", "x160 y233 w300 h25")

    ; Hidden field to store the raw AHK key of selected row (for update matching)
    selectedRawKey := ""

    ; --- Buttons ---
    btnAdd := mainGui.Add("Button", "x20 y268 w100 h26", "➕ Add / Update")
    btnDel := mainGui.Add("Button", "x128 y268 w100 h26", "❌ Delete Line")
    btnToggle := mainGui.Add("Button", "x236 y268 w110 h26", "🔁 Toggle ON/OFF")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    LV.OnEvent("Click", SelectHotkey)

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x20 y302 w440 h30", "Tip: Piliin ang Modifier at Key sa dropdowns, tapos isulat ang text na ire-type.")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; =========================================================
    ; --- TAB 3: VAT CALCULATOR INFO ---
    ; =========================================================
    tabMenu.UseTab(3)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x30 y60 w400 h25 c0x0066CC", "Automated VAT Deductor Tool")
    mainGui.SetFont("s10 Norm", "Segoe UI")
    
    vatTxt := "
    (
    💡PAANO GAMITIN:

    1. I-highlight/I-select ang presyo na may VAT (Kahit may kuwit o comma).

    2. Pindutin ang [ Alt + V ].

    3. Awtomatikong mada-deduct ang 12% VAT at mapapalitan ang text!

    💡 MAHALAGANG PAALALA SA VAT TOOL:

    • Numero at kuwit lang ang i-highlight: Huwag isama ang currency symbols tulad ng "₱", "PHP", o "$", pati na rin ang mga letra o spacing (e.g., "₱ 1,500" -> i-highlight lang ang "1,500"). Mag-e-error ang calculator kapag may kasamang letra.

    • Rounding off: Awtomatikong sine-set ng tool ang resulta sa dalawang decimal places (e.g., 133.93).

    • Paano mag-Undo: Kung nagkamali ka ng na-highlight o hindi mo sinasadyang mapalitan ang text, pindutin lang ang [ Ctrl + Z ] sa iyong keyboard para bumalik sa dati ang text.

    • Clipboard backup: Ang huling net amount na kinalkula ay mananatiling naka-copy sa iyong clipboard (ready to paste).
    )"
    
    mainGui.Add("Edit", "x30 y95 w420 h290 +ReadOnly +Wrap +VScroll -WantReturn", vatTxt)
    
    ; --- TAB 4: ABOUT & CREDITS ---
    tabMenu.UseTab(4)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x25 y50 w400 h25 c0x0066CC", "🎯 KeyTap Pro v4.1")
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x25 y75 w400 h18", "Version: 4.1.0 (Dynamic ListView)")
    mainGui.Add("Text", "x25 y95 w400 h18", "Developer: Jerom Requillo")
    
    mainGui.SetFont("italic s9", "Segoe UI")
    mainGui.Add("Link", "x25 y120 w400 h20", 'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x25 y140 w400 h20", 'Repository: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo/🎯 KeyTap Pro v4.0</a>')
    
    mainGui.SetFont("s10 Norm", "Segoe UI")
    
    aboutTxt := "
    (
    Default Global Hotkeys:
    [Alt + F9] -> Generate & Type Auto-Invoice Number
    [Alt + F10] -> Open Management Interface Control Panel
    [Alt + V] -> Deduct 12% VAT from Selected Text

    🛠️ Troubleshooting & Diagnostic Guide:

    1. Hotkeys Are Unresponsive

       - Verify that the application is running by checking for the 'H' icon in the Windows System Tray (lower-right corner of the taskbar).
       - If the application is active but non-responsive, right-click the system tray icon and select 'Reload Script'.

    2. Configuration Settings Fail to Save

       - Ensure that the 'settings.ini' configuration file exists within the directory and is not marked as 'Read-Only'.

    3. Application Crashes or Throws Fatal Errors

       - Review your custom macro entries. Ensure that the shortcut key string is properly formatted and that no duplicate hotkeys are assigned to conflicting actions.

    📂 Deployment Information:

    This application is fully portable and operates independently of the Windows Registry. It can be executed from a shared network drive or a USB storage device, or placed in the Windows Startup directory for automatic initialization. All application states are recorded locally in 'settings.ini'.
    )"
    
    mainGui.Add("Edit", "x25 y170 w420 h220 +ReadOnly +Wrap +VScroll -WantReturn", aboutTxt)
    
    tabMenu.UseTab()
    
    ; --- BOTTOM BUTTONS ---
    mainGui.SetFont("Norm s10", "Segoe UI")
    btnSave := mainGui.Add("Button", "x130 y425 w110 h32 Default", "Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    
    btnCancel := mainGui.Add("Button", "x260 y425 w110 h32", "Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())
    
    mainGui.Show("w500 h470")
    
    ; =========================================================
    ; --- GUI INTERNAL FUNCTIONS ---
    ; =========================================================

    UpdatePreview(*) {
        temp_preview := GenerateInvoice(guiCtrl_Prefix.Value, guiCtrl_Num.Value, guiCtrl_Suffix.Value)
        guiCtrl_PreviewText.Value := "Preview: " . temp_preview
    }

    ; Helper: Convert dropdown selections to AHK hotkey string
    BuildHotkeyString() {
        modMap := Map(
            "Alt (!)",        "!",
            "Ctrl (^)",       "^",
            "Shift (+)",      "+",
            "Ctrl+Alt (^!)",  "^!",
            "Alt+Shift (!+)", "!+",
            "Ctrl+Shift (^+)","^+"
        )
        modSym := modMap[ddModifier.Text]
        rawKey := ddKey.Text
        return modSym . rawKey
    }

    ; Helper: Parse existing AHK key string back into dropdown indexes
    ParseHotkeyToDropdowns(hkStr) {
        ; Map modifier symbols to display labels
        modOptions := [
            {sym: "^!", label: "Ctrl+Alt (^!)"},
            {sym: "!+", label: "Alt+Shift (!+)"},
            {sym: "^+", label: "Ctrl+Shift (^+)"},
            {sym: "!",  label: "Alt (!)"},
            {sym: "^",  label: "Ctrl (^)"},
            {sym: "+",  label: "Shift (+)"}
        ]
        foundMod := ""
        foundKey := ""
        for opt in modOptions {
            if (SubStr(hkStr, 1, StrLen(opt.sym)) == opt.sym) {
                foundMod := opt.label
                foundKey := SubStr(hkStr, StrLen(opt.sym) + 1)
                break
            }
        }
        ; Set modifier dropdown
        for i, choice in modifierChoices {
            if (choice == foundMod) {
                ddModifier.Value := i
                break
            }
        }
        ; Set key dropdown
        for i, choice in keyChoices {
            if (choice == foundKey) {
                ddKey.Value := i
                break
            }
        }
    }

    ; On row click: populate dropdowns and text field
    SelectHotkey(CtrlObj, RowNumber) {
        if (RowNumber == 0)
            return
        rawKey := CtrlObj.GetText(RowNumber, 2)  ; Column 2 = Shortcut Key
        ParseHotkeyToDropdowns(rawKey)
        editTxt.Value := CtrlObj.GetText(RowNumber, 3)  ; Column 3 = Text
    }

    AddUpdateHotkey(*) {
        if (editTxt.Value == "") {
            MsgBox("Paki-sulat muna ang Text to Output!", "Babala", 48)
            return
        }

        newKey := BuildHotkeyString()

        rowToUpdate := 0
        Loop LV.GetCount() {
            if (LV.GetText(A_Index, 2) = newKey) {
                rowToUpdate := A_Index
                break
            }
        }

        if (rowToUpdate > 0) {
            ; Keep existing status when updating
            existingStatus := LV.GetText(rowToUpdate, 1)
            LV.Modify(rowToUpdate, , existingStatus, newKey, editTxt.Value)
        } else {
            LV.Add(, "✅ ON", newKey, editTxt.Value)
        }

        editTxt.Value := ""
        ddModifier.Value := 1
        ddKey.Value := 1
    }

    DeleteHotkey(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng hotkey sa listahan na gustong burahin.", "Babala", 48)
            return
        }
        LV.Delete(selectedRow)
        editTxt.Value := ""
        ddModifier.Value := 1
        ddKey.Value := 1
    }

    ; Toggle ON/OFF the selected hotkey row
    ToggleHotkey(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng hotkey sa listahan na gustong i-toggle.", "Babala", 48)
            return
        }
        currentStatus := LV.GetText(selectedRow, 1)
        rawKey := LV.GetText(selectedRow, 2)
        hkTxt := LV.GetText(selectedRow, 3)

        if (currentStatus == "✅ ON") {
            ; Turn OFF
            LV.Modify(selectedRow, , "⛔ OFF", rawKey, hkTxt)
            ; Immediately disable the hotkey in memory
            try Hotkey(rawKey, "Off")
        } else {
            ; Turn ON
            LV.Modify(selectedRow, , "✅ ON", rawKey, hkTxt)
            ; Immediately enable the hotkey in memory
            try {
                boundFunc := CreateHotkeyFunc(hkTxt)
                Hotkey(rawKey, boundFunc, "On")
                global activeHotkeys
                activeHotkeys[rawKey] := boundFunc
            }
        }
    }

    SaveSettings(*) {
        global prefix, current_num, suffix, hotkeyList

        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' cannot be empty!", "Error", 48)
            return
        }
        
        prefix := guiCtrl_Prefix.Value
        current_num := Format("{:05}", Number(guiCtrl_Num.Value)) 
        suffix := guiCtrl_Suffix.Value
        
        IniWrite(prefix, "settings.ini", "Settings", "Prefix")
        IniWrite(Number(guiCtrl_Num.Value), "settings.ini", "Sequence", "LastNumber")
        IniWrite(suffix, "settings.ini", "Settings", "Suffix")
        
        try IniDelete("settings.ini", "Hotkeys")
        try IniDelete("settings.ini", "HotkeyState")
        
        hotkeyList := [] 
        Loop LV.GetCount() {
            hKey   := LV.GetText(A_Index, 2)  ; Column 2 = key
            hTxt   := LV.GetText(A_Index, 3)  ; Column 3 = text
            hState := LV.GetText(A_Index, 1)  ; Column 1 = status
            isEnabled := (hState == "✅ ON")

            IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
            IniWrite(isEnabled ? "1" : "0", "settings.ini", "HotkeyState", hKey)
            hotkeyList.Push({key: hKey, txt: hTxt, enabled: isEnabled})
        }
        
        RegisterCustomHotkeys()
        
        MsgBox("All settings and dynamic hotkeys updated successfully!", "Success", "64 T1.5")
        mainGui.Destroy()
    }
}
