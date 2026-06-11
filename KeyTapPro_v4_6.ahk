;@Ahk2Exe-SetFileVersion 4.6.0.0
;@Ahk2Exe-SetProductVersion 4.6.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "🎯 KeyTap Pro v4.6"
TrayRecalcMenu()

; Global Variables

global current_num    := "0"
global prefix         := "AAPI"
global suffix         := "S"
global digit_length   := 7
global vat_rate       := 12.0
global discount_rate  := 0.0
global vat_mode       := "Deduct"   ; "Deduct" or "Add"
global active_profile := "Default"
global mainGui        := ""
global hotkeyList     := []
global activeHotkeys  := Map()

; System hotkey strings (global, loaded from ini)
global sysHK_Invoice  := "!F9"
global sysHK_Vat      := "!v"
global sysHK_Discount := "!d"
global sysHK_Manager  := "!F10"

; Folder Launcher globals
global folderLauncherList := []   ; array of {path, label, hotkey, enabled}
global activeFolderHotkeys := Map()

; Active function refs for system hotkeys (so we can re-register)
global sysFunc_Invoice  := ""
global sysFunc_Vat      := ""
global sysFunc_Discount := ""
global sysFunc_Manager  := ""


; STARTUP

LoadSettings()
LaunchGUI()  
RegisterSystemHotkeys()
RegisterCustomHotkeys()
RegisterFolderHotkeys()
; Register tray icon click handler at startup
OnMessage(0x404, OnTrayIcon)
return


; TRAY

TrayRecalcMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Open Manager", (*) => LaunchGUI())
    Tray.Add()
    Tray.Add("Exit Application", (*) => ExitApp())
    Tray.Default := "Open Manager"
}

; Tray icon message handler
OnTrayIcon(wParam, lParam, msg, hwnd) {
    if (lParam = 0x203) {  ; WM_LBUTTONDBLCLK
        LaunchGUI()
        return 0
    }
}


; LOAD SETTINGS

LoadSettings() {
    global current_num, prefix, suffix, digit_length, vat_rate, discount_rate, vat_mode
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Discount, sysHK_Manager
    global folderLauncherList

    active_profile := IniRead("settings.ini", "Settings", "ActiveProfile", "Default")

    ; --- System hotkeys (global) ---
    sysHK_Invoice  := IniRead("settings.ini", "SystemHotkeys", "Invoice",  "!F9")
    sysHK_Vat      := IniRead("settings.ini", "SystemHotkeys", "Vat",      "!v")
    sysHK_Discount := IniRead("settings.ini", "SystemHotkeys", "Discount", "!d")
    sysHK_Manager  := IniRead("settings.ini", "SystemHotkeys", "Manager",  "!F10")

    ; --- Active profile settings ---
    profileSection := "Profile_" . active_profile
    current_num    := IniRead("settings.ini", profileSection, "LastNumber",    "0")
    prefix         := IniRead("settings.ini", profileSection, "Prefix",        "AAPI")
    suffix         := IniRead("settings.ini", profileSection, "Suffix",        "S")
    digit_length   := Integer(IniRead("settings.ini", profileSection, "DigitLength",   "7"))
    vat_rate       := Float(IniRead("settings.ini", profileSection, "VatRate",         "12.0"))
    discount_rate  := Float(IniRead("settings.ini", profileSection, "DiscountRate",    "0.0"))
    vat_mode       := IniRead("settings.ini", profileSection, "VatMode", "Deduct")

    if (digit_length < 1)
        digit_length := 7
    if (vat_rate < 0 || vat_rate > 100)
        vat_rate := 12.0
    if (discount_rate < 0 || discount_rate > 100)
        discount_rate := 0.0
    if (vat_mode != "Deduct" && vat_mode != "Add")
        vat_mode := "Deduct"

    ; --- Custom text hotkeys ---
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
        hotkeyList := [{key: "!S", txt: "SAMPLE TXT", enabled: true}]
    }

    ; --- Folder Launcher entries ---
    folderLauncherList := []
    try {
        flSection := IniRead("settings.ini", "FolderLauncher")
        Loop Parse, flSection, "`n", "`r" {
            if (A_LoopField == "")
                continue
            pos := InStr(A_LoopField, "=")
            if (pos > 0) {
                flIdx   := SubStr(A_LoopField, 1, pos - 1)
                flVal   := SubStr(A_LoopField, pos + 1)
                ; format stored: label|path|hotkey|enabled
                parts   := StrSplit(flVal, "|")
                flLabel   := (parts.Length >= 1) ? parts[1] : ""
                flPath    := (parts.Length >= 2) ? parts[2] : ""
                flHotkey  := (parts.Length >= 3) ? parts[3] : ""
                flEnabled := (parts.Length >= 4) ? (parts[4] == "1") : true
                folderLauncherList.Push({label: flLabel, path: flPath, hotkey: flHotkey, enabled: flEnabled})
            }
        }
    }
}


; REGISTER SYSTEM HOTKEYS

RegisterSystemHotkeys() {
    global sysHK_Invoice, sysHK_Vat, sysHK_Discount, sysHK_Manager
    global sysFunc_Invoice, sysFunc_Vat, sysFunc_Discount, sysFunc_Manager

    if (sysFunc_Invoice != "")
        try Hotkey(sysFunc_Invoice, "Off")
    if (sysFunc_Vat != "")
        try Hotkey(sysFunc_Vat, "Off")
    if (sysFunc_Discount != "")
        try Hotkey(sysFunc_Discount, "Off")
    if (sysFunc_Manager != "")
        try Hotkey(sysFunc_Manager, "Off")

    invoiceAction := (*) => DoInvoiceHotkey()
    try {
        Hotkey(sysHK_Invoice, invoiceAction, "On")
        sysFunc_Invoice := sysHK_Invoice
    }

    vatAction := (*) => DoVatHotkey()
    try {
        Hotkey(sysHK_Vat, vatAction, "On")
        sysFunc_Vat := sysHK_Vat
    }

    discountAction := (*) => DoDiscountHotkey()
    try {
        Hotkey(sysHK_Discount, discountAction, "On")
        sysFunc_Discount := sysHK_Discount
    }

    managerAction := (*) => LaunchGUI()
    try {
        Hotkey(sysHK_Manager, managerAction, "On")
        sysFunc_Manager := sysHK_Manager
    }
}


; REGISTER FOLDER HOTKEYS

RegisterFolderHotkeys() {
    global folderLauncherList, activeFolderHotkeys

    ; First pass: turn off ALL previously registered folder hotkeys
    for hkStr, _ in activeFolderHotkeys
        try Hotkey(hkStr, "Off")

    ; Also turn off hotkeys for ALL current entries (catches hotkey changes)
    for fl in folderLauncherList {
        if (fl.hotkey != "")
            try Hotkey(fl.hotkey, "Off")
    }

    activeFolderHotkeys := Map()

    ; Second pass: register only enabled entries with a valid hotkey
    for fl in folderLauncherList {
        if (fl.hotkey == "" || !fl.enabled)
            continue
        if (activeFolderHotkeys.Has(fl.hotkey))
            continue  ; skip duplicate hotkeys — first entry wins
        flPath := fl.path
        try {
            boundFunc := CreateFolderFunc(flPath)
            Hotkey(fl.hotkey, boundFunc, "On")
            activeFolderHotkeys[fl.hotkey] := boundFunc
        }
    }
}

CreateFolderFunc(folderPath) {
    return (*) => OpenFolder(folderPath)
}

OpenFolder(folderPath) {
    if (!DirExist(folderPath)) {
        ToolTip("Folder not found: " . folderPath)
        SetTimer(() => ToolTip(), -3000)
        return
    }
    
    
    if (SubStr(folderPath, -1) != "\")
        folderPath .= "\"
        
    fileCount := 0
    
    
    Loop Files, folderPath . "*.*", "F" {
        try {
             
            
            Run('"' . A_LoopFilePath . '"')
            fileCount++
            
            
            Sleep(1000) 
        } catch {
            continue
        }
    }
    
    
    if (fileCount > 0) {
        
        SoundBeep(1000, 300)
        SoundBeep(1200, 400)
        ToolTip("🚀 Completed: " . fileCount . " files are now active.")
    } else {
        ToolTip("📂 Folder is empty (No files found): " . folderPath)
    }
    SetTimer(() => ToolTip(), -2500)
}


; SYSTEM HOTKEY ACTIONS

DoInvoiceHotkey() {
    Critical()
    global current_num, active_profile
    invoice_string := GenerateInvoice()
    SendInput(invoice_string)
    SoundBeep(750, 50)
    ToolTip("Invoice number sent: " . invoice_string)
    SetTimer(() => ToolTip(), -2000)
    current_num := Number(current_num) + 1
    profileSection := "Profile_" . active_profile
    IniWrite(current_num, "settings.ini", profileSection, "LastNumber")
}

DoVatHotkey() {
    global vat_rate, vat_mode
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        ToolTip("Nothing was copied. Please highlight a value first.")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    lines      := StrSplit(A_Clipboard, "`n", "`r")
    resultLines := []
    hasError   := false

    for line in lines {
        trimmed := Trim(line)
        if (trimmed == "") {
            resultLines.Push("")
            continue
        }
        CleanAmount := StrReplace(trimmed, ",", "")
        if IsNumber(CleanAmount) {
            divisor  := 1 + (vat_rate / 100)
            if (vat_mode == "Add") {
                computed := Round(Number(CleanAmount) * divisor, 2)
            } else {
                computed := Round(Number(CleanAmount) / divisor, 2)
            }
            resultLines.Push(Format("{:.2f}", computed))
        } else {
            hasError := true
            resultLines.Push(trimmed)
        }
    }

    if (hasError) {
        ToolTip("Warning: One or more lines contain non-numeric values and were skipped.")
        SetTimer(() => ToolTip(), -3000)
    }

    finalText := ""
    for i, r in resultLines {
        finalText .= r
        if (i < resultLines.Length)
            finalText .= "`n"
    }

    if (SubStr(A_Clipboard, -1) != "`n")
        finalText := RTrim(finalText, "`n")

    A_Clipboard := finalText
    Send("^v")

    modeLabel := (vat_mode == "Add") ? "Added" : "Deducted"
    ToolTip("VAT " . vat_rate . "% successfully " . modeLabel . ".")
    SetTimer(() => ToolTip(), -2000)
}

DoDiscountHotkey() {
    global discount_rate
    if (discount_rate <= 0) {
        ToolTip("Discount rate is currently set to 0%. Please configure it in the Manager first.")
        SetTimer(() => ToolTip(), -3000)
        return
    }

    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        ToolTip("Nothing was copied. Please highlight a value first.")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    lines       := StrSplit(A_Clipboard, "`n", "`r")
    resultLines := []
    hasError    := false

    for line in lines {
        trimmed := Trim(line)
        if (trimmed == "") {
            resultLines.Push("")
            continue
        }
        CleanAmount := StrReplace(trimmed, ",", "")
        if IsNumber(CleanAmount) {
            computed := Round(Number(CleanAmount) * (1 - discount_rate / 100), 2)
            resultLines.Push(Format("{:.2f}", computed))
        } else {
            hasError := true
            resultLines.Push(trimmed)
        }
    }

    if (hasError) {
        ToolTip("Warning: One or more lines contain non-numeric values and were skipped.")
        SetTimer(() => ToolTip(), -3000)
    }

    finalText := ""
    for i, r in resultLines {
        finalText .= r
        if (i < resultLines.Length)
            finalText .= "`n"
    }
    if (SubStr(A_Clipboard, -1) != "`n")
        finalText := RTrim(finalText, "`n")

    A_Clipboard := finalText
    Send("^v")

    ToolTip("Discount of " . discount_rate . "% applied successfully.")
    SetTimer(() => ToolTip(), -2000)
}


; CUSTOM TEXT HOTKEYS

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
            }
        }
    }
}

CreateHotkeyFunc(txt) {
    return (*) => SendTextSafe(txt)
}

SendTextSafe(txt) {
    global activeFolderHotkeys
    ; Suspend folder hotkeys so typed uppercase letters don't trigger them
    for hkStr, _ in activeFolderHotkeys
        try Hotkey(hkStr, "Off")
    SendInput(txt)
    for hkStr, hkFunc in activeFolderHotkeys
        try Hotkey(hkStr, hkFunc, "On")
}


; HELPERS

GenerateInvoice(p := "", n := 0, s := "", dlen := 0) {
    global prefix, current_num, suffix, digit_length
    target_prefix := (p == "")   ? prefix       : p
    target_num    := (n == 0)    ? current_num  : n
    target_suffix := (s == "")   ? suffix       : s
    target_dlen   := (dlen == 0) ? digit_length : dlen
    formatted_num := Format("{:0" . target_dlen . "}", target_num)
    return target_prefix . formatted_num . target_suffix
}

SaveProfileSettings(profileName, pfx, num, sfx, dlen, vrate, discrate, vmode) {
    profileSection := "Profile_" . profileName
    IniWrite(pfx,      "settings.ini", profileSection, "Prefix")
    IniWrite(num,      "settings.ini", profileSection, "LastNumber")
    IniWrite(sfx,      "settings.ini", profileSection, "Suffix")
    IniWrite(dlen,     "settings.ini", profileSection, "DigitLength")
    IniWrite(vrate,    "settings.ini", profileSection, "VatRate")
    IniWrite(discrate, "settings.ini", profileSection, "DiscountRate")
    IniWrite(vmode,    "settings.ini", profileSection, "VatMode")
}

GetProfileList() {
    profiles := ["Default"]
    try {
        allSections := IniRead("settings.ini")
        Loop Parse, allSections, "`n", "`r" {
            if (SubStr(A_LoopField, 1, 8) == "Profile_") {
                pName := SubStr(A_LoopField, 9)
                if (pName != "Default") {
                    found := false
                    for p in profiles
                        if (p == pName)
                            found := true
                    if (!found)
                        profiles.Push(pName)
                }
            }
        }
    }
    return profiles
}

BuildHKString(modSym, keyStr) {
    return modSym . keyStr
}

ParseHKString(hkStr) {
    modOptions := [
        {sym: "^!", label: "Ctrl+Alt (^!)"},
        {sym: "!+", label: "Alt+Shift (!+)"},
        {sym: "^+", label: "Ctrl+Shift (^+)"},
        {sym: "!",  label: "Alt (!)"},
        {sym: "^",  label: "Ctrl (^)"},
        {sym: "+",  label: "Shift (+)"}
    ]
    for opt in modOptions {
        if (SubStr(hkStr, 1, StrLen(opt.sym)) == opt.sym)
            return {modLabel: opt.label, keyStr: SubStr(hkStr, StrLen(opt.sym) + 1)}
    }
    return {modLabel: "Alt (!)", keyStr: hkStr}
}


; MAIN GUI

LaunchGUI() {
    global mainGui, current_num, prefix, suffix, digit_length, vat_rate
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Manager
    global discount_rate, vat_mode, sysHK_Discount
    global folderLauncherList

    LoadSettings()

    if (mainGui != "")
        mainGui.Destroy()

    mainGui := Gui("-MaximizeBox", "🎯 KeyTap Pro v4.6")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())
    mainGui.SetFont("s10", "Segoe UI")

    tabMenu := mainGui.Add("Tab3", "x10 y10 w660 h560",
        ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "Folder Launcher", "Mini Apps", "About"])

    modifierChoices := ["Alt (!)", "Ctrl (^)", "Shift (+)", "Ctrl+Alt (^!)", "Alt+Shift (!+)", "Ctrl+Shift (^+)"]
    modSymMap := Map(
        "Alt (!)",         "!",
        "Ctrl (^)",        "^",
        "Shift (+)",       "+",
        "Ctrl+Alt (^!)",   "^!",
        "Alt+Shift (!+)",  "!+",
        "Ctrl+Shift (^+)", "^+"
    )
    keyChoices := []
    Loop 26
        keyChoices.Push(Chr(64 + A_Index))
    Loop 12
        keyChoices.Push("F" . A_Index)
    for extraKey in ["1","2","3","4","5","6","7","8","9","0","Space","Tab","Enter","Delete","Home","End","PgUp","PgDn","Up","Down","Left","Right"]
        keyChoices.Push(extraKey)

    SetModDD(dd, label) {
        for i, c in modifierChoices {
            if (c == label) {
                dd.Value := i
                return
            }
        }
        dd.Value := 1
    }

    SetKeyDD(dd, keyStr) {
        for i, c in keyChoices {
            if (c == keyStr) {
                dd.Value := i
                return
            }
        }
        dd.Value := 1
    }

    
    ; TAB 1: INVOICE CONFIGURATION
    
    tabMenu.UseTab(1)

    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w450 h28 c0x0055AA", "🧾 Invoice Number Generator")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y76 w630 h18",
        "Configure the format of your invoice number and assign a hotkey to trigger it automatically.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y97 w305 h75", "  👤 Profile")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y118 w55 h22 +0x200", "Active:")
    profileList := GetProfileList()
    ddProfile := mainGui.Add("DropDownList", "x86 y116 w145 h200", profileList)
    for i, p in profileList {
        if (p == active_profile) {
            ddProfile.Value := i
            break
        }
    }
    btnNewProfile := mainGui.Add("Button", "x236 y116 w38 h24", "➕")
    btnDelProfile := mainGui.Add("Button", "x278 y116 w33 h24", "🗑")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y145 w285 h18",
        "Each profile has its own independent sequence & format")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    btnNewProfile.OnEvent("Click", NewProfile)
    btnDelProfile.OnEvent("Click", DeleteProfile)
    ddProfile.OnEvent("Change", SwitchProfile)

    mainGui.Add("GroupBox", "x330 y97 w305 h75", "  🔢 Invoice Format")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x345 y118 w55 h22 +0x200", "Prefix:")
    guiCtrl_Prefix := mainGui.Add("Edit", "x403 y116 w100 h24", prefix)
    mainGui.Add("Text", "x508 y118 w40 h22 +0x200", "Suffix:")
    guiCtrl_Suffix := mainGui.Add("Edit", "x552 y116 w75 h24", suffix)

    mainGui.Add("Text", "x345 y148 w80 h22 +0x200", "Digit Length:")
    guiCtrl_DigitLen := mainGui.Add("Edit", "x430 y146 w35 h24 Number", digit_length)
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x470 y150 w160 h18", "Enter digit count")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    guiCtrl_Prefix.OnEvent("Change", UpdatePreview)
    guiCtrl_Suffix.OnEvent("Change", UpdatePreview)
    guiCtrl_DigitLen.OnEvent("Change", UpdatePreview)

    mainGui.Add("GroupBox", "x15 y182 w305 h80", "  🔄 Sequence Number")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y203 w85 h22 +0x200", "Next Number:")
    guiCtrl_Num := mainGui.Add("Edit", "x120 y201 w100 h28 Number", current_num)
    guiCtrl_Num.SetFont("s11 Bold")
    btnReset := mainGui.Add("Button", "x228 y201 w82 h28", "↩ Reset to 0")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y235 w285 h18",
        "Enter Invoice Series Here.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    guiCtrl_Num.OnEvent("Change", UpdatePreview)
    btnReset.OnEvent("Click", (*) => (guiCtrl_Num.Value := "0", UpdatePreview()))

    mainGui.Add("GroupBox", "x330 y182 w305 h80", "  ⌨ Invoice Hotkey")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x345 y203 w60 h22 +0x200", "Hotkey:")
    ddInvMod := mainGui.Add("DropDownList", "x408 y201 w110 h200", modifierChoices)
    ddInvKey := mainGui.Add("DropDownList", "x523 y201 w105 h300", keyChoices)

    parsedInv := ParseHKString(sysHK_Invoice)
    SetModDD(ddInvMod, parsedInv.modLabel)
    SetKeyDD(ddInvKey, parsedInv.keyStr)

    guiCtrl_InvHKLabel := mainGui.Add("Text", "x345 y232 w285 h18 cGray",
        "Active: " . sysHK_Invoice)
    UpdateInvHKLabel() {
        sym := modSymMap[ddInvMod.Text]
        guiCtrl_InvHKLabel.Value := "Active: " . sym . ddInvKey.Text
    }
    ddInvMod.OnEvent("Change", (*) => UpdateInvHKLabel())
    ddInvKey.OnEvent("Change", (*) => UpdateInvHKLabel())

    mainGui.Add("GroupBox", "x15 y272 w620 h55", "  👁 Live Preview")
    mainGui.SetFont("bold s14 c0x005500", "Segoe UI")
    current_preview := GenerateInvoice()
    guiCtrl_PreviewText := mainGui.Add("Text",
        "x25 y288 w600 h30 Center +BackgroundTrans", current_preview)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y337 w305 h215", "  💡 How to Use")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    howToTxt := "
    (
Step 1.  Select an existing Profile from the dropdown, or create a new one by clicking the [+] button. Each profile stores its own invoice format and sequence number independently.

Step 2.  Set the Prefix, Suffix, and Digit Length in the Invoice Format section. These fields define the structure of the generated invoice number.

Step 3.  Verify the Next Number field. This is the number that will be used on the next hotkey press. You can reset it to zero at any time using the [Reset to 0] button.

Step 4.  Select your preferred Invoice Hotkey by choosing a Modifier key and a Key from the dropdowns.

Step 5.  Click [Save All Changes] to apply and save all settings to the configuration file.

Step 6.  Go to any application — spreadsheet, browser, text field — and press your hotkey. The invoice number will be typed automatically, and the sequence will increment by 1 after each use.
    )"
    mainGui.Add("Edit", "x25 y355 w285 h188 +ReadOnly +Wrap -WantReturn +VScroll", howToTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x330 y337 w305 h215", "  📌 Important Notes")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    notesTxt := "
    (
Invoice Format:
The invoice number is composed of three parts: a Prefix, a zero-padded sequence number, and a Suffix.

Example:
  Prefix : AAPI
  Number : 1
  Suffix : S
  Digits : 7
  Result : AAPI0000001S

Multiple Profiles:
Each Profile maintains its own independent sequence number, prefix, suffix, and digit length. This is particularly useful when handling invoices for different clients, branches, or document types within the same application.

Auto-Save:
The current sequence number is automatically saved to settings.ini after every hotkey press. Progress is never lost, even if the application is closed unexpectedly.
    )"
    mainGui.Add("Edit", "x340 y355 w285 h188 +ReadOnly +Wrap -WantReturn +VScroll", notesTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    
    ; TAB 2: CUSTOM TEXT HOTKEYS
    
    tabMenu.UseTab(2)

    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h28 c0x0055AA", "⌨ Custom Text Hotkeys")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y76 w630 h18",
        "Assign a keyboard shortcut to any text: company names, addresses, email templates, account numbers, or any phrase.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y97 w620 h215", "  📋 Hotkey List")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y116 w55 h22 +0x200", "Search:")
    editSearch := mainGui.Add("Edit", "x86 y114 w430 h24")
    btnClearSearch := mainGui.Add("Button", "x522 y114 w100 h24", "✖ Clear Filter")

    LV := mainGui.Add("ListView", "x28 y144 w592 h155 +Grid -Multi",
        ["Status", "Shortcut Key", "Text / Output"])
    LV.ModifyCol(1, 58)
    LV.ModifyCol(2, 105)
    LV.ModifyCol(3, 410)

    RefreshListView(filterTxt := "") {
        LV.Delete()
        for hk in hotkeyList {
            if (filterTxt != "" && !InStr(hk.key, filterTxt) && !InStr(hk.txt, filterTxt))
                continue
            statusTxt := hk.enabled ? "✅ ON" : "⛔ OFF"
            LV.Add(, statusTxt, hk.key, hk.txt)
        }
    }
    RefreshListView()

    editSearch.OnEvent("Change", (*) => RefreshListView(editSearch.Value))
    btnClearSearch.OnEvent("Click", (*) => (editSearch.Value := "", RefreshListView()))

    mainGui.Add("GroupBox", "x15 y322 w620 h130", "  ✏ Add or Edit a Hotkey")

    mainGui.SetFont("s9 Norm", "Segoe UI")

    mainGui.Add("Text", "x28 y343 w65 h24 +0x200", "Modifier:")
    ddModifier := mainGui.Add("DropDownList", "x96 y341 w130 h120", modifierChoices)
    ddModifier.Value := 1

    mainGui.Add("Text", "x235 y343 w30 h24 +0x200", "Key:")
    ddKey := mainGui.Add("DropDownList", "x268 y341 w65 h300", keyChoices)
    ddKey.Value := 1

    mainGui.SetFont("bold s9 c0x0055AA", "Segoe UI")
    mainGui.Add("Text", "x345 y343 w40 h24 +0x200", "→")
    mainGui.SetFont("s9 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x365 y343 w260 h24 +0x200",
        "Select Key Combination Here.")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    mainGui.Add("Text", "x28 y372 w65 h24 +0x200", "Text Output:")
    editTxt := mainGui.Add("Edit", "x96 y370 w520 h55 +Multi +WantReturn +VScroll")

    mainGui.Add("GroupBox", "x15 y462 w620 h88", "  🎛 Actions")

    btnAdd      := mainGui.Add("Button", "x28 y480 w145 h30", "➕ Add / Update")
    btnDel      := mainGui.Add("Button", "x180 y480 w130 h30", "❌ Delete")
    btnToggle   := mainGui.Add("Button", "x317 y480 w155 h30", "🔁 Toggle ON / OFF")
    btnMoveUp   := mainGui.Add("Button", "x480 y480 w70 h30", "▲ Up")
    btnMoveDown := mainGui.Add("Button", "x557 y480 w70 h30", "▼ Down")

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y516 w600 h28",
        "Tip: Click any row in the list above to load it into the editor below for modifications. The Text Output field supports multiple lines — press Enter to insert a new line. Use the Move Up and Move Down buttons to rearrange the order of your hotkeys.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    btnMoveUp.OnEvent("Click", MoveRowUp)
    btnMoveDown.OnEvent("Click", MoveRowDown)
    LV.OnEvent("Click", SelectHotkey)

    
    ; TAB 3: VAT CALCULATOR
    
    tabMenu.UseTab(3)

    mainGui.SetFont("bold s12", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h26 c0x0055AA", "💰 VAT & Discount Tool")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y74 w620 h18",
        "Configure your VAT rate, discount rate, and their respective hotkeys below.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y95 w305 h190", "  📋 VAT Configuration")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y118 w100 h20", "Active Profile:")
    mainGui.SetFont("bold s9 cGreen", "Segoe UI")
    guiCtrl_VatProfileLabel := mainGui.Add("Text", "x135 y118 w170 h20", active_profile)
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    mainGui.Add("Text", "x28 y148 w80 h22 +0x200", "VAT Rate:")
    vatPresets := ["12% (Standard)", "5% (Reduced)", "0% (Zero-rated)", "Custom..."]
    ddVatPreset    := mainGui.Add("DropDownList", "x110 y146 w120 h200", vatPresets)
    guiCtrl_VatRate := mainGui.Add("Edit", "x236 y146 w48 h22", Format("{:.2f}", vat_rate))
    mainGui.Add("Text", "x288 y148 w15 h20", "%")

    mainGui.Add("Text", "x28 y178 w80 h22 +0x200", "Mode:")
    rbDeduct := mainGui.Add("Radio", "x110 y178 w100 h22", "⬇ Deduct VAT")
    rbAdd     := mainGui.Add("Radio", "x215 y178 w100 h22", "⬆ Add VAT")
    if (vat_mode == "Add") {
        rbAdd.Value := 1
    } else {
        rbDeduct.Value := 1
    }

    guiCtrl_VatPreview := mainGui.Add("Text", "x28 y207 w285 h18 cBlue", "")

    mainGui.Add("Text", "x28 y233 w80 h22 +0x200", "Hotkey:")
    ddVatMod := mainGui.Add("DropDownList", "x110 y231 w108 h200", modifierChoices)
    ddVatKey := mainGui.Add("DropDownList", "x223 y231 w65 h300", keyChoices)
    guiCtrl_VatHKLabel := mainGui.Add("Text", "x110 y256 w200 h18 cGray", "Active: " . sysHK_Vat)

    parsedVat := ParseHKString(sysHK_Vat)
    SetModDD(ddVatMod, parsedVat.modLabel)
    SetKeyDD(ddVatKey, parsedVat.keyStr)

    mainGui.Add("GroupBox", "x330 y95 w305 h190", "  🏷 Discount Settings")

    mainGui.SetFont("s9 Norm", "Segoe UI")

    mainGui.Add("Text", "x345 y118 w100 h22 +0x200", "Discount Rate:")
    guiCtrl_DiscRate := mainGui.Add("Edit", "x450 y118 w60 h22", Format("{:.2f}", discount_rate))
    mainGui.Add("Text", "x514 y118 w15 h22 +0x200", "%")

    guiCtrl_DiscPreview := mainGui.Add("Text", "x345 y148 w280 h18 cBlue", "")

    mainGui.Add("Text", "x345 y172 w60 h22 +0x200", "Quick set:")
    btn5pct  := mainGui.Add("Button", "x410 y170 w40 h24", "5%")
    btn10pct := mainGui.Add("Button", "x454 y170 w40 h24", "10%")
    btn15pct := mainGui.Add("Button", "x498 y170 w40 h24", "15%")
    btn20pct := mainGui.Add("Button", "x542 y170 w40 h24", "20%")
    btn5pct.OnEvent("Click",  (*) => (guiCtrl_DiscRate.Value := "5.00",  UpdateDiscPreview()))
    btn10pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "10.00", UpdateDiscPreview()))
    btn15pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "15.00", UpdateDiscPreview()))
    btn20pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "20.00", UpdateDiscPreview()))

    mainGui.Add("Text", "x345 y204 w65 h22 +0x200", "Hotkey:")
    ddDiscMod := mainGui.Add("DropDownList", "x415 y202 w108 h200", modifierChoices)
    ddDiscKey := mainGui.Add("DropDownList", "x527 y202 w65 h300", keyChoices)
    guiCtrl_DiscHKLabel := mainGui.Add("Text", "x415 y227 w200 h18 cGray", "Active: " . sysHK_Discount)

    parsedDisc := ParseHKString(sysHK_Discount)
    SetModDD(ddDiscMod, parsedDisc.modLabel)
    SetKeyDD(ddDiscKey, parsedDisc.keyStr)

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x345 y252 w280 h30",
        "This hotkey operates on highlighted text in any application.")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y295 w620 h235", "  🧮 Built-In Calculator")

    mainGui.SetFont("bold s9 c0x333333", "Segoe UI")
    mainGui.Add("Text", "x28 y318 w280 h18", "ENTER VALUES")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    mainGui.Add("Text", "x28 y342 w90 h24 +0x200", "Gross Amount:")
    calcInput := mainGui.Add("Edit", "x125 y340 w150 h26")
    calcInput.SetFont("s11")

    mainGui.Add("Text", "x28 y375 w90 h24 +0x200", "Discount %:")
    calcDiscInput := mainGui.Add("Edit", "x125 y373 w70 h24", Format("{:.2f}", discount_rate))
    mainGui.Add("Text", "x199 y375 w12 h22 +0x200", "%")

    mainGui.Add("Text", "x28 y405 w90 h24 +0x200", "VAT %:")
    calcVatInput := mainGui.Add("Edit", "x125 y403 w70 h24", Format("{:.2f}", vat_rate))
    mainGui.Add("Text", "x199 y405 w12 h22 +0x200", "%")

    mainGui.Add("Text", "x28 y435 w90 h24 +0x200", "Order:")
    calcOrderChoices := ["Apply Discount first, then VAT", "Apply VAT first, then Discount"]
    ddCalcOrder := mainGui.Add("DropDownList", "x125 y433 w160 h100", calcOrderChoices)
    ddCalcOrder.Value := 1

    mainGui.Add("Text", "x28 y463 w90 h24 +0x200", "VAT Mode:")
    calcModeChoices := ["Deduct VAT — remove VAT from the gross amount", "Add VAT — add VAT on top of the net amount"]
    ddCalcMode := mainGui.Add("DropDownList", "x125 y461 w175 h100", calcModeChoices)
    ddCalcMode.Value := (vat_mode == "Add") ? 2 : 1

    btnCalculate := mainGui.Add("Button", "x28 y495 w120 h30", "↺ Recalculate")
    btnClearCalc := mainGui.Add("Button", "x155 y495 w70 h30", "🗑 Clear")

    mainGui.Add("Text", "x320 y295 w2 h235 +0x10")

    mainGui.SetFont("bold s9 c0x333333", "Segoe UI")
    mainGui.Add("Text", "x335 y318 w290 h18", "COMPUTED BREAKDOWN")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    mainGui.Add("Text", "x335 y342 w130 h22 +0x200", "Gross Amount:")
    calcGrossLabel := mainGui.Add("Text", "x475 y342 w155 h22 +0x202", "—")

    mainGui.Add("Text", "x335 y368 w130 h22 +0x200 cRed", "Discount:")
    calcDiscLabel  := mainGui.Add("Text", "x475 y368 w155 h22 +0x202 cRed", "—")

    mainGui.Add("Text", "x335 y394 w130 h22 +0x200", "After Discount:")
    calcAfterDisc  := mainGui.Add("Text", "x475 y394 w155 h22 +0x202", "—")

    mainGui.Add("Text", "x335 y420 w130 h22 +0x200 cMaroon", "VAT Amount:")
    calcVatLabel   := mainGui.Add("Text", "x475 y420 w155 h22 +0x202 cMaroon", "—")

    mainGui.Add("Text", "x335 y446 w300 h1 +0x10")

    mainGui.SetFont("bold s11 c0x005500", "Segoe UI")
    mainGui.Add("Text", "x335 y452 w130 h26 +0x200", "NET AMOUNT:")
    calcNetLabel   := mainGui.Add("Text", "x475 y452 w155 h26 +0x202 c0x005500", "—")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    mainGui.Add("Text", "x335 y480 w300 h1 +0x10")

    btnCopyNet := mainGui.Add("Button", "x335 y488 w140 h28", "📋 Copy Net Amount")
    btnCopyAll := mainGui.Add("Button", "x485 y488 w148 h28", "📋 Copy Full Breakdown")

    calcNetValue := ""

    guiCtrl_VatModeValue := vat_mode

    SetVatPresetFromRate(r) {
        if (r == 12.0) {
            ddVatPreset.Value := 1
        } else if (r == 5.0) {
            ddVatPreset.Value := 2
        } else if (r == 0.0) {
            ddVatPreset.Value := 3
        } else {
            ddVatPreset.Value := 4
        }
    }
    SetVatPresetFromRate(vat_rate)

    UpdateVatPreview() {
        raw := guiCtrl_VatRate.Value
        if (!IsNumber(raw) || Number(raw) < 0 || Number(raw) > 100) {
            guiCtrl_VatPreview.Value := "  ⚠ VAT rate invalid"
            return
        }
        r    := Number(raw)
        mode := guiCtrl_VatModeValue
        if (mode == "Add") {
            gross := Round(1000 * (1 + r / 100), 2)
            guiCtrl_VatPreview.Value := "e.g.  ₱1,000.00  →  ₱" . Format("{:.2f}", gross) . "  (+VAT " . r . "%)"
        } else {
            net := Round(1000 / (1 + r / 100), 2)
            guiCtrl_VatPreview.Value := "e.g.  ₱1,000.00  →  ₱" . Format("{:.2f}", net) . "  (-VAT " . r . "%)"
        }
    }
    UpdateVatPreview()

    UpdateDiscPreview() {
        raw := guiCtrl_DiscRate.Value
        if (!IsNumber(raw) || Number(raw) < 0 || Number(raw) > 100) {
            guiCtrl_DiscPreview.Value := "  ⚠ invalid discount rate"
            return
        }
        r   := Number(raw)
        net := Round(1000 * (1 - r / 100), 2)
        guiCtrl_DiscPreview.Value := "e.g.  ₱1,000.00  →  ₱" . Format("{:.2f}", net) . "  (" . r . "% off)"
    }
    UpdateDiscPreview()

    OnVatPresetChange(*) {
        if (ddVatPreset.Value == 1) {
            guiCtrl_VatRate.Value := "12.00"
        } else if (ddVatPreset.Value == 2) {
            guiCtrl_VatRate.Value := "5.00"
        } else if (ddVatPreset.Value == 3) {
            guiCtrl_VatRate.Value := "0.00"
        } else {
            guiCtrl_VatRate.Focus()
        }
        UpdateVatPreview()
    }
    ddVatPreset.OnEvent("Change", OnVatPresetChange)

    OnVatRateChange(*) {
        v := guiCtrl_VatRate.Value
        if (v == "12" || v == "12.0" || v == "12.00") {
            ddVatPreset.Value := 1
        } else if (v == "5" || v == "5.0" || v == "5.00") {
            ddVatPreset.Value := 2
        } else if (v == "0" || v == "0.0" || v == "0.00") {
            ddVatPreset.Value := 3
        } else {
            ddVatPreset.Value := 4
        }
        UpdateVatPreview()
        calcVatInput.Value := guiCtrl_VatRate.Value
    }
    guiCtrl_VatRate.OnEvent("Change", OnVatRateChange)

    OnRbDeduct(*) {
        guiCtrl_VatModeValue := "Deduct"
        ddCalcMode.Value := 1
        UpdateVatPreview()
    }
    OnRbAdd(*) {
        guiCtrl_VatModeValue := "Add"
        ddCalcMode.Value := 2
        UpdateVatPreview()
    }
    rbDeduct.OnEvent("Click", OnRbDeduct)
    rbAdd.OnEvent("Click", OnRbAdd)

    UpdateVatHKLabel() {
        sym := modSymMap[ddVatMod.Text]
        guiCtrl_VatHKLabel.Value := "Active: " . sym . ddVatKey.Text
    }
    ddVatMod.OnEvent("Change", (*) => UpdateVatHKLabel())
    ddVatKey.OnEvent("Change", (*) => UpdateVatHKLabel())

    UpdateDiscHKLabel() {
        sym := modSymMap[ddDiscMod.Text]
        guiCtrl_DiscHKLabel.Value := "Active: " . sym . ddDiscKey.Text
    }
    ddDiscMod.OnEvent("Change", (*) => UpdateDiscHKLabel())
    ddDiscKey.OnEvent("Change", (*) => UpdateDiscHKLabel())

    guiCtrl_DiscRate.OnEvent("Change", (*) => UpdateDiscPreview())

    FmtNum(n) {
        s       := Format("{:.2f}", n)
        dotPos  := InStr(s, ".")
        intPart := SubStr(s, 1, dotPos - 1)
        decPart := SubStr(s, dotPos)
        result  := ""
        len     := StrLen(intPart)
        Loop len {
            idx := A_Index
            result .= SubStr(intPart, idx, 1)
            rem := len - idx
            if (rem > 0 && Mod(rem, 3) == 0) {
                result .= ","
            }
        }
        return result . decPart
    }

    DoCalculate(*) {
        rawAmt  := StrReplace(calcInput.Value, ",", "")
        rawDisc := calcDiscInput.Value
        rawVat  := calcVatInput.Value

        if (!IsNumber(rawAmt) || Number(rawAmt) <= 0) {
            calcNetLabel.Value   := "Enter VAlid Amount."
            calcGrossLabel.Value := "—"
            calcDiscLabel.Value  := "—"
            calcAfterDisc.Value  := "—"
            calcVatLabel.Value   := "—"
            return
        }
        if (!IsNumber(rawDisc) || Number(rawDisc) < 0 || Number(rawDisc) > 100) {
            calcNetLabel.Value := "Discount percentage must be between 0 and 100."
            return
        }
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            calcNetLabel.Value := "VAT percentage must be between 0 and 100."
            return
        }

        gross    := Number(rawAmt)
        discPct  := Number(rawDisc)
        vatPct   := Number(rawVat)
        calcMode := (ddCalcMode.Value == 2) ? "Add" : "Deduct"
        order    := ddCalcOrder.Value

        discAmt   := 0.0
        vatAmt    := 0.0
        afterDisc := gross
        net       := gross

        if (order == 1) {
            discAmt   := Round(gross * discPct / 100, 2)
            afterDisc := Round(gross - discAmt, 2)
            if (calcMode == "Add") {
                vatAmt := Round(afterDisc * vatPct / 100, 2)
                net    := Round(afterDisc + vatAmt, 2)
            } else {
                net    := Round(afterDisc / (1 + vatPct / 100), 2)
                vatAmt := Round(afterDisc - net, 2)
            }
        } else {
            if (calcMode == "Add") {
                vatAmt    := Round(gross * vatPct / 100, 2)
                afterVat  := Round(gross + vatAmt, 2)
                discAmt   := Round(afterVat * discPct / 100, 2)
                net       := Round(afterVat - discAmt, 2)
                afterDisc := afterVat
            } else {
                net       := Round(gross / (1 + vatPct / 100), 2)
                vatAmt    := Round(gross - net, 2)
                discAmt   := Round(net * discPct / 100, 2)
                net       := Round(net - discAmt, 2)
                afterDisc := gross
            }
        }

        calcNetValue := FmtNum(net)
        calcGrossLabel.Value := "₱ " . FmtNum(gross)
        calcDiscLabel.Value  := "-₱ " . FmtNum(discAmt) . "  (" . discPct . "% off)"
        calcAfterDisc.Value  := "₱ " . FmtNum(afterDisc)
        calcVatLabel.Value   := (calcMode == "Add" ? "+₱ " : "-₱ ") . FmtNum(vatAmt) . "  (" . vatPct . "%)"
        calcNetLabel.Value   := "₱ " . calcNetValue
    }

    OnClearCalc(*) {
        calcInput.Value      := ""
        calcDiscInput.Value  := Format("{:.2f}", discount_rate)
        calcVatInput.Value   := Format("{:.2f}", vat_rate)
        calcGrossLabel.Value := "—"
        calcDiscLabel.Value  := "—"
        calcAfterDisc.Value  := "—"
        calcVatLabel.Value   := "—"
        calcNetLabel.Value   := "—"
        calcNetValue         := ""
        calcInput.Focus()
    }

    btnCalculate.OnEvent("Click", DoCalculate)
    btnClearCalc.OnEvent("Click", OnClearCalc)

    calcInput.OnEvent("Change",     (*) => DoCalculate())
    calcDiscInput.OnEvent("Change", (*) => DoCalculate())
    calcVatInput.OnEvent("Change",  (*) => DoCalculate())
    ddCalcOrder.OnEvent("Change",   (*) => DoCalculate())
    ddCalcMode.OnEvent("Change",    (*) => DoCalculate())

    OnCopyNet(*) {
        if (calcNetValue == "") {
            ToolTip("No result yet. Please fill in the Amount field and press Calculate.")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        A_Clipboard := calcNetValue
        ToolTip("Net amount copied to clipboard: " . calcNetValue)
        SetTimer(() => ToolTip(), -2000)
    }
    btnCopyNet.OnEvent("Click", OnCopyNet)

    OnCopyAll(*) {
        if (calcNetValue == "") {
            ToolTip("No result yet. Please fill in the Amount field and press Calculate.")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        breakdown := "Gross Amount:    " . calcGrossLabel.Value . "`n"
                   . "Discount:        " . calcDiscLabel.Value . "`n"
                   . "After Discount:  " . calcAfterDisc.Value . "`n"
                   . "VAT Amount:      " . calcVatLabel.Value . "`n"
                   . "─────────────────────────`n"
                   . "NET AMOUNT:      " . calcNetLabel.Value
        A_Clipboard := breakdown
        ToolTip("Full breakdown copied to clipboard.")
        SetTimer(() => ToolTip(), -2000)
    }
    btnCopyAll.OnEvent("Click", OnCopyAll)

    
    ; TAB 4: FOLDER LAUNCHER
    
    tabMenu.UseTab(4)

    ; ── HEADER ───────────────────────────────────────────────
    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h28 c0x0055AA", "📂 Folder Launcher")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y76 w630 h18",
        "Register folder locations and open them instantly with a hotkey — or use the Open button directly from this panel.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── FOLDER LIST ──────────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y97 w620 h180", "  📋 Registered Folders")

    FL_LV := mainGui.Add("ListView", "x28 y115 w592 h150 +Grid -Multi",
        ["Status", "Label / Description", "Folder Path", "Hotkey"])
    FL_LV.ModifyCol(1, 55)
    FL_LV.ModifyCol(2, 130)
    FL_LV.ModifyCol(3, 300)
    FL_LV.ModifyCol(4, 85)

    RefreshFolderLV() {
        FL_LV.Delete()
        for fl in folderLauncherList {
            existsTxt := DirExist(fl.path) ? "✅ OK" : "⚠ Missing"
            FL_LV.Add(, existsTxt, fl.label, fl.path, fl.hotkey)
        }
    }
    RefreshFolderLV()

    ; ── ADD / EDIT FOLDER ────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y285 w620 h135", "  ✏ Add or Edit a Folder Entry")

    mainGui.SetFont("s9 Norm", "Segoe UI")

    ; Row 1: Label
    mainGui.Add("Text", "x28 y306 w80 h24 +0x200", "Label:")
    fl_editLabel := mainGui.Add("Edit", "x112 y304 w200 h24")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x318 y308 w305 h18", "Short name for this folder (e.g. Projects, Invoices 2026)")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    ; Row 2: Folder path + Browse button
    mainGui.Add("Text", "x28 y336 w80 h24 +0x200", "Folder Path:")
    fl_editPath := mainGui.Add("Edit", "x112 y334 w430 h24")
    btnBrowse := mainGui.Add("Button", "x548 y334 w75 h24", "📁 Browse")

    ; Row 3: Hotkey assignment
    mainGui.Add("Text", "x28 y366 w80 h24 +0x200", "Hotkey:")
    ddFlMod := mainGui.Add("DropDownList", "x112 y364 w120 h200", modifierChoices)
    ddFlMod.Value := 1
    ddFlKey := mainGui.Add("DropDownList", "x238 y364 w70 h300", keyChoices)
    ddFlKey.Value := 1
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    fl_hkLabel := mainGui.Add("Text", "x315 y368 w165 h18 cGray", "Active: none")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    mainGui.Add("Text", "x485 y368 w148 h18 cGray", "(Leave key as-is = no hotkey)")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    UpdateFlHKLabel() {
        if (ddFlKey.Value == 1) {
            fl_hkLabel.Value := "Active: none"
        } else {
            sym := modSymMap[ddFlMod.Text]
            fl_hkLabel.Value := "Active: " . sym . ddFlKey.Text
        }
    }
    ddFlMod.OnEvent("Change", (*) => UpdateFlHKLabel())
    ddFlKey.OnEvent("Change", (*) => UpdateFlHKLabel())

    ; Browse button action
    DoBrowse(*) {
        chosen := DirSelect("*" . fl_editPath.Value, 3, "Select a folder to register")
        if (chosen != "")
            fl_editPath.Value := chosen
    }
    btnBrowse.OnEvent("Click", DoBrowse)

    ; ── ACTION BUTTONS ───────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y428 w620 h88", "  🎛 Actions")

    btnFlAdd    := mainGui.Add("Button", "x28 y446 w145 h30", "➕ Add / Update")
    btnFlDel    := mainGui.Add("Button", "x180 y446 w130 h30", "❌ Delete")
    btnFlToggle := mainGui.Add("Button", "x317 y446 w155 h30", "🔁 Toggle ON / OFF")
    btnFlOpen   := mainGui.Add("Button", "x480 y446 w150 h30", "📂 Open Selected Now")

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y482 w600 h28",
        "Tip: Click any row to load it into the editor. Use [Open Selected Now] to open the folder immediately without a hotkey. Hotkeys are optional — a folder entry without a hotkey can still be opened from this panel. ")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── HOW TO USE + NOTES ───────────────────────────────────
    mainGui.Add("GroupBox", "x15 y525 w305 h50", "  💡 Quick Tips")
    mainGui.SetFont("s8 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y542 w285 h30",
        "You can register network paths (\\server\share), USB drives, or any local folder. ")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x330 y525 w305 h50", "  📌 Storage")
    mainGui.SetFont("s8 Norm", "Segoe UI")
    mainGui.Add("Text", "x343 y542 w285 h30",
        "All folder entries are saved to settings.ini under [FolderLauncher]. ")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── FOLDER LIST CLICK → LOAD INTO EDITOR ─────────────────
    FL_LV.OnEvent("Click", SelectFolderEntry)

    SelectFolderEntry(CtrlObj, RowNumber) {
        if (RowNumber == 0)
            return
        fl_editLabel.Value := CtrlObj.GetText(RowNumber, 2)
        fl_editPath.Value  := CtrlObj.GetText(RowNumber, 3)
        hkStr := CtrlObj.GetText(RowNumber, 4)
        if (hkStr != "") {
            parsed := ParseHKString(hkStr)
            SetModDD(ddFlMod, parsed.modLabel)
            SetKeyDD(ddFlKey, parsed.keyStr)
        } else {
            ddFlMod.Value := 1
            ddFlKey.Value := 1
        }
        UpdateFlHKLabel()
    }

    ; ── FOLDER ACTIONS ───────────────────────────────────────
    btnFlAdd.OnEvent("Click", AddUpdateFolder)
    btnFlDel.OnEvent("Click", DeleteFolder)
    btnFlToggle.OnEvent("Click", ToggleFolder)
    btnFlOpen.OnEvent("Click", OpenSelectedFolder)

    AddUpdateFolder(*) {
        newLabel := Trim(fl_editLabel.Value)
        newPath  := Trim(fl_editPath.Value)
        if (newLabel == "") {
            MsgBox("Please enter a label for this folder entry.", "Required Field", 48)
            return
        }
        if (newPath == "") {
            MsgBox("Please enter or browse to a folder path.", "Required Field", 48)
            return
        }
        ; Build hotkey string — if key dropdown is at position 1 (default), treat as "no hotkey"
        newHK := (ddFlKey.Value == 1) ? "" : (modSymMap[ddFlMod.Text] . ddFlKey.Text)

        ; Check for hotkey conflict with system/custom hotkeys
        if (newHK != "") {
            if (newHK == sysHK_Invoice || newHK == sysHK_Vat || newHK == sysHK_Discount || newHK == sysHK_Manager) {
                MsgBox("Hotkey Conflict: '" . newHK . "' is already used by a system hotkey. Please choose a different combination.", "Conflict", 48)
                return
            }
            for hk in hotkeyList {
                if (hk.key == newHK) {
                    MsgBox("Hotkey Conflict: '" . newHK . "' is already used by a Custom Text Hotkey. Please choose a different combination.", "Conflict", 48)
                    return
                }
            }
        }

        ; Find existing row by label
        rowToUpdate := 0
        Loop FL_LV.GetCount() {
            if (FL_LV.GetText(A_Index, 2) == newLabel) {
                rowToUpdate := A_Index
                break
            }
        }

        existsTxt := DirExist(newPath) ? "✅ OK" : "⚠ Missing"
        if (rowToUpdate > 0) {
            FL_LV.Modify(rowToUpdate, , existsTxt, newLabel, newPath, newHK)
        } else {
            FL_LV.Add(, existsTxt, newLabel, newPath, newHK)
        }

        fl_editLabel.Value := ""
        fl_editPath.Value  := ""
        ddFlMod.Value := 1
        ddFlKey.Value := 1
        fl_hkLabel.Value := "Active: none"
    }

    DeleteFolder(*) {
        selectedRow := FL_LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Please select a folder entry from the list before deleting.", "No Selection", 48)
            return
        }
        FL_LV.Delete(selectedRow)
        fl_editLabel.Value := ""
        fl_editPath.Value  := ""
        ddFlMod.Value := 1
        ddFlKey.Value := 1
        fl_hkLabel.Value := "Active: none"
    }

    ToggleFolder(*) {
        selectedRow := FL_LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Please select a folder entry from the list before toggling.", "No Selection", 48)
            return
        }
        currentStatus := FL_LV.GetText(selectedRow, 1)
        lbl := FL_LV.GetText(selectedRow, 2)
        pth := FL_LV.GetText(selectedRow, 3)
        hk  := FL_LV.GetText(selectedRow, 4)

        ; Status col is either "✅ OK", "⚠ Missing", "⛔ OFF"
        if (InStr(currentStatus, "OFF")) {
            newStatus := DirExist(pth) ? "✅ OK" : "⚠ Missing"
        } else {
            newStatus := "⛔ OFF"
        }
        FL_LV.Modify(selectedRow, , newStatus, lbl, pth, hk)
    }

    OpenSelectedFolder(*) {
    selectedRow := FL_LV.GetNext()
    if (selectedRow == 0) {
        MsgBox("Please select a folder entry from the list first.", "No Selection", 48)
        return
    }
    pth := FL_LV.GetNext() ? FL_LV.GetText(selectedRow, 3) : ""
    
    if (!DirExist(pth)) {
        MsgBox("The folder path does not exist or is not accessible:`n`n" . pth, "Folder Not Found", 48)
        return
    }
    
    
    OpenFolder(pth)
}

    
    
    ; TAB 5: MINI APPS
    
    tabMenu.UseTab(5)

    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h26 c0x0055AA", "🧰 Mini Apps & Tools")
    mainGui.SetFont("s8 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y75 w630 h16",
        "Click any tool to launch it in its own window. Each app runs independently.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── Card dimensions ─────────────────────────────────────
    ; Col1 x=15  Col2 x=335  CardW=310  CardH=116
    ; Rows: y=94, 220, 346, 466

    ; === ROW 1 ===
    ; Card 1-1: Scratchpad
    mainGui.Add("GroupBox", "x15 y94 w310 h116", "  📝 Quick Scratchpad")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x26 y113 w285 h36",
        "Floating notepad for quick notes and clipboard drafts. Notes persist across restarts.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x26 y152 w175 h16", "✦ Auto-saves on close")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchScratch := mainGui.Add("Button", "x200 y149 w118 h26", "📝 Open Notepad")
    btnLaunchScratch.OnEvent("Click", (*) => LaunchScratchpad())

    ; Card 1-2: Volume Control
    mainGui.Add("GroupBox", "x335 y94 w310 h116", "  🔊 Volume & Media Control")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x346 y113 w285 h36",
        "Control system volume with a slider. Manage media playback — play, pause, skip, mute.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x346 y152 w175 h16", "✦ Uses Windows multimedia keys")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchVol := mainGui.Add("Button", "x520 y149 w118 h26", "🔊 Open Volume")
    btnLaunchVol.OnEvent("Click", (*) => LaunchVolumeControl())

    ; === ROW 2 ===
    ; Card 2-1: Screen Dimmer
    mainGui.Add("GroupBox", "x15 y220 w310 h116", "  🌙 Screen Dimmer / Eye Care")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x26 y239 w285 h36",
        "Overlays a dark transparent layer on your screen to reduce brightness and eye strain.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x26 y278 w175 h16", "✦ Adjustable opacity, hideable")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchDimmer := mainGui.Add("Button", "x200 y275 w118 h26", "🌙 Open Dimmer")
    btnLaunchDimmer.OnEvent("Click", (*) => LaunchScreenDimmer())

    ; Card 2-2: Disk Cleaner
    mainGui.Add("GroupBox", "x335 y220 w310 h116", "  🗑 Disk Cleaner")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x346 y239 w285 h36",
        "Empty the Recycle Bin and flush Windows Temp folder to free up disk space in one click.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x346 y278 w175 h16", "✦ Shows files removed after cleanup")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchCleaner := mainGui.Add("Button", "x520 y275 w118 h26", "🗑 Open Cleaner")
    btnLaunchCleaner.OnEvent("Click", (*) => LaunchDiskCleaner())

    ; === ROW 3 ===
    ; Card 3-1: Live Clock
    mainGui.Add("GroupBox", "x15 y346 w310 h116", "  🕐 Live Clock & Date")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x26 y365 w285 h36",
        "Compact floating clock showing live time and date. Always-on-top over any window.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x26 y404 w175 h16", "✦ Click to toggle date display")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchClock := mainGui.Add("Button", "x200 y401 w118 h26", "🕐 Open Clock")
    btnLaunchClock.OnEvent("Click", (*) => LaunchLiveClock())

    ; Card 3-2: Pomodoro Timer
    mainGui.Add("GroupBox", "x335 y346 w310 h116", "  🍅 Pomodoro / Work Timer")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x346 y365 w285 h36",
        "Focus timer: 25-minute work sessions with 5-minute breaks. Beeps when session ends.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x346 y404 w175 h16", "✦ Customizable work/break duration")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchPomo := mainGui.Add("Button", "x520 y401 w118 h26", "🍅 Open Timer")
    btnLaunchPomo.OnEvent("Click", (*) => LaunchPomodoro())

    ; === ROW 4 ===
    ; Card 4-1: Color Picker
    mainGui.Add("GroupBox", "x15 y472 w310 h100", "  🎨 Color Picker")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x26 y491 w285 h30",
        "Pick any color on screen. Instantly copies the HEX and RGB values to clipboard.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x26 y524 w175 h16", "✦ Click button to capture pixel color")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchColor := mainGui.Add("Button", "x200 y521 w118 h26", "🎨 Open Picker")
    btnLaunchColor.OnEvent("Click", (*) => LaunchColorPicker())

    ; Card 4-2: Case Converter
    mainGui.Add("GroupBox", "x335 y472 w310 h100", "  🔡 Text Case Converter")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x346 y491 w285 h30",
        "Convert text to UPPER, lower, Title, or Sentence case. Paste in, convert, copy out.")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x346 y524 w175 h16", "✦ Works on multi-line text")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")
    btnLaunchCase := mainGui.Add("Button", "x520 y521 w118 h26", "🔡 Open Converter")
    btnLaunchCase.OnEvent("Click", (*) => LaunchCaseConverter())

    ; TAB 6: ABOUT
    
    tabMenu.UseTab(6)

    mainGui.Add("GroupBox", "x15 y48 w620 h118", "  🎯 About This Application")
    mainGui.SetFont("bold s14 c0x0055AA", "Segoe UI")
    mainGui.Add("Text", "x30 y68 w380 h30", "🎯 KeyTap Pro  v4.6")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x30 y100 w85 h20 +0x200", "Version:")
    mainGui.Add("Text", "x118 y100 w270 h20", "4.6.0 ")
    mainGui.Add("Text", "x30 y120 w85 h20 +0x200", "Developer:")
    mainGui.Add("Text", "x118 y120 w180 h20", "Jerom Requillo")
    mainGui.Add("Text", "x30 y140 w85 h20 +0x200", "Build Date:")
    mainGui.Add("Text", "x118 y140 w180 h20", "2026")
    mainGui.SetFont("italic s9 c0x0055AA", "Segoe UI")
    mainGui.Add("Link", "x420 y100 w205 h20",
        'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x420 y122 w205 h20",
        'Repo: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo/KeyTap-Pro</a>')
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y174 w305 h160", "  ⌨ Hotkey Reference")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    hkRefTxt := "
    (
All hotkeys are configured in their respective tabs and can be reassigned at any time.

Invoice Hotkey
Automatically types the next invoice number and increments the sequence counter by one after each use.

VAT Hotkey
Deducts or adds VAT to any highlighted amount in any active application window.

Discount Hotkey
Applies the configured discount rate to any highlighted amount. Multiple lines are supported simultaneously.

Folder Hotkeys
Opens a registered folder in Windows Explorer instantly. Each folder entry can have its own optional hotkey.

Alt + F10  (Fixed — cannot be changed)
Opens this Manager window from anywhere on the system.
    )"
    mainGui.Add("Edit", "x27 y192 w285 h133 +ReadOnly +Wrap +VScroll -WantReturn", hkRefTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x328 y174 w307 h160", "  🛠 Troubleshooting Guide")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    tsTxt := "
    (
1.  Hotkeys are not responding.
Check the Windows System Tray (lower-right of taskbar) for the H icon. If the application is running but unresponsive, right-click the icon and select Reload Script.

2.  Settings are not being saved.
Verify that the settings.ini file in the application folder is not marked as Read-Only. Right-click the file, open Properties, and uncheck the Read-Only attribute.

3.  The application crashes on startup.
Check your custom hotkey list for duplicate or invalid key combinations. No two hotkeys may share the same key assignment.

4.  Tray icon double-click does not open the Manager.
Ensure only one instance of the application is running. Exit from the tray menu and relaunch if needed.
    )"
    mainGui.Add("Edit", "x340 y192 w287 h133 +ReadOnly +Wrap +VScroll -WantReturn", tsTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y342 w620 h110", "  📂 Deployment and Portability")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    deployTxt := "
    (
Fully Portable — No Windows Registry entries are required. The application runs directly from any location including a USB drive, a shared network folder, or the Windows Startup directory for automatic launch on login.

All settings are stored in a single settings.ini file located in the same folder as the application. No installation is required and the application can be moved or copied freely without reconfiguration.

Multiple Profiles are supported within a single installation. Each profile maintains its own invoice sequence, VAT rate, discount rate, and hotkey format independently.
    )"
    mainGui.Add("Edit", "x27 y360 w592 h84 +ReadOnly +Wrap +VScroll -WantReturn", deployTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    mainGui.Add("GroupBox", "x15 y460 w620 h148", "  📝 Version History")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    clTxt := "
    (

v4.6  —  Mini Apps tab added. Eight built-in utility tools: Quick Scratchpad, Volume & Media Control, Screen Dimmer, Disk Cleaner, Live Clock, Pomodoro Timer, Color Picker, and Text Case Converter. Each tool launches in its own independent window.

v4.5  —  Folder Launcher tab added. Register any number of folder paths with optional global hotkeys. Includes a Browse button, label field, inline Open button, Toggle ON/OFF, and conflict detection against all existing hotkeys. Folder status automatically shows OK or Missing based on disk availability.

v4.4  —  VAT and Discount tab completely redesigned with a wider window layout (680px). GroupBox containers added throughout for visual clarity. Built-in live calculator with a full per-transaction breakdown. Discount hotkey with multi-line support. VAT Add and Deduct mode toggle using radio buttons. Quick-set discount buttons at 5%, 10%, 15%, and 20%. Live peso preview on all rate settings.

v4.3  —  Invoice, VAT, and Manager hotkeys are now fully configurable from within the application. Hotkey conflict detection was implemented. VAT rate is now stored independently per Profile.

v4.2  —  Multiple Profile support was introduced. The Custom Text Hotkey manager received enable and disable toggles and Move Up and Move Down reorder controls.

v4.1  —  Initial public release. Features included auto-invoice number generation with configurable prefix, suffix, and digit length, a VAT deductor hotkey, and system tray integration.
    )"
    mainGui.Add("Edit", "x27 y478 w592 h122 +ReadOnly +Wrap +VScroll -WantReturn", clTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    tabMenu.UseTab()

    ; --- BOTTOM BUTTONS ---
    mainGui.SetFont("Norm s10", "Segoe UI")
    btnSave   := mainGui.Add("Button", "x180 y590 w140 h35 Default", "💾 Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel := mainGui.Add("Button", "x340 y590 w140 h35", "✖ Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())

    mainGui.Show("w680 h640")

    
    ; GUI INTERNAL FUNCTIONS
    

    UpdatePreview(*) {
        dlen := (guiCtrl_DigitLen.Value == "" || Number(guiCtrl_DigitLen.Value) < 1)
            ? 7 : Number(guiCtrl_DigitLen.Value)
        temp := GenerateInvoice(guiCtrl_Prefix.Value, guiCtrl_Num.Value,
            guiCtrl_Suffix.Value, dlen)
        guiCtrl_PreviewText.Value := "Preview: " . temp
    }

    LoadProfileIntoGui(pName) {
        pSection := "Profile_" . pName
        guiCtrl_Prefix.Value   := IniRead("settings.ini", pSection, "Prefix",       "AAPI")
        guiCtrl_Num.Value      := IniRead("settings.ini", pSection, "LastNumber",   "0")
        guiCtrl_Suffix.Value   := IniRead("settings.ini", pSection, "Suffix",       "S")
        guiCtrl_DigitLen.Value := IniRead("settings.ini", pSection, "DigitLength",  "7")
        loadedRate    := Float(IniRead("settings.ini", pSection, "VatRate",      "12.0"))
        loadedDisc    := Float(IniRead("settings.ini", pSection, "DiscountRate", "0.0"))
        loadedVatMode := IniRead("settings.ini", pSection, "VatMode", "Deduct")
        guiCtrl_VatRate.Value  := Format("{:.2f}", loadedRate)
        guiCtrl_DiscRate.Value := Format("{:.2f}", loadedDisc)
        guiCtrl_VatModeValue   := loadedVatMode
        SetVatPresetFromRate(loadedRate)
        if (loadedVatMode == "Add") {
            rbAdd.Value := 1
        } else {
            rbDeduct.Value := 1
        }
        ddCalcMode.Value := (loadedVatMode == "Add") ? 2 : 1
        calcVatInput.Value  := Format("{:.2f}", loadedRate)
        calcDiscInput.Value := Format("{:.2f}", loadedDisc)
        guiCtrl_VatProfileLabel.Value := pName
        UpdatePreview()
        UpdateVatPreview()
        UpdateDiscPreview()
    }

    SwitchProfile(*) {
        global active_profile
        active_profile := ddProfile.Text
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")
        LoadProfileIntoGui(active_profile)
    }

    NewProfile(*) {
        global active_profile
        newName := InputBox("Enter a name for the new profile:", "Create New Profile", "w320 h120").Value
        if (newName == "" || newName == 0)
            return
        pList := GetProfileList()
        for p in pList {
            if (p == newName) {
                MsgBox("A profile named '" . newName . "' already exists. Please choose a different name.", "Duplicate Name", 48)
                return
            }
        }
        curRate := IsNumber(guiCtrl_VatRate.Value) ? guiCtrl_VatRate.Value : "12.00"
        curDisc := IsNumber(guiCtrl_DiscRate.Value) ? guiCtrl_DiscRate.Value : "0.00"
        SaveProfileSettings(newName, guiCtrl_Prefix.Value, 0, guiCtrl_Suffix.Value, 7, curRate, curDisc, guiCtrl_VatModeValue)
        newList := GetProfileList()
        ddProfile.Delete()
        for p in newList
            ddProfile.Add([p])
        for i, p in newList {
            if (p == newName) {
                ddProfile.Value := i
                break
            }
        }
        active_profile := newName
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")
        LoadProfileIntoGui(active_profile)
    }

    DeleteProfile(*) {
        global active_profile
        if (ddProfile.Text == "Default") {
            MsgBox("The Default profile cannot be deleted.", "Action Not Allowed", 48)
            return
        }
        pName := ddProfile.Text
        confirm := MsgBox("Are you sure you want to permanently delete the profile '" . pName . "'? This action cannot be undone.",
            "Confirm Deletion", "YesNo 48")
        if (confirm != "Yes")
            return
        try IniDelete("settings.ini", "Profile_" . pName)
        active_profile := "Default"
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")
        newList := GetProfileList()
        ddProfile.Delete()
        for p in newList
            ddProfile.Add([p])
        ddProfile.Value := 1
        LoadProfileIntoGui("Default")
    }

    ; --- Tab 2 functions ---

    SelectHotkey(CtrlObj, RowNumber) {
        if (RowNumber == 0)
            return
        rawKey    := CtrlObj.GetText(RowNumber, 2)
        storedTxt := CtrlObj.GetText(RowNumber, 3)
        parsed := ParseHKString(rawKey)
        SetModDD(ddModifier, parsed.modLabel)
        SetKeyDD(ddKey, parsed.keyStr)
        editTxt.Value := StrReplace(storedTxt, "\n", "`n")
    }

    CheckConflict(newKey, excludeRow := 0) {
        if (newKey == sysHK_Manager)
            return "'" . newKey . "' is already assigned to the Manager hotkey (Alt+F10) and cannot be reassigned."
        invKey := modSymMap[ddInvMod.Text] . ddInvKey.Text
        if (newKey == invKey)
            return "'" . newKey . "' is already assigned to the Invoice hotkey. Please choose a different key combination."
        vatKey := modSymMap[ddVatMod.Text] . ddVatKey.Text
        if (newKey == vatKey)
            return "'" . newKey . "' is already assigned to the VAT hotkey. Please choose a different key combination."
        discKey := modSymMap[ddDiscMod.Text] . ddDiscKey.Text
        if (newKey == discKey)
            return "'" . newKey . "' is already assigned to the Discount hotkey. Please choose a different key combination."
        Loop LV.GetCount() {
            if (A_Index == excludeRow)
                continue
            if (LV.GetText(A_Index, 2) == newKey)
                return "'" . newKey . "' is already in use by row #" . A_Index . " in the hotkey list. Each hotkey must be unique."
        }
        ; Also check folder launcher hotkeys
        Loop FL_LV.GetCount() {
            if (FL_LV.GetText(A_Index, 4) == newKey)
                return "'" . newKey . "' is already assigned to a Folder Launcher entry (row #" . A_Index . "). Each hotkey must be unique."
        }
        return ""
    }

    AddUpdateHotkey(*) {
        if (editTxt.Value == "") {
            MsgBox("Please enter the text you want this hotkey to output.", "Required Field", 48)
            return
        }
        newKey := modSymMap[ddModifier.Text] . ddKey.Text
        rowToUpdate := 0
        Loop LV.GetCount() {
            if (LV.GetText(A_Index, 2) == newKey) {
                rowToUpdate := A_Index
                break
            }
        }
        conflictMsg := CheckConflict(newKey, rowToUpdate)
        if (conflictMsg != "") {
            MsgBox("Hotkey Conflict Detected`n`n" . conflictMsg . "`n`nPlease select a different key combination before proceeding.", "Hotkey Conflict", 48)
            return
        }
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
            MsgBox("Please select a hotkey from the list before deleting.", "No Selection", 48)
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
            MsgBox("Please select a hotkey from the list before toggling.", "No Selection", 48)
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
                realTxt   := StrReplace(hkTxt, "\n", "`n")
                boundFunc := CreateHotkeyFunc(realTxt)
                Hotkey(rawKey, boundFunc, "On")
                global activeHotkeys
                activeHotkeys[rawKey] := boundFunc
            }
        }
    }

    MoveRowUp(*) {
        selectedRow := LV.GetNext()
        if (selectedRow <= 1) {
            if (selectedRow == 0)
                MsgBox("Please select a row from the list first.", "No Selection", 48)
            return
        }
        SwapListViewRows(selectedRow, selectedRow - 1)
    }

    MoveRowDown(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Please select a row from the list first.", "No Selection", 48)
            return
        }
        if (selectedRow >= LV.GetCount())
            return
        SwapListViewRows(selectedRow, selectedRow + 1)
    }

    SwapListViewRows(rowA, rowB) {
        statusA := LV.GetText(rowA, 1)
        keyA    := LV.GetText(rowA, 2)
        txtA    := LV.GetText(rowA, 3)
        statusB := LV.GetText(rowB, 1)
        keyB    := LV.GetText(rowB, 2)
        txtB    := LV.GetText(rowB, 3)
        LV.Modify(rowA, , statusB, keyB, txtB)
        LV.Modify(rowB, , statusA, keyA, txtA)
        LV.Modify(rowA, "-Select")
        LV.Modify(rowB, "+Select +Focus")
    }

    
    ; SAVE ALL SETTINGS
    
    SaveSettings(*) {
        global prefix, current_num, suffix, digit_length, vat_rate, discount_rate, vat_mode
        global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Discount
        global folderLauncherList

        dlen := Number(guiCtrl_DigitLen.Value)
        if (guiCtrl_DigitLen.Value == "" || dlen < 1) {
            MsgBox("Digit Length must be at least 1.", "Invalid Input", 48)
            return
        }
        if (guiCtrl_Num.Value == "") {
            MsgBox("The Next Number field cannot be left empty.", "Invalid Input", 48)
            return
        }

        rawVat := guiCtrl_VatRate.Value
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            MsgBox("VAT Rate must be a number between 0 and 100.", "Invalid Input", 48)
            return
        }

        rawDisc := guiCtrl_DiscRate.Value
        if (!IsNumber(rawDisc) || Number(rawDisc) < 0 || Number(rawDisc) > 100) {
            MsgBox("Discount Rate must be a number between 0 and 100.", "Invalid Input", 48)
            return
        }

        newInvKey  := modSymMap[ddInvMod.Text]  . ddInvKey.Text
        newVatKey  := modSymMap[ddVatMod.Text]  . ddVatKey.Text
        newDiscKey := modSymMap[ddDiscMod.Text] . ddDiscKey.Text
        managerKey := sysHK_Manager

        sysKeys := [newInvKey, newVatKey, newDiscKey, managerKey]
        sysLabels := ["Invoice", "VAT", "Discount", "Manager (Alt+F10)"]
        conflictFound := false
        conflictMsg2  := ""
        for ci, ck in sysKeys {
            for cj, cv in sysKeys {
                if (ci >= cj)
                    continue
                if (ck == cv) {
                    conflictMsg2 := "Hotkey Conflict Detected`n`nThe " . sysLabels[ci] . " hotkey and the " . sysLabels[cj] . " hotkey are both assigned to '" . ck . "'.`n`nEach hotkey must be unique. Please change one of them before saving."
                    conflictFound := true
                    break
                }
            }
            if (conflictFound)
                break
        }
        if (conflictFound) {
            MsgBox(conflictMsg2, "Conflict!", 48)
            return
        }

        Loop LV.GetCount() {
            lvKey := LV.GetText(A_Index, 2)
            for si, sk in sysKeys {
                if (lvKey == sk && sk != managerKey) {
                    MsgBox("Hotkey Conflict Detected`n`nThe " . sysLabels[si] . " hotkey '" . sk . "' is already assigned to a Custom Text Hotkey in row #" . A_Index . ".`n`nPlease resolve this conflict before saving.", "Hotkey Conflict", 48)
                    return
                }
            }
        }

        ; Check folder hotkeys vs system hotkeys
        Loop FL_LV.GetCount() {
            flHK := FL_LV.GetText(A_Index, 4)
            if (flHK == "")
                continue
            for si, sk in sysKeys {
                if (flHK == sk) {
                    MsgBox("Hotkey Conflict Detected`n`nThe " . sysLabels[si] . " hotkey '" . sk . "' is also assigned to a Folder Launcher entry (row #" . A_Index . "). Please resolve this conflict before saving.", "Hotkey Conflict", 48)
                    return
                }
            }
            Loop LV.GetCount() {
                if (LV.GetText(A_Index, 2) == flHK) {
                    MsgBox("Hotkey Conflict Detected`n`nA Folder Launcher entry uses hotkey '" . flHK . "' which is already assigned to Custom Text Hotkey row #" . A_Index . ". Please resolve this before saving.", "Hotkey Conflict", 48)
                    return
                }
            }
        }

        prefix        := guiCtrl_Prefix.Value
        current_num   := Number(guiCtrl_Num.Value)
        suffix        := guiCtrl_Suffix.Value
        digit_length  := dlen
        vat_rate      := Number(rawVat)
        discount_rate := Number(rawDisc)
        vat_mode      := guiCtrl_VatModeValue
        active_profile := ddProfile.Text
        sysHK_Invoice  := newInvKey
        sysHK_Vat      := newVatKey
        sysHK_Discount := newDiscKey

        IniWrite(active_profile,  "settings.ini", "Settings",      "ActiveProfile")
        IniWrite(sysHK_Invoice,   "settings.ini", "SystemHotkeys", "Invoice")
        IniWrite(sysHK_Vat,       "settings.ini", "SystemHotkeys", "Vat")
        IniWrite(sysHK_Discount,  "settings.ini", "SystemHotkeys", "Discount")
        IniWrite(sysHK_Manager,   "settings.ini", "SystemHotkeys", "Manager")
        SaveProfileSettings(active_profile, prefix, current_num, suffix, digit_length, vat_rate, discount_rate, vat_mode)

        try IniDelete("settings.ini", "Hotkeys")
        try IniDelete("settings.ini", "HotkeyState")
        hotkeyList := []
        Loop LV.GetCount() {
            hKey    := LV.GetText(A_Index, 2)
            hTxt    := LV.GetText(A_Index, 3)
            hState  := LV.GetText(A_Index, 1)
            isEnabled := (hState == "✅ ON")
            realTxt := StrReplace(hTxt, "\n", "`n")
            IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
            IniWrite(isEnabled ? "1" : "0", "settings.ini", "HotkeyState", hKey)
            hotkeyList.Push({key: hKey, txt: realTxt, enabled: isEnabled})
        }

        ; Save folder launcher entries
        try IniDelete("settings.ini", "FolderLauncher")
        folderLauncherList := []
        Loop FL_LV.GetCount() {
            flStatus  := FL_LV.GetText(A_Index, 1)
            flLabel   := FL_LV.GetText(A_Index, 2)
            flPath    := FL_LV.GetText(A_Index, 3)
            flHotkey  := FL_LV.GetText(A_Index, 4)
            isEnabled := !InStr(flStatus, "OFF")
            storedVal := flLabel . "|" . flPath . "|" . flHotkey . "|" . (isEnabled ? "1" : "0")
            IniWrite(storedVal, "settings.ini", "FolderLauncher", A_Index)
            folderLauncherList.Push({label: flLabel, path: flPath, hotkey: flHotkey, enabled: isEnabled})
        }

        RegisterSystemHotkeys()
        RegisterCustomHotkeys()
        RegisterFolderHotkeys()

        MsgBox("All settings have been saved successfully.`n`n"
            . "Invoice Hotkey : " . sysHK_Invoice . "`n"
            . "VAT Hotkey    : " . sysHK_Vat . "  (Mode: " . vat_mode . ", Rate: " . vat_rate . "%)`n"
            . "Disc. Hotkey  : " . sysHK_Discount . "  (Rate: " . discount_rate . "%)`n"
            . "Active Profile : " . active_profile . "`n"
            . "Folder Entries : " . folderLauncherList.Length,
            "Settings Saved", "64 T3")
        mainGui.Destroy()
    }
}


; MINI APPS LAUNCHER FUNCTIONS


; --- 1. SCRATCHPAD ---
LaunchScratchpad() {
    static scratchGui  := ""
    static scratchEdit := ""
    static saveFile    := A_ScriptDir . "\scratchpad.txt"

    if (IsObject(scratchGui)) {
        try {
            scratchGui.Show()
            return
        }
    }

    ; Load saved content from file
    savedContent := ""
    if (FileExist(saveFile)) {
        try savedContent := FileRead(saveFile, "UTF-8")
    }

    scratchGui := Gui("+AlwaysOnTop -MaximizeBox", "📝 Quick Scratchpad")
    scratchGui.SetFont("s10", "Segoe UI")

    ; Auto-save on close
    scratchGui.OnEvent("Close", SaveAndClose)
    SaveAndClose(*) {
        try FileDelete(saveFile)
        try FileAppend(scratchEdit.Value, saveFile, "UTF-8")
        scratchGui.Destroy()
    }

    scratchGui.Add("Text", "x8 y8 w300 h18 cGray", "Auto-saves when closed. Notes persist across restarts.")
    savedLabel := scratchGui.Add("Text", "x8 y8 w384 h18 cGray", "")  ; placeholder for status
    scratchEdit := scratchGui.Add("Edit", "x8 y28 w384 h280 +Multi +WantReturn +VScroll +Wrap", savedContent)

    btnCopy  := scratchGui.Add("Button", "x8   y316 w90 h28", "📋 Copy All")
    btnSave  := scratchGui.Add("Button", "x104 y316 w80 h28", "💾 Save ")
    btnClear := scratchGui.Add("Button", "x190 y316 w80 h28", "🗑 Clear")
    btnPin   := scratchGui.Add("Button", "x302 y316 w90 h28", "📌 Stay Top")

    btnCopy.OnEvent("Click", (*) => (A_Clipboard := scratchEdit.Value, ToolTip("Copied!"), SetTimer(() => ToolTip(), -1500)))
    btnSave.OnEvent("Click", SaveNote)
    btnClear.OnEvent("Click", (*) => scratchEdit.Value := "")
    btnPin.OnEvent("Click",   (*) => scratchGui.Opt("+AlwaysOnTop"))

    SaveNote(*) {
        try FileDelete(saveFile)
        try FileAppend(scratchEdit.Value, saveFile, "UTF-8")
        ToolTip("💾 Saved!")
        SetTimer(() => ToolTip(), -1500)
    }

    scratchGui.Show("w400 h352")
}

; --- 2. VOLUME & MEDIA CONTROL ---
LaunchVolumeControl() {
    static volGui := ""
    if (IsObject(volGui)) {
        try { volGui.Show()
            return
        }
    }

    volGui := Gui("-MaximizeBox +AlwaysOnTop", "🔊 Volume & Media Control")
    volGui.SetFont("s10", "Segoe UI")
    volGui.OnEvent("Close", (*) => volGui.Destroy())

    volGui.SetFont("bold s11", "Segoe UI")
    volGui.Add("Text", "x10 y10 w280 h22 c0x0055AA", "🔊 System Volume")
    volGui.SetFont("s9 Norm", "Segoe UI")

    volGui.Add("Text", "x10 y38 w50 h22 +0x200", "Volume:")
    volSlider := volGui.Add("Slider", "x65 y38 w200 h28 +Thick15 Range0-100", 50)
    volLabel  := volGui.Add("Text", "x270 y38 w40 h22", "50%")

    volSlider.OnEvent("Change", (*) => (
        SoundSetVolume(volSlider.Value),
        volLabel.Value := volSlider.Value . "%"
    ))

    ; Read current volume
    try {
        curVol := Round(SoundGetVolume())
        volSlider.Value := curVol
        volLabel.Value  := curVol . "%"
    }

    ; Mute toggle
    btnMute := volGui.Add("Button", "x10 y72 w90 h28", "🔇 Mute")
    btnMute.OnEvent("Click", (*) => (
        SoundSetMute(-1),
        ToolTip("Mute toggled"),
        SetTimer(() => ToolTip(), -1200)
    ))

    volGui.SetFont("bold s11", "Segoe UI")
    volGui.Add("Text", "x10 y112 w280 h22 c0x0055AA", "⏯ Media Playback")
    volGui.SetFont("s9 Norm", "Segoe UI")

    btnPrev := volGui.Add("Button", "x10  y138 w85 h32", "⏮ Prev")
    btnPlay := volGui.Add("Button", "x100 y138 w100 h32", "⏯ Play/Pause")
    btnNext := volGui.Add("Button", "x205 y138 w85 h32", "⏭ Next")

    btnPrev.OnEvent("Click", (*) => Send("{Media_Prev}"))
    btnPlay.OnEvent("Click", (*) => Send("{Media_Play_Pause}"))
    btnNext.OnEvent("Click", (*) => Send("{Media_Next}"))

    volGui.SetFont("bold s11", "Segoe UI")
    volGui.Add("Text", "x10 y182 w280 h22 c0x0055AA", "🔈 Quick Volume Presets")
    volGui.SetFont("s9 Norm", "Segoe UI")

    btn0   := volGui.Add("Button", "x10  y206 w60 h26", "0%")
    btn25  := volGui.Add("Button", "x75  y206 w60 h26", "25%")
    btn50  := volGui.Add("Button", "x140 y206 w60 h26", "50%")
    btn75  := volGui.Add("Button", "x205 y206 w60 h26", "75%")
    btn100 := volGui.Add("Button", "x270 y206 w60 h26", "100%")

    SetVol(v) {
        SoundSetVolume(v)
        volSlider.Value := v
        volLabel.Value  := v . "%"
    }
    btn0.OnEvent("Click",   (*) => SetVol(0))
    btn25.OnEvent("Click",  (*) => SetVol(25))
    btn50.OnEvent("Click",  (*) => SetVol(50))
    btn75.OnEvent("Click",  (*) => SetVol(75))
    btn100.OnEvent("Click", (*) => SetVol(100))

    volGui.Show("w340 h244")
}

; --- 3. SCREEN DIMMER ---
LaunchScreenDimmer() {
    static dimmerGui  := ""
    static overlayGui := ""
    static isDimmed   := false

    if (IsObject(dimmerGui)) {
        try { dimmerGui.Show()
            return
        }
    }

    dimmerGui := Gui("-MaximizeBox +AlwaysOnTop", "🌙 Screen Dimmer")
    dimmerGui.SetFont("s10", "Segoe UI")
    dimmerGui.OnEvent("Close", OnDimmerClose)
    OnDimmerClose(*) {
        if (overlayGui != "") {
            overlayGui.Destroy()
            overlayGui := ""
        }
        isDimmed := false
        dimmerGui.Destroy()
        dimmerGui := ""
    }

    ; Mode: 0 = Dark dim, 1 = Warm/Blue-light filter
    static filterMode := 0

    dimmerGui.SetFont("bold s11 c0x0055AA", "Segoe UI")
    dimmerGui.Add("Text", "x10 y10 w330 h22", "🌙 Screen Dimmer & Eye Protection")
    dimmerGui.SetFont("s9 Norm", "Segoe UI")
    dimmerGui.Add("Text", "x10 y34 w330 h18",
        "Reduce eye strain with a dark or warm-toned screen overlay.")

    ; Mode toggle buttons
    dimmerGui.SetFont("s9 Bold", "Segoe UI")
    dimmerGui.Add("Text", "x10 y60 w60 h20 +0x200", "Mode:")
    btnModeDark := dimmerGui.Add("Button", "x72  y57 w130 h24", "🌑 Dark Dim")
    btnModeWarm := dimmerGui.Add("Button", "x208 y57 w130 h24", "🟡 Warm / Blue Light")
    dimmerGui.SetFont("s9 Norm", "Segoe UI")

    ; Opacity slider
    dimmerGui.Add("Text", "x10 y92 w65 h22 +0x200", "Strength:")
    dimSlider := dimmerGui.Add("Slider", "x80 y92 w210 h26 +Thick15 Range5-90", 35)
    dimLabel  := dimmerGui.Add("Text", "x295 y92 w44 h22", "35%")

    dimSlider.OnEvent("Change", OnSliderChange)
    OnSliderChange(*) {
        dimLabel.Value := dimSlider.Value . "%"
        if (isDimmed)
            UpdateOverlay()
    }

    ; Action buttons
    btnToggleDim := dimmerGui.Add("Button", "x10 y128 w148 h30", "🌙 Enable")
    btnHide      := dimmerGui.Add("Button", "x164 y128 w174 h30", "🔽 Hide This Window")
    btnToggleDim.OnEvent("Click", ToggleDim)
    btnHide.OnEvent("Click",      (*) => dimmerGui.Hide())

    ; Mode button handlers
    btnModeDark.OnEvent("Click", (*) => SetMode(0))
    btnModeWarm.OnEvent("Click", (*) => SetMode(1))

    ; Warm tip
    tipCtrl := dimmerGui.Add("Text", "x10 y167 w330 h28 cGray",
        "🟡 Warm mode applies a soft amber tint to reduce blue light for comfortable night viewing.")

    SetMode(m) {
        filterMode := m
        if (m == 0) {
            btnModeDark.SetFont("bold")
            btnModeWarm.SetFont("Norm")
            tipCtrl.Value := "🌑 Dark mode dims the screen to reduce overall brightness."
        } else {
            btnModeDark.SetFont("Norm")
            btnModeWarm.SetFont("bold")
            tipCtrl.Value := "🟡 Warm mode applies a soft amber tint to reduce blue light for night viewing."
        }
        if (isDimmed)
            UpdateOverlay()
    }

    GetOverlayColor() {
        ; Dark mode: black overlay. Warm mode: amber/orange tint (#FF8C00 = warm amber)
        return (filterMode == 1) ? "C8741A" : "000000"
    }

    UpdateOverlay() {
        if (!IsObject(overlayGui))
            return
        overlayGui.BackColor := GetOverlayColor()
        WinSetTransparent(Round(dimSlider.Value * 2.55), overlayGui)
    }

    ToggleDim(*) {
        if (isDimmed) {
            if (IsObject(overlayGui))
                overlayGui.Destroy()
            overlayGui := ""
            isDimmed   := false
            btnToggleDim.Text := "🌙 Enable"
        } else {
            overlayGui := Gui("+E0x80000 -Caption +ToolWindow +AlwaysOnTop")
            overlayGui.BackColor := GetOverlayColor()
            overlayGui.Show("x0 y0 w" . A_ScreenWidth . " h" . A_ScreenHeight . " NoActivate")
            WinSetTransparent(Round(dimSlider.Value * 2.55), overlayGui)
            WinSetExStyle("+0x20", overlayGui)   ; click-through
            isDimmed := true
            btnToggleDim.Text := "☀ Disable"
        }
    }

    ; Default: highlight dark mode button
    btnModeDark.SetFont("bold")
    dimmerGui.Show("w348 h202")
}

; --- 4. DISK CLEANER ---
LaunchDiskCleaner() {
    static cleanGui := ""
    if (IsObject(cleanGui)) {
        try { cleanGui.Show()
            return
        }
    }

    cleanGui := Gui("-MaximizeBox +AlwaysOnTop", "🗑 Disk Cleaner")
    cleanGui.SetFont("s10", "Segoe UI")
    cleanGui.OnEvent("Close", (*) => cleanGui.Destroy())

    cleanGui.SetFont("bold s11 c0x0055AA", "Segoe UI")
    cleanGui.Add("Text", "x10 y10 w360 h22", "🗑 Recycle Bin & Temp Folder Cleaner")
    cleanGui.SetFont("s9 Norm", "Segoe UI")
    cleanGui.Add("Text", "x10 y36 w360 h30",
        "Free up disk space by emptying the Recycle Bin and clearing the Windows Temp folder.")

    cbRecycle := cleanGui.Add("CheckBox", "x10 y72 w200 h22 +Checked", "Empty Recycle Bin")
    cbTemp    := cleanGui.Add("CheckBox", "x10 y98 w200 h22 +Checked", "Clear Temp Folder (%TEMP%)")
    cbPrefetch := cleanGui.Add("CheckBox", "x10 y124 w200 h22", "Clear Prefetch (Admin required)")

    resultTxt := cleanGui.Add("Edit", "x10 y156 w360 h80 +ReadOnly +Wrap +VScroll", "Results will appear here...")

    btnClean := cleanGui.Add("Button", "x10 y244 w170 h32", "🚀 Run Cleanup Now")
    btnClose := cleanGui.Add("Button", "x190 y244 w120 h32", "✖ Close")
    btnClose.OnEvent("Click", (*) => cleanGui.Destroy())

    btnClean.OnEvent("Click", DoClean)

    DoClean(*) {
        log := ""
        if (cbRecycle.Value) {
            try {
                FileRecycleEmpty()
                log .= "✅ Recycle Bin emptied.`n"
            } catch as e {
                log .= "⚠ Recycle Bin: " . e.Message . "`n"
            }
        }
        if (cbTemp.Value) {
            tempPath := EnvGet("TEMP")
            deleted := 0
            Loop Files, tempPath . "\*.*", "FR" {
                try {
                    FileDelete(A_LoopFilePath)
                    deleted++
                } catch {
                }
            }
            log .= "✅ Temp folder: " . deleted . " file(s) removed.`n"
        }
        if (cbPrefetch.Value) {
            try {
                RunWait('cmd.exe /c del /Q /F "C:\Windows\Prefetch\*.*"',, "Hide")
                log .= "✅ Prefetch cleared.`n"
            } catch {
                log .= "⚠ Prefetch: Admin privileges required.`n"
            }
        }
        resultTxt.Value := log != "" ? log : "Nothing selected to clean."
    }

    cleanGui.Show("w384 h288")
}

; --- 5. LIVE CLOCK ---
LaunchLiveClock() {
    static clockGui   := ""
    static clockTimer := ""
    static showDate   := true

    if (IsObject(clockGui)) {
        try { clockGui.Show()
            return
        }
    }

    clockGui := Gui("-MaximizeBox +AlwaysOnTop", "🕐 Live Clock")
    clockGui.SetFont("s10", "Segoe UI")
    clockGui.BackColor := "1a1a2e"
    clockGui.OnEvent("Close", OnClockClose)
    OnClockClose(*) {
        SetTimer(UpdateClock, 0)
        clockGui.Destroy()
        clockGui := ""
    }

    ; Time display
    clockGui.SetFont("bold s34 c00d4ff", "Segoe UI")
    timeCtrl := clockGui.Add("Text", "x10 y14 w260 h52 Center", "00:00:00")

    ; Date display
    clockGui.SetFont("s10 c88c0d0", "Segoe UI")
    dateCtrl := clockGui.Add("Text", "x10 y66 w260 h20 Center", "")

    ; Click anywhere on clock to toggle date
    clockGui.Add("Text", "x0 y94 w280 h16 Center c334455", "[ click to toggle date ]")
    clickZone := clockGui.Add("Text", "x0 y0 w280 h112 +BackgroundTrans")
    clickZone.OnEvent("Click", ToggleDate)

    ToggleDate(*) {
        showDate := !showDate
        dateCtrl.Visible := showDate
    }

    UpdateClock() {
        try {
            timeCtrl.Value := FormatTime(, "HH:mm:ss")
            dateCtrl.Value := FormatTime(, "dddd, MMMM d, yyyy")
        }
    }

    SetTimer(UpdateClock, 1000)
    UpdateClock()
    clockGui.Show("w280 h116")
}

; --- 6. POMODORO TIMER ---
LaunchPomodoro() {
    static pomoGui    := ""
    static pomoTimer  := ""
    static pomoSecs   := 0
    static pomoRunning := false
    static pomoMode   := "Work"

    if (IsObject(pomoGui)) {
        try { pomoGui.Show()
            return
        }
    }

    pomoGui := Gui("-MaximizeBox +AlwaysOnTop", "🍅 Pomodoro Timer")
    pomoGui.SetFont("s10", "Segoe UI")
    pomoGui.OnEvent("Close", (*) => (SetTimer(TickPomo, 0), pomoGui.Destroy()))

    pomoGui.SetFont("bold s11 c0x0055AA", "Segoe UI")
    pomoGui.Add("Text", "x10 y10 w340 h22", "🍅 Pomodoro / Focus Timer")
    pomoGui.SetFont("s9 Norm", "Segoe UI")

    ; Settings row
    pomoGui.Add("Text", "x10 y38 w70 h22 +0x200", "Work (min):")
    editWork := pomoGui.Add("Edit", "x85 y36 w45 h24 Number", "25")
    pomoGui.Add("Text", "x138 y38 w70 h22 +0x200", "Break (min):")
    editBreak := pomoGui.Add("Edit", "x213 y36 w45 h24 Number", "5")

    ; Big timer display
    pomoGui.SetFont("bold s38 c0x005500", "Segoe UI")
    timerDisp := pomoGui.Add("Text", "x0 y68 w360 h60 Center", "25:00")
    pomoGui.SetFont("bold s11 c0x888888", "Segoe UI")
    modeDisp  := pomoGui.Add("Text", "x0 y128 w360 h22 Center", "— WORK SESSION —")
    pomoGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; Buttons
    btnStart  := pomoGui.Add("Button", "x10  y158 w100 h32", "▶ Start")
    btnPause  := pomoGui.Add("Button", "x116 y158 w100 h32", "⏸ Pause")
    btnReset  := pomoGui.Add("Button", "x222 y158 w100 h32", "↩ Reset")
    btnPause.Enabled := false

    ; Session counter
    pomoGui.SetFont("s9 cGray", "Segoe UI")
    sessionCtrl := pomoGui.Add("Text", "x10 y196 w340 h18 Center", "Sessions completed: 0")
    pomoGui.SetFont("s10 Norm cDefault", "Segoe UI")
    sessionCount := 0

    UpdateTimerDisp() {
        mins := pomoSecs // 60
        secs := Mod(pomoSecs, 60)
        timerDisp.Value := Format("{:02}:{:02}", mins, secs)
    }

    TickPomo() {
        pomoSecs--
        if (pomoSecs < 0) {
            ; Session complete
            SoundBeep(880, 400)
            SoundBeep(1100, 600)
            if (pomoMode == "Work") {
                sessionCount++
                sessionCtrl.Value := "Sessions completed: " . sessionCount
                pomoMode  := "Break"
                pomoSecs  := Integer(editBreak.Value) * 60
                timerDisp.SetFont("cMaroon")
                modeDisp.Value := "— BREAK TIME 🌿 —"
            } else {
                pomoMode  := "Work"
                pomoSecs  := Integer(editWork.Value) * 60
                timerDisp.SetFont("c0x005500")
                modeDisp.Value := "— WORK SESSION —"
            }
            ToolTip(pomoMode == "Break" ? "🍅 Work session done! Take a break." : "🌿 Break over! Back to work.")
            SetTimer(() => ToolTip(), -3000)
        }
        UpdateTimerDisp()
    }

    OnStartClick(*) {
        if (!pomoRunning) {
            pomoSecs    := Integer(editWork.Value) * 60
            pomoMode    := "Work"
            modeDisp.Value := "— WORK SESSION —"
            timerDisp.SetFont("c0x005500")
        }
        SetTimer(TickPomo, 1000)
        pomoRunning      := true
        btnStart.Enabled  := false
        btnPause.Enabled  := true
        UpdateTimerDisp()
    }

    OnPauseClick(*) {
        SetTimer(TickPomo, 0)
        pomoRunning       := false
        btnStart.Enabled  := true
        btnPause.Enabled  := false
    }

    OnResetClick(*) {
        SetTimer(TickPomo, 0)
        pomoRunning       := false
        pomoMode          := "Work"
        pomoSecs          := Integer(editWork.Value) * 60
        modeDisp.Value    := "— WORK SESSION —"
        timerDisp.SetFont("c0x005500")
        btnStart.Enabled  := true
        btnPause.Enabled  := false
        UpdateTimerDisp()
    }

    btnStart.OnEvent("Click", OnStartClick)
    btnPause.OnEvent("Click", OnPauseClick)
    btnReset.OnEvent("Click", OnResetClick)

    pomoSecs := Integer(editWork.Value) * 60
    UpdateTimerDisp()
    pomoGui.Show("w360 h222")
}

; --- 7. COLOR PICKER ---
LaunchColorPicker() {
    static cpGui := ""
    if (IsObject(cpGui)) {
        try { cpGui.Show()
            return
        }
    }

    cpGui := Gui("-MaximizeBox +AlwaysOnTop", "🎨 Color Picker")
    cpGui.SetFont("s10", "Segoe UI")
    cpGui.OnEvent("Close", OnCpClose)
    OnCpClose(*) {
        SetTimer(TrackMouse, 0)
        cpGui.Destroy()
        cpGui := ""
    }

    cpGui.SetFont("bold s11 c0x0055AA", "Segoe UI")
    cpGui.Add("Text", "x10 y10 w340 h22", "🎨 Real-Time Color Picker")
    cpGui.SetFont("s9 Norm", "Segoe UI")
    cpGui.Add("Text", "x10 y32 w340 h18",
        "Move mouse anywhere — color updates live. Click Lock to freeze.")

    ; Big live preview box
    colorBox := cpGui.Add("Progress", "x10 y56 w90 h70 Background000000")

    ; Live readouts
    cpGui.SetFont("s9 Norm", "Segoe UI")
    cpGui.Add("Text", "x108 y58 w32 h20 +0x200", "HEX:")
    hexCtrl := cpGui.Add("Edit", "x142 y56 w130 h22 +ReadOnly", "#000000")
    cpGui.Add("Text", "x108 y84 w32 h20 +0x200", "RGB:")
    rgbCtrl := cpGui.Add("Edit", "x142 y82 w130 h22 +ReadOnly", "0, 0, 0")
    cpGui.Add("Text", "x108 y110 w32 h20 +0x200", "Pos:")
    posCtrl := cpGui.Add("Edit", "x142 y108 w130 h22 +ReadOnly", "X: 0  Y: 0")

    ; Buttons
    isLocked := false
    btnLock    := cpGui.Add("Button", "x10  y138 w90  h28", "🔒 Lock")
    btnCopyHex := cpGui.Add("Button", "x106 y138 w118 h28", "📋 Copy HEX")
    btnCopyRgb := cpGui.Add("Button", "x230 y138 w118 h28", "📋 Copy RGB")

    cpGui.SetFont("s8 cGray Italic", "Segoe UI")
    cpGui.Add("Text", "x10 y174 w340 h16",
        "Updates every 100ms. Lock freezes the current color for copying.")

    btnLock.OnEvent("Click", ToggleLock)
    btnCopyHex.OnEvent("Click", (*) => (A_Clipboard := hexCtrl.Value, ToolTip("HEX copied!"), SetTimer(() => ToolTip(), -1500)))
    btnCopyRgb.OnEvent("Click", (*) => (A_Clipboard := rgbCtrl.Value, ToolTip("RGB copied!"), SetTimer(() => ToolTip(), -1500)))

    ToggleLock(*) {
        isLocked := !isLocked
        btnLock.Text := isLocked ? "🔓 Unlock" : "🔒 Lock"
    }

    TrackMouse() {
        if (isLocked)
            return
        mx := 0, my := 0
        MouseGetPos(&mx, &my)
        try {
            clr := PixelGetColor(mx, my, "RGB")
        } catch {
            return
        }
        r := (clr >> 16) & 0xFF
        g := (clr >>  8) & 0xFF
        b :=  clr        & 0xFF
        hexCtrl.Value := Format("#{:02X}{:02X}{:02X}", r, g, b)
        rgbCtrl.Value := r . ", " . g . ", " . b
        posCtrl.Value := "X: " . mx . "  Y: " . my
        colorBox.Opt("Background" . Format("{:06X}", clr))
    }

    SetTimer(TrackMouse, 100)
    cpGui.Show("w358 h198")
}

; --- 8. TEXT CASE CONVERTER ---
LaunchCaseConverter() {
    static caseGui := ""
    if (IsObject(caseGui)) {
        try { caseGui.Show()
            return
        }
    }

    caseGui := Gui("-MaximizeBox +AlwaysOnTop", "🔡 Text Case Converter")
    caseGui.SetFont("s10", "Segoe UI")
    caseGui.OnEvent("Close", (*) => caseGui.Destroy())

    caseGui.SetFont("bold s11 c0x0055AA", "Segoe UI")
    caseGui.Add("Text", "x10 y10 w400 h22", "🔡 Text Case Converter")
    caseGui.SetFont("s9 Norm", "Segoe UI")
    caseGui.Add("Text", "x10 y34 w400 h18", "Paste your text below, choose a conversion, and copy the result.")

    caseGui.Add("Text", "x10 y58 w80 h18", "Input Text:")
    inputEdit := caseGui.Add("Edit", "x10 y76 w400 h100 +Multi +WantReturn +VScroll +Wrap")

    caseGui.Add("Text", "x10 y184 w80 h18", "Output Text:")
    outputEdit := caseGui.Add("Edit", "x10 y202 w400 h100 +Multi +ReadOnly +VScroll +Wrap")

    ; Conversion buttons
    btnUpper  := caseGui.Add("Button", "x10  y310 w90 h28", "⬆ UPPER")
    btnLower  := caseGui.Add("Button", "x106 y310 w90 h28", "⬇ lower")
    btnTitle  := caseGui.Add("Button", "x202 y310 w90 h28", "📖 Title")
    btnSent   := caseGui.Add("Button", "x298 y310 w90 h28", "💬 Sentence")
    btnCopyOut := caseGui.Add("Button", "x10  y346 w120 h28", "📋 Copy Output")
    btnPasteIn := caseGui.Add("Button", "x136 y346 w120 h28", "📋 Paste as Input")
    btnSwap    := caseGui.Add("Button", "x262 y346 w80 h28", "⇅ Swap")
    btnClearAll := caseGui.Add("Button", "x348 y346 w62 h28", "🗑 Clear")

    ToTitleCase(txt) {
        result := ""
        cap := true
        Loop Parse, txt {
            ch := A_LoopField
            if (ch == " " || ch == "`n" || ch == "`t" || ch == "." || ch == "!" || ch == "?") {
                result .= ch
                cap := true
            } else if (cap) {
                result .= StrUpper(ch)
                cap := false
            } else {
                result .= StrLower(ch)
            }
        }
        return result
    }

    ToSentenceCase(txt) {
        result := ""
        cap := true
        Loop Parse, txt {
            ch := A_LoopField
            if (ch == "." || ch == "!" || ch == "?") {
                result .= ch
                cap := true
            } else if (ch == " " || ch == "`n" || ch == "`t") {
                result .= ch
            } else if (cap) {
                result .= StrUpper(ch)
                cap := false
            } else {
                result .= StrLower(ch)
            }
        }
        return result
    }

    btnUpper.OnEvent("Click",   (*) => (outputEdit.Value := StrUpper(inputEdit.Value)))
    btnLower.OnEvent("Click",   (*) => (outputEdit.Value := StrLower(inputEdit.Value)))
    btnTitle.OnEvent("Click",   (*) => (outputEdit.Value := ToTitleCase(inputEdit.Value)))
    btnSent.OnEvent("Click",    (*) => (outputEdit.Value := ToSentenceCase(inputEdit.Value)))
    btnCopyOut.OnEvent("Click", (*) => (A_Clipboard := outputEdit.Value, ToolTip("Output copied!"), SetTimer(() => ToolTip(), -1500)))
    btnPasteIn.OnEvent("Click", (*) => (inputEdit.Value := A_Clipboard))
    btnSwap.OnEvent("Click",    (*) => (tmp := inputEdit.Value, inputEdit.Value := outputEdit.Value, outputEdit.Value := tmp))
    btnClearAll.OnEvent("Click",(*) => (inputEdit.Value := "", outputEdit.Value := ""))

    caseGui.Show("w424 h384")
}
