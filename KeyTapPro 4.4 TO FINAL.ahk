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

    tabMenu := mainGui.Add("Tab3", "x10 y10 w660 h560",
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

    ; ── HEADER ───────────────────────────────────────────────
    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w450 h28 c0x0055AA", "🧾 Invoice Number Generator")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y76 w630 h18",
        "I-configure ang format ng invoice number at ang hotkey para sa auto-type.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── SECTION 1: PROFILE MANAGEMENT ────────────────────────
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
        "Bawat profile ay may sariling sequence number at format.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    btnNewProfile.OnEvent("Click", NewProfile)
    btnDelProfile.OnEvent("Click", DeleteProfile)
    ddProfile.OnEvent("Change", SwitchProfile)

    ; ── SECTION 2: INVOICE FORMAT ────────────────────────────
    mainGui.Add("GroupBox", "x330 y97 w305 h75", "  🔢 Invoice Format")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x345 y118 w55 h22 +0x200", "Prefix:")
    guiCtrl_Prefix := mainGui.Add("Edit", "x403 y116 w100 h24", prefix)
    mainGui.Add("Text", "x508 y118 w40 h22 +0x200", "Suffix:")
    guiCtrl_Suffix := mainGui.Add("Edit", "x552 y116 w75 h24", suffix)

    mainGui.Add("Text", "x345 y148 w80 h22 +0x200", "Digit Length:")
    guiCtrl_DigitLen := mainGui.Add("Edit", "x430 y146 w35 h24 Number", digit_length)
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x470 y150 w160 h18", "e.g. 7 digits:  0000001")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    guiCtrl_Prefix.OnEvent("Change", UpdatePreview)
    guiCtrl_Suffix.OnEvent("Change", UpdatePreview)
    guiCtrl_DigitLen.OnEvent("Change", UpdatePreview)

    ; ── SECTION 3: SEQUENCE NUMBER ───────────────────────────
    mainGui.Add("GroupBox", "x15 y182 w305 h80", "  🔄 Sequence Number")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y203 w85 h22 +0x200", "Next Number:")
    guiCtrl_Num := mainGui.Add("Edit", "x120 y201 w100 h28 Number", current_num)
    guiCtrl_Num.SetFont("s11 Bold")
    btnReset := mainGui.Add("Button", "x228 y201 w82 h28", "↩ Reset to 0")
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y235 w285 h18",
        "Auto-increments by 1 every time the hotkey is used.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    guiCtrl_Num.OnEvent("Change", UpdatePreview)
    btnReset.OnEvent("Click", (*) => (guiCtrl_Num.Value := "0", UpdatePreview()))

    ; ── SECTION 4: HOTKEY CONFIG ─────────────────────────────
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

    ; ── LIVE PREVIEW BOX ─────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y272 w620 h55", "  👁 Live Preview")
    mainGui.SetFont("bold s14 c0x005500", "Segoe UI")
    current_preview := GenerateInvoice()
    guiCtrl_PreviewText := mainGui.Add("Text",
        "x25 y288 w600 h30 Center +BackgroundTrans", current_preview)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── HOW TO USE ────────────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y337 w305 h215", "  💡 Paano Gamitin")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    howToTxt := "
    (
1. Pumili o gumawa ng Profile.

2. Itakda ang Prefix, Suffix, at
   Digit Length sa Invoice Format.

3. I-set ang Next Number (o Reset).

4. Piliin ang Invoice Hotkey.

5. I-click ang [💾 Save All Changes].

6. Pindutin ang hotkey kahit saan —
   awtomatikong mati-type ang invoice
   number at mag-iincrement ng +1!
    )"
    mainGui.Add("Edit", "x25 y355 w285 h188 +ReadOnly +Wrap -WantReturn -VScroll", howToTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── IMPORTANT NOTES ──────────────────────────────────────
    mainGui.Add("GroupBox", "x330 y337 w305 h215", "  📌 Mahalagang Paalala")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    notesTxt := "
    (
• Prefix + Zero-padded Number + Suffix
  ang format ng invoice.

  Example:
  Prefix: AAPI  |  Suffix: S
  Digit: 7  |  Number: 1
  → AAPI0000001S

• Bawat Profile ay may sariling
  sequence — magaling para sa
  iba't ibang kliyente o branch.

• Ang numero ay nase-save agad
  sa settings.ini pagkatapos ng
  bawat hotkey press.
    )"
    mainGui.Add("Edit", "x340 y355 w285 h188 +ReadOnly +Wrap -WantReturn -VScroll", notesTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

        ; =========================================================
    ; TAB 2: CUSTOM TEXT HOTKEYS
    ; =========================================================
    tabMenu.UseTab(2)

    ; ── HEADER ───────────────────────────────────────────────
    mainGui.SetFont("bold s13", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h28 c0x0055AA", "⌨ Custom Text Hotkeys")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y76 w630 h18",
        "Mag-assign ng keyboard shortcut sa kahit anong text — pangalan, address, template, o kahit anong paulit-ulit na ita-type.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── HOTKEY LIST ──────────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y97 w620 h215", "  📋 Listahan ng Hotkeys")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y116 w55 h22 +0x200", "🔍 Filter:")
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

    ; ── ADD / EDIT HOTKEY ────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y322 w620 h130", "  ✏ Mag-add o Mag-edit ng Hotkey")

    mainGui.SetFont("s9 Norm", "Segoe UI")

    ; Row 1: Modifier + Key + label
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
        "Pindutin ito = ima-type ang text sa ibaba")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    ; Row 2: Text output
    mainGui.Add("Text", "x28 y372 w65 h24 +0x200", "Text Output:")
    editTxt := mainGui.Add("Edit", "x96 y370 w520 h55 +Multi +WantReturn +VScroll")

    ; ── ACTION BUTTONS ───────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y462 w620 h88", "  🎛 Actions")

    btnAdd      := mainGui.Add("Button", "x28 y480 w145 h30", "➕ Add / Update")
    btnDel      := mainGui.Add("Button", "x180 y480 w130 h30", "❌ Delete")
    btnToggle   := mainGui.Add("Button", "x317 y480 w155 h30", "🔁 Toggle ON / OFF")
    btnMoveUp   := mainGui.Add("Button", "x480 y480 w70 h30", "▲ Move Up")
    btnMoveDown := mainGui.Add("Button", "x557 y480 w70 h30", "▼ Move Down")

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x28 y516 w600 h28",
        "💡 Tip: I-click ang isang row sa listahan para ma-load ito sa editor.  Pwedeng multi-line ang Text Output (Enter = bagong linya).  ▲▼ para i-reorder.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    btnMoveUp.OnEvent("Click", MoveRowUp)
    btnMoveDown.OnEvent("Click", MoveRowDown)
    LV.OnEvent("Click", SelectHotkey)

        ; =========================================================
    ; TAB 3: VAT CALCULATOR  (REDESIGNED - WIDER)
    ; =========================================================
    tabMenu.UseTab(3)

    ; ── HEADER ───────────────────────────────────────────────
    mainGui.SetFont("bold s12", "Segoe UI")
    mainGui.Add("Text", "x20 y48 w500 h26 c0x0055AA", "💰 VAT & Discount Tool")
    mainGui.SetFont("s9 Norm cGray", "Segoe UI")
    mainGui.Add("Text", "x20 y74 w620 h18",
        "I-configure ang VAT at Discount hotkeys, at gamitin ang built-in calculator para sa mabilis na computation.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── SECTION 1: VAT SETTINGS ──────────────────────────────
    mainGui.Add("GroupBox", "x15 y95 w305 h190", "  📋 VAT Settings")

    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y118 w100 h20", "Active Profile:")
    mainGui.SetFont("bold s9 cGreen", "Segoe UI")
    guiCtrl_VatProfileLabel := mainGui.Add("Text", "x135 y118 w170 h20", active_profile)
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    ; VAT Rate row
    mainGui.Add("Text", "x28 y148 w80 h22 +0x200", "VAT Rate:")
    vatPresets := ["12% (Standard)", "5% (Reduced)", "0% (Zero-rated)", "Custom..."]
    ddVatPreset    := mainGui.Add("DropDownList", "x110 y146 w120 h200", vatPresets)
    guiCtrl_VatRate := mainGui.Add("Edit", "x236 y146 w48 h22", Format("{:.2f}", vat_rate))
    mainGui.Add("Text", "x288 y148 w15 h20", "%")

    ; VAT Mode - radio buttons (clearer than two small buttons)
    mainGui.Add("Text", "x28 y178 w80 h22 +0x200", "Mode:")
    rbDeduct := mainGui.Add("Radio", "x110 y178 w100 h22", "⬇ Deduct VAT")
    rbAdd     := mainGui.Add("Radio", "x215 y178 w100 h22", "⬆ Add VAT")
    if (vat_mode == "Add") {
        rbAdd.Value := 1
    } else {
        rbDeduct.Value := 1
    }

    ; Live preview
    guiCtrl_VatPreview := mainGui.Add("Text", "x28 y207 w285 h18 cBlue", "")

    ; VAT Hotkey row
    mainGui.Add("Text", "x28 y233 w80 h22 +0x200", "Hotkey:")
    ddVatMod := mainGui.Add("DropDownList", "x110 y231 w108 h200", modifierChoices)
    ddVatKey := mainGui.Add("DropDownList", "x223 y231 w65 h300", keyChoices)
    guiCtrl_VatHKLabel := mainGui.Add("Text", "x110 y256 w200 h18 cGray", "Active: " . sysHK_Vat)

    parsedVat := ParseHKString(sysHK_Vat)
    SetModDD(ddVatMod, parsedVat.modLabel)
    SetKeyDD(ddVatKey, parsedVat.keyStr)

    ; ── SECTION 2: DISCOUNT SETTINGS ─────────────────────────
    mainGui.Add("GroupBox", "x330 y95 w305 h190", "  🏷 Discount Settings")

    mainGui.SetFont("s9 Norm", "Segoe UI")

    ; Discount rate row
    mainGui.Add("Text", "x345 y118 w100 h22 +0x200", "Discount Rate:")
    guiCtrl_DiscRate := mainGui.Add("Edit", "x450 y118 w60 h22", Format("{:.2f}", discount_rate))
    mainGui.Add("Text", "x514 y118 w15 h22 +0x200", "%")

    ; Discount preview
    guiCtrl_DiscPreview := mainGui.Add("Text", "x345 y148 w280 h18 cBlue", "")

    ; Quick preset discount buttons
    mainGui.Add("Text", "x345 y172 w60 h22 +0x200", "Quick set:")
    btn5pct  := mainGui.Add("Button", "x410 y170 w40 h24", "5%")
    btn10pct := mainGui.Add("Button", "x454 y170 w40 h24", "10%")
    btn15pct := mainGui.Add("Button", "x498 y170 w40 h24", "15%")
    btn20pct := mainGui.Add("Button", "x542 y170 w40 h24", "20%")
    btn5pct.OnEvent("Click",  (*) => (guiCtrl_DiscRate.Value := "5.00",  UpdateDiscPreview()))
    btn10pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "10.00", UpdateDiscPreview()))
    btn15pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "15.00", UpdateDiscPreview()))
    btn20pct.OnEvent("Click", (*) => (guiCtrl_DiscRate.Value := "20.00", UpdateDiscPreview()))

    ; Discount Hotkey row
    mainGui.Add("Text", "x345 y204 w65 h22 +0x200", "Hotkey:")
    ddDiscMod := mainGui.Add("DropDownList", "x415 y202 w108 h200", modifierChoices)
    ddDiscKey := mainGui.Add("DropDownList", "x527 y202 w65 h300", keyChoices)
    guiCtrl_DiscHKLabel := mainGui.Add("Text", "x415 y227 w200 h18 cGray", "Active: " . sysHK_Discount)

    parsedDisc := ParseHKString(sysHK_Discount)
    SetModDD(ddDiscMod, parsedDisc.modLabel)
    SetKeyDD(ddDiscKey, parsedDisc.keyStr)

    ; Multi-line tip
    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x345 y252 w280 h30",
        "💡 Hotkey works on highlighted text — pwedeng multi-line!")
    mainGui.SetFont("s9 Norm cDefault", "Segoe UI")

    ; ── SECTION 3: IN-APP CALCULATOR ─────────────────────────
    mainGui.Add("GroupBox", "x15 y295 w620 h235", "  🧮 In-App Calculator")

    ; --- Left column: Inputs ---
    mainGui.SetFont("bold s9 c0x333333", "Segoe UI")
    mainGui.Add("Text", "x28 y318 w280 h18", "INPUT")
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
    calcOrderChoices := ["Discount first, then VAT", "VAT first, then Discount"]
    ddCalcOrder := mainGui.Add("DropDownList", "x125 y433 w160 h100", calcOrderChoices)
    ddCalcOrder.Value := 1

    mainGui.Add("Text", "x28 y463 w90 h24 +0x200", "VAT Mode:")
    calcModeChoices := ["Deduct VAT (remove from gross)", "Add VAT (add on top)"]
    ddCalcMode := mainGui.Add("DropDownList", "x125 y461 w175 h100", calcModeChoices)
    ddCalcMode.Value := (vat_mode == "Add") ? 2 : 1

    btnCalculate := mainGui.Add("Button", "x28 y495 w120 h30", "🧮 Calculate")
    btnClearCalc := mainGui.Add("Button", "x155 y495 w70 h30", "🗑 Clear")

    ; --- Right column: Results ---
    mainGui.Add("Text", "x320 y295 w2 h235 +0x10")  ; vertical divider

    mainGui.SetFont("bold s9 c0x333333", "Segoe UI")
    mainGui.Add("Text", "x335 y318 w290 h18", "BREAKDOWN")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    ; Result rows - label + value pairs, well-spaced
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

    ; ── HELPER FUNCTIONS ─────────────────────────────────────

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

    ; ── CALCULATOR LOGIC ──────────────────────────────────────

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
            calcNetLabel.Value   := "⚠ Enter a valid amount"
            calcGrossLabel.Value := "—"
            calcDiscLabel.Value  := "—"
            calcAfterDisc.Value  := "—"
            calcVatLabel.Value   := "—"
            return
        }
        if (!IsNumber(rawDisc) || Number(rawDisc) < 0 || Number(rawDisc) > 100) {
            calcNetLabel.Value := "⚠ Discount must be 0–100"
            return
        }
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            calcNetLabel.Value := "⚠ VAT must be 0–100"
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

    OnCopyNet(*) {
        if (calcNetValue == "") {
            ToolTip("Wala pang result! I-click muna ang Calculate.")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        A_Clipboard := calcNetValue
        ToolTip("✅ Net amount copied: " . calcNetValue)
        SetTimer(() => ToolTip(), -2000)
    }
    btnCopyNet.OnEvent("Click", OnCopyNet)

    OnCopyAll(*) {
        if (calcNetValue == "") {
            ToolTip("Wala pang result! I-click muna ang Calculate.")
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
        ToolTip("✅ Full breakdown copied!")
        SetTimer(() => ToolTip(), -2000)
    }
    btnCopyAll.OnEvent("Click", OnCopyAll)

        ; =========================================================
    ; TAB 4: ABOUT
    ; =========================================================
    tabMenu.UseTab(4)

    ; ── APP IDENTITY ─────────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y48 w620 h115", "  🎯 About KeyTap Pro")

    mainGui.SetFont("bold s14 c0x0055AA", "Segoe UI")
    mainGui.Add("Text", "x30 y68 w400 h30", "🎯 KeyTap Pro  v4.3")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x30 y100 w300 h20", "Version:    4.3.0  —  Configurable Hotkeys")
    mainGui.Add("Text", "x30 y120 w300 h20", "Developer:  Jerom Requillo")
    mainGui.Add("Text", "x30 y140 w300 h20", "Build Date: 2026")
    mainGui.SetFont("italic s9 c0x0055AA", "Segoe UI")
    mainGui.Add("Link", "x370 y100 w250 h20",
        'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x370 y122 w250 h20",
        'Repo: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo/KeyTap-Pro</a>')
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── HOTKEY REFERENCE ─────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y173 w305 h140", "  ⌨ Global Hotkey Reference")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y193 w285 h20 cGray", "These are set in the other tabs:")
    mainGui.Add("Text", "x28 y215 w285 h20", "🧾  Invoice Hotkey  →  Auto-type invoice #")
    mainGui.Add("Text", "x28 y237 w285 h20", "💰  VAT Hotkey      →  Deduct/Add VAT")
    mainGui.Add("Text", "x28 y259 w285 h20", "🏷  Discount Hotkey →  Apply discount %")
    mainGui.Add("Text", "x28 y281 w285 h20 cGray", "Alt+F10  →  Open this Manager (fixed)")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── TROUBLESHOOTING ──────────────────────────────────────
    mainGui.Add("GroupBox", "x330 y173 w305 h140", "  🛠 Troubleshooting")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    ts1 := "1.  Hotkeys not working?"
    ts2 := "    Check system tray for the H icon."
    ts3 := "    Right-click → Reload Script."
    ts4 := "2.  Settings not saving?"
    ts5 := "    Check that settings.ini is not"
    ts6 := "    marked as Read-Only."
    ts7 := "3.  App crashes?"
    ts8 := "    Check for duplicate hotkeys."
    mainGui.Add("Text", "x345 y193 w285 h18", ts1)
    mainGui.Add("Text", "x345 y211 w285 h18 cGray", ts2)
    mainGui.Add("Text", "x345 y229 w285 h18 cGray", ts3)
    mainGui.Add("Text", "x345 y249 w285 h18", ts4)
    mainGui.Add("Text", "x345 y267 w285 h18 cGray", ts5)
    mainGui.Add("Text", "x345 y285 w285 h18 cGray", ts6)
    mainGui.Add("Text", "x345 y303 w285 h18", ts7) 
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── DEPLOYMENT INFO ───────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y323 w620 h80", "  📂 Deployment Info")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    mainGui.Add("Text", "x28 y343 w595 h20",
        "✅  Fully portable — no Registry entries. Can run from USB, network drive, or Startup folder.")
    mainGui.Add("Text", "x28 y363 w595 h20",
        "✅  All settings stored locally in settings.ini alongside the .ahk / .exe file.")
    mainGui.Add("Text", "x28 y383 w595 h20",
        "✅  Multiple profiles supported — one app, multiple invoice sequences or VAT rates.")
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

    ; ── CHANGELOG ────────────────────────────────────────────
    mainGui.Add("GroupBox", "x15 y413 w620 h135", "  📝 Changelog")
    mainGui.SetFont("s9 Norm", "Segoe UI")
    clTxt := "
    (
v4.3  —  VAT & Discount Tab redesigned. Wider window (680px). GroupBox layout. In-app calculator with breakdown. Discount hotkey with multi-line support. VAT Add/Deduct mode toggle (radio buttons). Quick preset discount buttons (5/10/15/20%). Live peso preview on all settings. Copy Net & Copy Full Breakdown buttons.

v4.2  —  Configurable system hotkeys (Invoice, VAT, Manager). Hotkey conflict detection. Profile-based VAT rate storage.

v4.1  —  Multi-profile support. Custom text hotkey manager with enable/disable toggle. Reorder (▲▼) support.

v4.0  —  Initial release. Auto-invoice with prefix/suffix/digit-length. VAT deductor hotkey. System tray integration.
    )"
    mainGui.Add("Edit", "x28 y430 w592 h108 +ReadOnly +Wrap +VScroll -WantReturn", clTxt)
    mainGui.SetFont("s10 Norm cDefault", "Segoe UI")

        tabMenu.UseTab()

    ; --- BOTTOM BUTTONS ---
    mainGui.SetFont("Norm s10", "Segoe UI")
    btnSave   := mainGui.Add("Button", "x180 y590 w140 h35 Default", "💾 Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel := mainGui.Add("Button", "x340 y590 w140 h35", "✖ Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())

    mainGui.Show("w680 h640")

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
        conflictFound := false
        conflictMsg2  := ""
        for ci, ck in sysKeys {
            for cj, cv in sysKeys {
                if (ci >= cj)
                    continue
                if (ck == cv) {
                    conflictMsg2 := "⚠️ Conflict! " . sysLabels[ci] . " at " . sysLabels[cj] . " ay parehong '" . ck . "'!`n`nPiliin ang ibang key."
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
