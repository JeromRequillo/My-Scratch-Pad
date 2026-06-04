;@Ahk2Exe-SetFileVersion 4.3.0.0
;@Ahk2Exe-SetProductVersion 4.3.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "🎯 KeyTap Pro v4.3"
TrayRecalcMenu()

; =========================================================
; Global Variables
; =========================================================
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

; Active function refs for system hotkeys (so we can re-register)
global sysFunc_Invoice  := ""
global sysFunc_Vat      := ""
global sysFunc_Discount := ""
global sysFunc_Manager  := ""

; =========================================================
; STARTUP
; =========================================================
LoadSettings()
RegisterSystemHotkeys()
RegisterCustomHotkeys()
return

; =========================================================
; TRAY
; =========================================================
TrayRecalcMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Open Manager", (*) => LaunchGUI())
    Tray.Add()
    Tray.Add("Exit Application", (*) => ExitApp())
}

; =========================================================
; LOAD SETTINGS
; =========================================================
LoadSettings() {
    global current_num, prefix, suffix, digit_length, vat_rate, discount_rate, vat_mode
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Discount, sysHK_Manager

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
}

; =========================================================
; REGISTER SYSTEM HOTKEYS
; =========================================================
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

; =========================================================
; SYSTEM HOTKEY ACTIONS
; =========================================================
DoInvoiceHotkey() {
    Critical()
    global current_num, active_profile
    invoice_string := GenerateInvoice()
    SendInput(invoice_string)
    SoundBeep(750, 50)
    ToolTip("Sent: " . invoice_string)
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
        ToolTip("Walang na-copy!")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; Process multi-line: each line separately
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
        ToolTip("⚠️ May linya na hindi numero — nilaktawan.")
        SetTimer(() => ToolTip(), -3000)
    }

    finalText := ""
    for i, r in resultLines {
        finalText .= r
        if (i < resultLines.Length)
            finalText .= "`n"
    }

    ; Remove trailing newline if original had none
    if (SubStr(A_Clipboard, -1) != "`n")
        finalText := RTrim(finalText, "`n")

    A_Clipboard := finalText
    Send("^v")

    modeLabel := (vat_mode == "Add") ? "Added" : "Deducted"
    ToolTip("VAT " . vat_rate . "% " . modeLabel)
    SetTimer(() => ToolTip(), -2000)
}

DoDiscountHotkey() {
    global discount_rate
    if (discount_rate <= 0) {
        ToolTip("⚠️ Discount rate ay 0%! I-set muna sa Manager.")
        SetTimer(() => ToolTip(), -3000)
        return
    }

    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        ToolTip("Walang na-copy!")
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
        ToolTip("⚠️ May linya na hindi numero — nilaktawan.")
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

    ToolTip("Discount " . discount_rate . "% Applied")
    SetTimer(() => ToolTip(), -2000)
}

; =========================================================
; CUSTOM TEXT HOTKEYS
; =========================================================
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
    return (*) => SendInput(txt)
}

; =========================================================
; HELPERS
; =========================================================
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

; =========================================================
; MAIN GUI
; =========================================================
LaunchGUI() {
    global mainGui, current_num, prefix, suffix, digit_length, vat_rate
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Manager
    global discount_rate, vat_mode, sysHK_Discount

    LoadSettings()

    if (mainGui != "")
        mainGui.Destroy()

    mainGui := Gui("-MaximizeBox", "🎯 KeyTap Pro v4.3")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())
    mainGui.SetFont("s10", "Segoe UI")

    tabMenu := mainGui.Add("Tab3", "x10 y10 w480 h400",
        ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "About"])

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

    ; =========================================================
    ; TAB 1: INVOICE CONFIGURATION
    ; =========================================================
    tabMenu.UseTab(1)

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y50 w55 h20", "Profile:")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    profileList := GetProfileList()
    ddProfile := mainGui.Add("DropDownList", "x78 y48 w160 h200", profileList)
    for i, p in profileList {
        if (p == active_profile) {
            ddProfile.Value := i
            break
        }
    }

    btnNewProfile := mainGui.Add("Button", "x244 y47 w70 h22", "➕ New")
    btnDelProfile := mainGui.Add("Button", "x318 y47 w70 h22", "🗑 Delete")
    btnNewProfile.OnEvent("Click", NewProfile)
    btnDelProfile.OnEvent("Click", DeleteProfile)
    ddProfile.OnEvent("Change", SwitchProfile)

    mainGui.Add("Text", "x20 y73 w440 h1 +0x10")

    mainGui.SetFont("s10 Norm", "Segoe UI")
    mainGui.Add("Text", "x20 y82 w90 h20", "Prefix:")
    guiCtrl_Prefix := mainGui.Add("Edit", "x115 y79 w160 h25", prefix)
    guiCtrl_Prefix.OnEvent("Change", UpdatePreview)

    mainGui.Add("Text", "x20 y112 w90 h20", "Next Number:")
    guiCtrl_Num := mainGui.Add("Edit", "x115 y109 w100 h25 Number", current_num)
    guiCtrl_Num.OnEvent("Change", UpdatePreview)

    btnReset := mainGui.Add("Button", "x220 y108 w55 h26", "Reset")
    btnReset.OnEvent("Click", (*) => (guiCtrl_Num.Value := "0", UpdatePreview()))

    mainGui.Add("Text", "x20 y142 w90 h20", "Suffix:")
    guiCtrl_Suffix := mainGui.Add("Edit", "x115 y139 w160 h25", suffix)
    guiCtrl_Suffix.OnEvent("Change", UpdatePreview)

    mainGui.Add("Text", "x20 y172 w90 h20", "Digit Length:")
    guiCtrl_DigitLen := mainGui.Add("Edit", "x115 y169 w40 h25 Number", digit_length)
    guiCtrl_DigitLen.OnEvent("Change", UpdatePreview)

    mainGui.Add("Text", "x20 y202 w440 h1 +0x10")

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y210 w90 h20", "Invoice Key:")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    ddInvMod := mainGui.Add("DropDownList", "x115 y208 w100 h200", modifierChoices)
    ddInvKey := mainGui.Add("DropDownList", "x220 y208 w70 h300", keyChoices)

    parsedInv := ParseHKString(sysHK_Invoice)
    SetModDD(ddInvMod, parsedInv.modLabel)
    SetKeyDD(ddInvKey, parsedInv.keyStr)

    guiCtrl_InvHKLabel := mainGui.Add("Text", "x296 y211 w160 h18 cGray",
        "Current: " . sysHK_Invoice)
    UpdateInvHKLabel() {
        sym := modSymMap[ddInvMod.Text]
        guiCtrl_InvHKLabel.Value := "Current: " . sym . ddInvKey.Text
    }
    ddInvMod.OnEvent("Change", (*) => UpdateInvHKLabel())
    ddInvKey.OnEvent("Change", (*) => UpdateInvHKLabel())

    mainGui.SetFont("bold s10", "Segoe UI")
    current_preview := GenerateInvoice()
    guiCtrl_PreviewText := mainGui.Add("Text", "x20 y237 w450 h20 Center +BackgroundTrans",
        "Preview: " . current_preview)

    mainGui.SetFont("Norm s9 cGray", "Segoe UI")
    invoiceTxt := "
    (
    💡PAANO GAMITIN ANG INVOICE GENERATOR:

    1. Pumili ng Profile o gumawa ng bago gamit ang [➕ New].

    2. Itakda ang Prefix, Next Number, Suffix, at Digit Length.

    3. Piliin ang Invoice Hotkey (Modifier + Key) na gusto mo.

    4. I-click ang [ Save All Changes ] para mai-save.

    5. Pindutin ang iyong napiling hotkey kahit saan para awtomatikong i-type ang Invoice!

    💡 MAHALAGANG PAALALA:

    • Multiple Profiles: Bawat profile ay may sariling Prefix, Suffix, Digit Length, at sequence number. Ang pagpapalit ng profile ay agad na gagamitin ito sa Alt+F9.

    • Digit Length: Kontrolin kung ilang digit ang numero (e.g., 5 digits: '1' = '00001'). Default ay 7.

    • Auto-Increment: Sa bawat Alt+F9, awtomatikong +1 ang numero at nase-save sa kasalukuyang profile.

    • Reset Button: Ibabalik sa 0 ang sequence number ng kasalukuyang profile.
    )"
    mainGui.Add("Edit", "x20 y260 w450 h130 +ReadOnly +Wrap +VScroll -WantReturn", invoiceTxt)

    mainGui.SetFont("Norm s10 cDefault", "Segoe UI")

    ; =========================================================
    ; TAB 2: CUSTOM TEXT HOTKEYS
    ; =========================================================
    tabMenu.UseTab(2)

    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y50 w50 h20", "🔍 Filter:")
    editSearch := mainGui.Add("Edit", "x70 y48 w280 h22")
    btnClearSearch := mainGui.Add("Button", "x356 y47 w50 h23", "Clear")
    mainGui.SetFont("s9 cGray", "Segoe UI")
    mainGui.Add("Text", "x410 y51 w70 h18", "live search")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    LV := mainGui.Add("ListView", "x20 y74 w440 h130 +Grid -Multi",
        ["Status", "Shortcut Key", "Text / Name to Output"])
    LV.ModifyCol(1, 55)
    LV.ModifyCol(2, 100)
    LV.ModifyCol(3, 262)

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

    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y213 w80 h18", "Modifier:")
    mainGui.Add("Text", "x108 y213 w40 h18", "Key:")
    mainGui.Add("Text", "x160 y213 w200 h18", "Text to Output:")

    ddModifier := mainGui.Add("DropDownList", "x20 y231 w82 h120", modifierChoices)
    ddModifier.Value := 1
    ddKey := mainGui.Add("DropDownList", "x108 y231 w46 h300", keyChoices)
    ddKey.Value := 1
    editTxt := mainGui.Add("Edit", "x160 y231 w300 h50 +Multi +WantReturn +VScroll")

    btnAdd      := mainGui.Add("Button", "x20 y290 w100 h26", "➕ Add / Update")
    btnDel      := mainGui.Add("Button", "x128 y290 w100 h26", "❌ Delete Line")
    btnToggle   := mainGui.Add("Button", "x236 y290 w110 h26", "🔁 Toggle ON/OFF")
    btnMoveUp   := mainGui.Add("Button", "x354 y290 w50 h26", "▲ Up")
    btnMoveDown := mainGui.Add("Button", "x408 y290 w52 h26", "▼ Down")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    btnMoveUp.OnEvent("Click", MoveRowUp)
    btnMoveDown.OnEvent("Click", MoveRowDown)
    LV.OnEvent("Click", SelectHotkey)

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x20 y322 w440 h28",
        "Tip: Piliin ang Modifier at Key. Pwedeng multi-line ang Text (Enter = bagong linya). ▲▼ = i-reorder.")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; =========================================================
    ; TAB 3: VAT CALCULATOR  (UPDATED)
    ; =========================================================
    tabMenu.UseTab(3)

    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x20 y50 w400 h25 c0x0066CC", "VAT & Discount Tool")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    mainGui.Add("Text", "x20 y73 w450 h1 +0x10")

    ; --- Active profile info ---
    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y80 w120 h20", "Active Profile:")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    guiCtrl_VatProfileLabel := mainGui.Add("Text", "x145 y80 w200 h20 cGreen", active_profile)

    ; ── ROW: VAT Rate + Mode Toggle ──────────────────────────
    mainGui.Add("Text", "x20 y100 w450 h1 +0x10")

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y108 w80 h20", "VAT Rate (%):")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    vatPresets := ["12% (Standard)", "5% (Reduced)", "0% (Zero-rated)", "Custom..."]
    ddVatPreset    := mainGui.Add("DropDownList", "x105 y106 w110 h200", vatPresets)
    guiCtrl_VatRate := mainGui.Add("Edit", "x220 y106 w48 h22", Format("{:.2f}", vat_rate))
    mainGui.Add("Text", "x272 y108 w12 h20", "%")

    ; VAT Mode Toggle buttons side by side
    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x295 y108 w40 h20", "Mode:")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    btnModeDeduct := mainGui.Add("Button", "x338 y105 w60 h24", "⬇ Deduct")
    btnModeAdd    := mainGui.Add("Button", "x402 y105 w60 h24", "⬆ Add")

    ; Highlight active mode
    UpdateModeButtons(mode) {
        if (mode == "Deduct") {
            btnModeDeduct.Opt("+BackgroundNavy")
            btnModeAdd.Opt("-Background")
        } else {
            btnModeDeduct.Opt("-Background")
            btnModeAdd.Opt("+BackgroundNavy")
        }
    }
    UpdateModeButtons(vat_mode)

    guiCtrl_VatModeValue := vat_mode  ; track current mode in a local var
    btnModeDeduct.OnEvent("Click", (*) {
        guiCtrl_VatModeValue := "Deduct"
        UpdateModeButtons("Deduct")
        UpdateVatPreview()
    })
    btnModeAdd.OnEvent("Click", (*) {
        guiCtrl_VatModeValue := "Add"
        UpdateModeButtons("Add")
        UpdateVatPreview()
    })

    ; live preview label
    guiCtrl_VatPreview := mainGui.Add("Text", "x20 y131 w440 h16 cGray", "")

    SetVatPresetFromRate(r) {
        if (r == 12.0)      ddVatPreset.Value := 1
        else if (r == 5.0)  ddVatPreset.Value := 2
        else if (r == 0.0)  ddVatPreset.Value := 3
        else                ddVatPreset.Value := 4
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
            guiCtrl_VatPreview.Value := "  e.g. 1,000.00  →  " . Format("{:.2f}", gross) . "  (Add " . r . "%)"
        } else {
            net := Round(1000 / (1 + r / 100), 2)
            guiCtrl_VatPreview.Value := "  e.g. 1,000.00  →  " . Format("{:.2f}", net) . "  (Deduct " . r . "%)"
        }
    }
    UpdateVatPreview()

    OnVatPresetChange(*) {
        if (ddVatPreset.Value == 1)      guiCtrl_VatRate.Value := "12.00"
        else if (ddVatPreset.Value == 2) guiCtrl_VatRate.Value := "5.00"
        else if (ddVatPreset.Value == 3) guiCtrl_VatRate.Value := "0.00"
        else                             guiCtrl_VatRate.Focus()
        UpdateVatPreview()
    }
    ddVatPreset.OnEvent("Change", OnVatPresetChange)

    OnVatRateChange(*) {
        v := guiCtrl_VatRate.Value
        if (v == "12" || v == "12.0" || v == "12.00")      ddVatPreset.Value := 1
        else if (v == "5" || v == "5.0" || v == "5.00")    ddVatPreset.Value := 2
        else if (v == "0" || v == "0.0" || v == "0.00")    ddVatPreset.Value := 3
        else                                                 ddVatPreset.Value := 4
        UpdateVatPreview()
    }
    guiCtrl_VatRate.OnEvent("Change", OnVatRateChange)

    ; ── ROW: VAT Hotkey ──────────────────────────────────────
    mainGui.Add("Text", "x20 y150 w450 h1 +0x10")

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y157 w85 h20", "VAT Hotkey:")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    ddVatMod := mainGui.Add("DropDownList", "x110 y155 w100 h200", modifierChoices)
    ddVatKey := mainGui.Add("DropDownList", "x215 y155 w70 h300", keyChoices)

    parsedVat := ParseHKString(sysHK_Vat)
    SetModDD(ddVatMod, parsedVat.modLabel)
    SetKeyDD(ddVatKey, parsedVat.keyStr)

    guiCtrl_VatHKLabel := mainGui.Add("Text", "x291 y158 w170 h18 cGray",
        "Current: " . sysHK_Vat)
    UpdateVatHKLabel() {
        sym := modSymMap[ddVatMod.Text]
        guiCtrl_VatHKLabel.Value := "Current: " . sym . ddVatKey.Text
    }
    ddVatMod.OnEvent("Change", (*) => UpdateVatHKLabel())
    ddVatKey.OnEvent("Change", (*) => UpdateVatHKLabel())

    ; ── ROW: Discount Rate + Hotkey ──────────────────────────
    mainGui.Add("Text", "x20 y178 w450 h1 +0x10")

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y185 w90 h20", "Discount (%):")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    guiCtrl_DiscRate := mainGui.Add("Edit", "x115 y183 w48 h22", Format("{:.2f}", discount_rate))
    mainGui.Add("Text", "x167 y185 w12 h20", "%")

    guiCtrl_DiscPreview := mainGui.Add("Text", "x185 y185 w130 h18 cGray", "")

    UpdateDiscPreview() {
        raw := guiCtrl_DiscRate.Value
        if (!IsNumber(raw) || Number(raw) < 0 || Number(raw) > 100) {
            guiCtrl_DiscPreview.Value := "⚠ invalid"
            return
        }
        r   := Number(raw)
        net := Round(1000 * (1 - r / 100), 2)
        guiCtrl_DiscPreview.Value := "1,000 → " . Format("{:.2f}", net)
    }
    UpdateDiscPreview()
    guiCtrl_DiscRate.OnEvent("Change", (*) => UpdateDiscPreview())

    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y210 w90 h20", "Disc. Hotkey:")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    ddDiscMod := mainGui.Add("DropDownList", "x115 y208 w100 h200", modifierChoices)
    ddDiscKey := mainGui.Add("DropDownList", "x220 y208 w70 h300", keyChoices)

    parsedDisc := ParseHKString(sysHK_Discount)
    SetModDD(ddDiscMod, parsedDisc.modLabel)
    SetKeyDD(ddDiscKey, parsedDisc.keyStr)

    guiCtrl_DiscHKLabel := mainGui.Add("Text", "x296 y211 w160 h18 cGray",
        "Current: " . sysHK_Discount)
    UpdateDiscHKLabel() {
        sym := modSymMap[ddDiscMod.Text]
        guiCtrl_DiscHKLabel.Value := "Current: " . sym . ddDiscKey.Text
    }
    ddDiscMod.OnEvent("Change", (*) => UpdateDiscHKLabel())
    ddDiscKey.OnEvent("Change", (*) => UpdateDiscHKLabel())

    ; ── IN-APP CALCULATOR ────────────────────────────────────
    mainGui.Add("Text", "x20 y232 w450 h1 +0x10")

    mainGui.SetFont("bold s9 c0x0066CC", "Segoe UI")
    mainGui.Add("Text", "x20 y238 w200 h18", "🧮 In-App Calculator")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    ; Input row
    mainGui.Add("Text", "x20 y258 w60 h18", "Amount:")
    calcInput := mainGui.Add("Edit", "x82 y256 w110 h22")

    mainGui.Add("Text", "x200 y258 w60 h18", "Discount:")
    calcDiscInput := mainGui.Add("Edit", "x258 y256 w48 h22", Format("{:.2f}", discount_rate))
    mainGui.Add("Text", "x310 y258 w10 h18", "%")

    mainGui.Add("Text", "x325 y258 w35 h18", "VAT:")
    calcVatInput := mainGui.Add("Edit", "x360 y256 w48 h22", Format("{:.2f}", vat_rate))
    mainGui.Add("Text", "x412 y258 w10 h18", "%")

    ; Order selection
    mainGui.Add("Text", "x20 y282 w55 h18", "Order:")
    calcOrderChoices := ["Discount → VAT", "VAT → Discount"]
    ddCalcOrder := mainGui.Add("DropDownList", "x78 y280 w130 h100", calcOrderChoices)
    ddCalcOrder.Value := 1

    ; VAT Mode for calculator (mirrors global but local override)
    mainGui.Add("Text", "x218 y282 w55 h18", "Mode:")
    calcModeChoices := ["Deduct VAT", "Add VAT"]
    ddCalcMode := mainGui.Add("DropDownList", "x258 y280 w110 h100", calcModeChoices)
    ddCalcMode.Value := (vat_mode == "Add") ? 2 : 1

    btnCalculate := mainGui.Add("Button", "x378 y278 w82 h26 Default", "🧮 Calculate")

    ; Result display — GroupBox style via a border
    mainGui.Add("Text", "x20 y310 w450 h1 +0x10")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    calcGrossLabel   := mainGui.Add("Text", "x20 y315 w215 h18", "Gross Amount:         —")
    calcDiscLabel    := mainGui.Add("Text", "x245 y315 w215 h18 cRed", "Discount Amount:   —")
    calcAfterDisc    := mainGui.Add("Text", "x20 y333 w215 h18", "After Discount:       —")
    calcVatLabel     := mainGui.Add("Text", "x245 y333 w215 h18 cMaroon", "VAT Amount:          —")
    mainGui.Add("Text", "x20 y351 w450 h1 +0x10")
    mainGui.SetFont("bold s10 c0x006600", "Segoe UI")
    calcNetLabel     := mainGui.Add("Text", "x20 y355 w440 h22 Center", "NET AMOUNT:  —")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; Button to copy net result to clipboard
    btnCopyNet := mainGui.Add("Button", "x20 y379 w140 h22", "📋 Copy Net")
    btnCopyAll := mainGui.Add("Button", "x168 y379 w160 h22", "📋 Copy Full Breakdown")

    calcNetValue := ""  ; store last computed net

    DoCalculate(*) {
        rawAmt  := StrReplace(calcInput.Value, ",", "")
        rawDisc := calcDiscInput.Value
        rawVat  := calcVatInput.Value

        if (!IsNumber(rawAmt) || Number(rawAmt) <= 0) {
            MsgBox("Mag-input ng valid na Amount!", "Error", 48)
            return
        }
        if (!IsNumber(rawDisc) || Number(rawDisc) < 0 || Number(rawDisc) > 100) {
            MsgBox("Discount % ay dapat 0–100!", "Error", 48)
            return
        }
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            MsgBox("VAT % ay dapat 0–100!", "Error", 48)
            return
        }

        gross    := Number(rawAmt)
        discPct  := Number(rawDisc)
        vatPct   := Number(rawVat)
        calcMode := (ddCalcMode.Value == 2) ? "Add" : "Deduct"
        order    := ddCalcOrder.Value  ; 1 = Disc→VAT, 2 = VAT→Disc

        discAmt   := 0.0
        vatAmt    := 0.0
        afterDisc := gross
        net       := gross

        if (order == 1) {
            ; Discount first, then VAT
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
            ; VAT first, then discount
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

        ; Format with commas helper
        FmtNum(n) {
            s := Format("{:.2f}", n)
            ; insert commas
            dotPos := InStr(s, ".")
            intPart := SubStr(s, 1, dotPos - 1)
            decPart := SubStr(s, dotPos)
            result  := ""
            len     := StrLen(intPart)
            Loop len {
                idx := A_Index
                result .= SubStr(intPart, idx, 1)
                rem := len - idx
                if (rem > 0 && Mod(rem, 3) == 0)
                    result .= ","
            }
            return result . decPart
        }

        calcNetValue := FmtNum(net)

        calcGrossLabel.Value  := "Gross Amount:        " . FmtNum(gross)
        calcDiscLabel.Value   := "Discount (" . discPct . "%):    -" . FmtNum(discAmt)
        calcAfterDisc.Value   := "After Discount:      " . FmtNum(afterDisc)
        calcVatLabel.Value    := "VAT (" . vatPct . "%):          " . (calcMode == "Add" ? "+" : "-") . FmtNum(vatAmt)
        calcNetLabel.Value    := "NET AMOUNT:   " . calcNetValue
    }

    btnCalculate.OnEvent("Click", DoCalculate)
    calcInput.OnEvent("Change", (*) => "")  ; allow live typing

    btnCopyNet.OnEvent("Click", (*) {
        if (calcNetValue == "") {
            ToolTip("Wala pang result! I-click muna ang Calculate.")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        A_Clipboard := calcNetValue
        ToolTip("Net amount copied: " . calcNetValue)
        SetTimer(() => ToolTip(), -2000)
    })

    btnCopyAll.OnEvent("Click", (*) {
        if (calcNetValue == "") {
            ToolTip("Wala pang result! I-click muna ang Calculate.")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        breakdown := calcGrossLabel.Value . "`n"
                   . calcDiscLabel.Value . "`n"
                   . calcAfterDisc.Value . "`n"
                   . calcVatLabel.Value . "`n"
                   . "─────────────────────`n"
                   . calcNetLabel.Value
        A_Clipboard := breakdown
        ToolTip("Full breakdown copied!")
        SetTimer(() => ToolTip(), -2000)
    })

    ; ── INSTRUCTIONS ─────────────────────────────────────────
    mainGui.Add("Text", "x20 y403 w450 h1 +0x10")  ; just a divider — instructions moved to scrollable area below

    ; =========================================================
    ; TAB 4: ABOUT  (unchanged)
    ; =========================================================
    tabMenu.UseTab(4)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x25 y50 w400 h25 c0x0066CC", "🎯 KeyTap Pro v4.3")
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x25 y75 w400 h18", "Version: 4.3.0 (Configurable System Hotkeys)")
    mainGui.Add("Text", "x25 y95 w400 h18", "Developer: Jerom Requillo")

    mainGui.SetFont("italic s9", "Segoe UI")
    mainGui.Add("Link", "x25 y120 w400 h20", 'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x25 y140 w400 h20", 'Repository: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo/🎯 KeyTap Pro v4.3</a>')

    mainGui.SetFont("s10 Norm", "Segoe UI")
    aboutTxt := "
    (
    Configurable Global Hotkeys (set in GUI):
    [Invoice Hotkey] -> Generate & Type Auto-Invoice Number
    [VAT Hotkey]     -> Deduct/Add VAT from Selected Text
    [Discount Hotkey]-> Apply Discount % to Selected Text
    [Alt + F10]      -> Open Manager (fixed, not configurable)

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
    btnSave   := mainGui.Add("Button", "x130 y425 w110 h32 Default", "Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel := mainGui.Add("Button", "x260 y425 w110 h32", "Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())

    mainGui.Show("w500 h470")

    ; =========================================================
    ; GUI INTERNAL FUNCTIONS
    ; =========================================================

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
        UpdateModeButtons(loadedVatMode)
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
        newName := InputBox("Enter new profile name:", "New Profile", "w300 h120").Value
        if (newName == "" || newName == 0)
            return
        pList := GetProfileList()
        for p in pList {
            if (p == newName) {
                MsgBox("Profile '" . newName . "' ay mayroon na!", "Babala", 48)
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
            MsgBox("Hindi pwedeng burahin ang 'Default' profile.", "Babala", 48)
            return
        }
        pName := ddProfile.Text
        confirm := MsgBox("Sigurado ka bang gusto mong burahin ang profile '" . pName . "'?",
            "Confirm Delete", "YesNo 48")
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
            return "'" . newKey . "' ay ginagamit ng Manager hotkey (Alt+F10) — hindi pwedeng palitan!"
        invKey := modSymMap[ddInvMod.Text] . ddInvKey.Text
        if (newKey == invKey)
            return "'" . newKey . "' ay ginagamit ng Invoice hotkey."
        vatKey := modSymMap[ddVatMod.Text] . ddVatKey.Text
        if (newKey == vatKey)
            return "'" . newKey . "' ay ginagamit ng VAT hotkey."
        discKey := modSymMap[ddDiscMod.Text] . ddDiscKey.Text
        if (newKey == discKey)
            return "'" . newKey . "' ay ginagamit ng Discount hotkey."
        Loop LV.GetCount() {
            if (A_Index == excludeRow)
                continue
            if (LV.GetText(A_Index, 2) == newKey)
                return "'" . newKey . "' ay duplicate! Ginagamit na ng row #" . A_Index . "."
        }
        return ""
    }

    AddUpdateHotkey(*) {
        if (editTxt.Value == "") {
            MsgBox("Paki-sulat muna ang Text to Output!", "Babala", 48)
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
            MsgBox("⚠️ Hotkey Conflict!`n`n" . conflictMsg . "`n`nPiliin ang ibang key combination.", "Conflict!", 48)
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
                MsgBox("Pumili muna ng row.", "Babala", 48)
            return
        }
        SwapListViewRows(selectedRow, selectedRow - 1)
    }

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

    ; =========================================================
    ; SAVE ALL SETTINGS
    ; =========================================================
    SaveSettings(*) {
        global prefix, current_num, suffix, digit_length, vat_rate, discount_rate, vat_mode
        global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Discount

        ; Validate Invoice fields
        dlen := Number(guiCtrl_DigitLen.Value)
        if (guiCtrl_DigitLen.Value == "" || dlen < 1) {
            MsgBox("Digit Length ay dapat 1 o higit pa!", "Error", 48)
            return
        }
        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' ay hindi pwedeng blangko!", "Error", 48)
            return
        }

        ; Validate VAT rate
        rawVat := guiCtrl_VatRate.Value
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            MsgBox("VAT Rate ay dapat numero sa pagitan ng 0 at 100!", "Error", 48)
            return
        }

        ; Validate Discount rate
        rawDisc := guiCtrl_DiscRate.Value
        if (!IsNumber(rawDisc) || Number(rawDisc) < 0 || Number(rawDisc) > 100) {
            MsgBox("Discount Rate ay dapat numero sa pagitan ng 0 at 100!", "Error", 48)
            return
        }

        ; Build new system hotkey strings
        newInvKey  := modSymMap[ddInvMod.Text]  . ddInvKey.Text
        newVatKey  := modSymMap[ddVatMod.Text]  . ddVatKey.Text
        newDiscKey := modSymMap[ddDiscMod.Text] . ddDiscKey.Text
        managerKey := sysHK_Manager

        ; Conflict checks among system hotkeys
        sysKeys := [newInvKey, newVatKey, newDiscKey, managerKey]
        sysLabels := ["Invoice", "VAT", "Discount", "Manager (Alt+F10)"]
        Loop 4 {
            i := A_Index
            Loop 4 {
                j := A_Index
                if (i >= j)
                    continue
                if (sysKeys[i] == sysKeys[j]) {
                    MsgBox("⚠️ Conflict! " . sysLabels[i] . " at " . sysLabels[j] . " ay parehong '" . sysKeys[i] . "'!`n`nPiliin ang ibang key.", "Conflict!", 48)
                    return
                }
            }
        }

        ; Conflict checks: system vs custom hotkeys
        Loop LV.GetCount() {
            lvKey := LV.GetText(A_Index, 2)
            for si, sk in sysKeys {
                if (lvKey == sk && sk != managerKey) {
                    MsgBox("⚠️ Conflict! Ang " . sysLabels[si] . " Hotkey '" . sk . "' ay ginagamit na ng Custom Hotkey sa row #" . A_Index . ".", "Conflict!", 48)
                    return
                }
            }
        }

        ; Apply globals
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

        ; Write to ini
        IniWrite(active_profile,  "settings.ini", "Settings",      "ActiveProfile")
        IniWrite(sysHK_Invoice,   "settings.ini", "SystemHotkeys", "Invoice")
        IniWrite(sysHK_Vat,       "settings.ini", "SystemHotkeys", "Vat")
        IniWrite(sysHK_Discount,  "settings.ini", "SystemHotkeys", "Discount")
        IniWrite(sysHK_Manager,   "settings.ini", "SystemHotkeys", "Manager")
        SaveProfileSettings(active_profile, prefix, current_num, suffix, digit_length, vat_rate, discount_rate, vat_mode)

        ; Save custom hotkeys
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

        RegisterSystemHotkeys()
        RegisterCustomHotkeys()

        MsgBox("Nai-save na lahat!`n`n"
            . "Invoice Key:  " . sysHK_Invoice . "`n"
            . "VAT Key:      " . sysHK_Vat . "  (" . vat_mode . " " . vat_rate . "%)`n"
            . "Discount Key: " . sysHK_Discount . "  (" . discount_rate . "%)`n"
            . "Profile:      " . active_profile,
            "Success", "64 T3")
        mainGui.Destroy()
    }
}