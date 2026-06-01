;@Ahk2Exe-SetFileVersion 4.1.0.0
;@Ahk2Exe-SetProductVersion 4.1.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "🎯 KeyTap pro v4.1"
TrayRecalcMenu()

; Global Variables
global current_num := "0000000"
global prefix := "AAPI"
global suffix := "S"
global mainGui := ""
global hotkeyList := [] ; [{key: "!B", txt: "text", enabled: true}, ...]
global activeHotkeys := Map()

; Reserved/system hotkeys na bawal i-conflict
global reservedHotkeys := ["!F9", "!F10", "!v", "!V"]

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
    target_num    := (n == 0) ? current_num : n
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
        NetAmount   := Number(CleanAmount) / 1.12
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

    mainGui := Gui("-MaximizeBox", "🎯 KeyTap Pro v4.1")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())
    mainGui.SetFont("s10", "Segoe UI")

    tabMenu := mainGui.Add("Tab3", "x10 y10 w480 h400", ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "About"])

    ; =========================================================
    ; --- TAB 1: INVOICE CONFIGURATION (UNCHANGED) ---
    ; =========================================================
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
    ; --- TAB 2: CUSTOM TEXT HOTKEYS (UPGRADED) ---
    ; =========================================================
    tabMenu.UseTab(2)

    ; --- Search / Filter Bar ---
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y50 w50 h20", "🔍 Filter:")
    editSearch := mainGui.Add("Edit", "x70 y48 w280 h22")
    btnClearSearch := mainGui.Add("Button", "x356 y47 w50 h23", "Clear")
    mainGui.SetFont("s9 cGray", "Segoe UI")
    mainGui.Add("Text", "x410 y51 w70 h18", "live search")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; --- ListView: Status | Shortcut Key | Text Output ---
    ; +LV0x10 enables full-row selection color; we handle row colors via LV_Colors workaround
    LV := mainGui.Add("ListView", "x20 y74 w440 h130 +Grid -Multi", ["Status", "Shortcut Key", "Text / Name to Output"])
    LV.ModifyCol(1, 55)
    LV.ModifyCol(2, 100)
    LV.ModifyCol(3, 262)

    ; --- Populate ListView ---
    RefreshListView(filterTxt := "") {
        LV.Delete()
        for hk in hotkeyList {
            ; Apply search filter (checks key and text)
            if (filterTxt != "" && !InStr(hk.key, filterTxt) && !InStr(hk.txt, filterTxt))
                continue
            statusTxt := hk.enabled ? "✅ ON" : "⛔ OFF"
            LV.Add(, statusTxt, hk.key, hk.txt)
        }
    }
    RefreshListView()

    ; Live search on keypress
    editSearch.OnEvent("Change", (*) => RefreshListView(editSearch.Value))
    btnClearSearch.OnEvent("Click", (*) => (editSearch.Value := "", RefreshListView()))

    ; --- Input Row Labels ---
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y213 w80 h18", "Modifier:")
    mainGui.Add("Text", "x108 y213 w40 h18", "Key:")
    mainGui.Add("Text", "x160 y213 w200 h18", "Text to Output (multi-line ok):")

    ; --- Modifier Dropdown ---
    modifierChoices := ["Alt (!)", "Ctrl (^)", "Shift (+)", "Ctrl+Alt (^!)", "Alt+Shift (!+)", "Ctrl+Shift (^+)"]
    ddModifier := mainGui.Add("DropDownList", "x20 y231 w82 h120", modifierChoices)
    ddModifier.Value := 1

    ; --- Key Dropdown ---
    keyChoices := []
    Loop 26
        keyChoices.Push(Chr(64 + A_Index))
    Loop 12
        keyChoices.Push("F" . A_Index)
    for extraKey in ["1","2","3","4","5","6","7","8","9","0","Space","Tab","Enter","Delete","Home","End","PgUp","PgDn","Up","Down","Left","Right"]
        keyChoices.Push(extraKey)

    ddKey := mainGui.Add("DropDownList", "x108 y231 w46 h300", keyChoices)
    ddKey.Value := 1

    ; --- Multi-line Text Output ---
    ; +WantReturn allows Enter key inside the edit box for multi-line
    editTxt := mainGui.Add("Edit", "x160 y231 w300 h50 +Multi +WantReturn +VScroll")

    ; --- Buttons Row 1: Add/Delete/Toggle ---
    btnAdd    := mainGui.Add("Button", "x20 y290 w100 h26", "➕ Add / Update")
    btnDel    := mainGui.Add("Button", "x128 y290 w100 h26", "❌ Delete Line")
    btnToggle := mainGui.Add("Button", "x236 y290 w110 h26", "🔁 Toggle ON/OFF")

    ; --- Buttons Row 2: Move Up / Move Down (Drag-to-Reorder alternative) ---
    btnMoveUp   := mainGui.Add("Button", "x354 y290 w50 h26", "▲ Up")
    btnMoveDown := mainGui.Add("Button", "x408 y290 w52 h26", "▼ Down")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    btnMoveUp.OnEvent("Click", MoveRowUp)
    btnMoveDown.OnEvent("Click", MoveRowDown)
    LV.OnEvent("Click", SelectHotkey)

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x20 y322 w440 h28", "Tip: Piliin ang Modifier at Key sa dropdowns. Pwedeng multi-line ang Text (Enter = bagong linya). ▲▼ = i-reorder.")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; =========================================================
    ; --- TAB 3: VAT CALCULATOR INFO (UNCHANGED) ---
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

    ; =========================================================
    ; --- TAB 4: ABOUT & CREDITS (UNCHANGED) ---
    ; =========================================================
    tabMenu.UseTab(4)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x25 y50 w400 h25 c0x0066CC", "🎯 KeyTap Pro v4.1")
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x25 y75 w400 h18", "Version: 4.0.0 (Dynamic ListView)")
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

    ; --- BOTTOM BUTTONS (UNCHANGED) ---
    mainGui.SetFont("Norm s10", "Segoe UI")
    btnSave   := mainGui.Add("Button", "x130 y425 w110 h32 Default", "Save All Changes")
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

    BuildHotkeyString() {
        modMap := Map(
            "Alt (!)",         "!",
            "Ctrl (^)",        "^",
            "Shift (+)",       "+",
            "Ctrl+Alt (^!)",   "^!",
            "Alt+Shift (!+)",  "!+",
            "Ctrl+Shift (^+)", "^+"
        )
        modSym := modMap[ddModifier.Text]
        rawKey := ddKey.Text
        return modSym . rawKey
    }

    ParseHotkeyToDropdowns(hkStr) {
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
        for i, choice in modifierChoices {
            if (choice == foundMod) {
                ddModifier.Value := i
                break
            }
        }
        for i, choice in keyChoices {
            if (choice == foundKey) {
                ddKey.Value := i
                break
            }
        }
    }

    SelectHotkey(CtrlObj, RowNumber) {
        if (RowNumber == 0)
            return
        rawKey := CtrlObj.GetText(RowNumber, 2)
        ParseHotkeyToDropdowns(rawKey)
        ; Multi-line: unescape \n back to actual newlines for display
        storedTxt := CtrlObj.GetText(RowNumber, 3)
        editTxt.Value := StrReplace(storedTxt, "\n", "`n")
    }

    ; --- Hotkey Conflict Checker ---
    ; Returns a conflict message string, or "" if clear
    CheckConflict(newKey, excludeRow := 0) {
        global reservedHotkeys
        ; Check against reserved system hotkeys
        for rk in reservedHotkeys {
            if (newKey = rk)
                return "'" . newKey . "' ay reserved ng KeyTap Pro system hotkey!"
        }
        ; Check against existing rows in ListView (skip excludeRow = row being updated)
        Loop LV.GetCount() {
            if (A_Index == excludeRow)
                continue
            if (LV.GetText(A_Index, 2) = newKey)
                return "'" . newKey . "' ay duplicate! Ginagamit na ng row #" . A_Index . "."
        }
        return ""
    }

    AddUpdateHotkey(*) {
        if (editTxt.Value == "") {
            MsgBox("Paki-sulat muna ang Text to Output!", "Babala", 48)
            return
        }

        newKey := BuildHotkeyString()

        ; Check kung may existing row na may same key (for update)
        rowToUpdate := 0
        Loop LV.GetCount() {
            if (LV.GetText(A_Index, 2) = newKey) {
                rowToUpdate := A_Index
                break
            }
        }

        ; Conflict check (exclude current row if updating)
        conflictMsg := CheckConflict(newKey, rowToUpdate)
        if (conflictMsg != "") {
            MsgBox("⚠️ Hotkey Conflict Detected!`n`n" . conflictMsg . "`n`nPiliin ang ibang key combination.", "Conflict!", 48)
            return
        }

        ; Multi-line: store newlines as \n literal so it fits one ListView cell
        storedTxt := StrReplace(editTxt.Value, "`n", "\n")
        storedTxt := StrReplace(storedTxt, "`r", "")

        if (rowToUpdate > 0) {
            existingStatus := LV.GetText(rowToUpdate, 1)
            LV.Modify(rowToUpdate, , existingStatus, newKey, storedTxt)
        } else {
            LV.Add(, "✅ ON", newKey, storedTxt)
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

    ToggleHotkey(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng hotkey sa listahan na gustong i-toggle.", "Babala", 48)
            return
        }
        currentStatus := LV.GetText(selectedRow, 1)
        rawKey := LV.GetText(selectedRow, 2)
        hkTxt  := LV.GetText(selectedRow, 3)

        if (currentStatus == "✅ ON") {
            LV.Modify(selectedRow, , "⛔ OFF", rawKey, hkTxt)
            try Hotkey(rawKey, "Off")
        } else {
            LV.Modify(selectedRow, , "✅ ON", rawKey, hkTxt)
            try {
                ; Unescape \n back to real newlines for SendInput
                realTxt := StrReplace(hkTxt, "\n", "`n")
                boundFunc := CreateHotkeyFunc(realTxt)
                Hotkey(rawKey, boundFunc, "On")
                global activeHotkeys
                activeHotkeys[rawKey] := boundFunc
            }
        }
    }

    ; --- Move Row Up ---
    MoveRowUp(*) {
        selectedRow := LV.GetNext()
        if (selectedRow <= 1) {
            if (selectedRow == 0)
                MsgBox("Pumili muna ng row.", "Babala", 48)
            return
        }
        ; Swap in hotkeyList (use unfiltered index by matching key)
        SwapListViewRows(selectedRow, selectedRow - 1)
    }

    ; --- Move Row Down ---
    MoveRowDown(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng row.", "Babala", 48)
            return
        }
        if (selectedRow >= LV.GetCount())
            return
        SwapListViewRows(selectedRow, selectedRow + 1)
    }

    ; Helper: swap two rows in ListView and re-select the moved row
    SwapListViewRows(rowA, rowB) {
        ; Read both rows
        statusA := LV.GetText(rowA, 1)
        keyA    := LV.GetText(rowA, 2)
        txtA    := LV.GetText(rowA, 3)
        isOnA   := (statusA == "✅ ON")

        statusB := LV.GetText(rowB, 1)
        keyB    := LV.GetText(rowB, 2)
        txtB    := LV.GetText(rowB, 3)
        isOnB   := (statusB == "✅ ON")

        ; Write B's data into rowA
        LV.Modify(rowA, , statusB, keyB, txtB)
        ; Write A's data into rowB
        LV.Modify(rowB, , statusA, keyA, txtA)

        ; Re-select rowB (where the moved item landed)
        LV.Modify(rowA, "-Select")
        LV.Modify(rowB, "+Select +Focus")
    }

    SaveSettings(*) {
        global prefix, current_num, suffix, hotkeyList

        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' cannot be empty!", "Error", 48)
            return
        }

        prefix      := guiCtrl_Prefix.Value
        current_num := Format("{:05}", Number(guiCtrl_Num.Value))
        suffix      := guiCtrl_Suffix.Value

        IniWrite(prefix, "settings.ini", "Settings", "Prefix")
        IniWrite(Number(guiCtrl_Num.Value), "settings.ini", "Sequence", "LastNumber")
        IniWrite(suffix, "settings.ini", "Settings", "Suffix")

        try IniDelete("settings.ini", "Hotkeys")
        try IniDelete("settings.ini", "HotkeyState")

        hotkeyList := []
        Loop LV.GetCount() {
            hKey   := LV.GetText(A_Index, 2)
            hTxt   := LV.GetText(A_Index, 3)
            hState := LV.GetText(A_Index, 1)
            isEnabled := (hState == "✅ ON")

            ; Unescape \n to real newlines for SendInput when registering
            realTxt := StrReplace(hTxt, "\n", "`n")

            IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
            IniWrite(isEnabled ? "1" : "0", "settings.ini", "HotkeyState", hKey)
            hotkeyList.Push({key: hKey, txt: realTxt, enabled: isEnabled})
        }

        RegisterCustomHotkeys()

        MsgBox("All settings and dynamic hotkeys updated successfully!", "Success", "64 T1.5")
        mainGui.Destroy()
    }
}
