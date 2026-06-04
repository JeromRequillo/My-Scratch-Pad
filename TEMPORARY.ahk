;@Ahk2Exe-SetFileVersion 4.4.0.0
;@Ahk2Exe-SetProductVersion 4.4.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; THEME COLORS
; =========================================================
global CLR_HEADER_BG   := "1E1530"
global CLR_SUBHDR_BG   := "2A1F42"
global CLR_ACCENT      := "7C3AED"
global CLR_ACCENT_SOFT := "9B5EF0"
global CLR_CONTENT_BG  := "F5F3FC"
global CLR_CARD_BG     := "FFFFFF"
global CLR_INPUT_BG    := "FFFFFF"
global CLR_INPUT_TEXT  := "2D1F4E"
global CLR_LABEL_TEXT  := "5A5270"
global CLR_MUTED       := "8474A8"
global CLR_DIVIDER     := "E0DAF0"
global CLR_PREVIEW_BG  := "F0EBFF"
global CLR_PREVIEW_TXT := "5B21B6"
global CLR_FOOTER_BG   := "EDE8F8"

; =========================================================
; Global Variables
; =========================================================
global current_num    := "0"
global prefix         := "AAPI"
global suffix         := "S"
global digit_length   := 7
global vat_rate       := 12.0
global active_profile := "Default"
global mainGui        := ""
global hotkeyList     := []
global activeHotkeys  := Map()

global sysHK_Invoice  := "!F9"
global sysHK_Vat      := "!v"
global sysHK_Manager  := "!F10"

global sysFunc_Invoice := ""
global sysFunc_Vat     := ""
global sysFunc_Manager := ""

; =========================================================
; SYSTEM TRAY
; =========================================================
A_IconTip := "KeyTap Pro v4.4"
TrayRecalcMenu()

TrayRecalcMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Open Manager", (*) => LaunchGUI())
    Tray.Add()
    Tray.Add("Exit Application", (*) => ExitApp())
}

; =========================================================
; STARTUP
; =========================================================
LoadSettings()
RegisterSystemHotkeys()
RegisterCustomHotkeys()
return

; =========================================================
; LOAD SETTINGS
; =========================================================
LoadSettings() {
    global current_num, prefix, suffix, digit_length, vat_rate
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Manager

    active_profile := IniRead("settings.ini", "Settings", "ActiveProfile", "Default")
    sysHK_Invoice  := IniRead("settings.ini", "SystemHotkeys", "Invoice", "!F9")
    sysHK_Vat      := IniRead("settings.ini", "SystemHotkeys", "Vat",     "!v")
    sysHK_Manager  := IniRead("settings.ini", "SystemHotkeys", "Manager", "!F10")

    profileSection := "Profile_" . active_profile
    current_num  := IniRead("settings.ini", profileSection, "LastNumber",  "0")
    prefix       := IniRead("settings.ini", profileSection, "Prefix",      "AAPI")
    suffix       := IniRead("settings.ini", profileSection, "Suffix",      "S")
    digit_length := Integer(IniRead("settings.ini", profileSection, "DigitLength", "7"))
    vat_rate     := Float(IniRead("settings.ini", profileSection, "VatRate", "12.0"))
    if (digit_length < 1)
        digit_length := 7
    if (vat_rate < 0 || vat_rate > 100)
        vat_rate := 12.0

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
    global sysHK_Invoice, sysHK_Vat, sysHK_Manager
    global sysFunc_Invoice, sysFunc_Vat, sysFunc_Manager

    if (sysFunc_Invoice != "")
        try Hotkey(sysFunc_Invoice, "Off")
    if (sysFunc_Vat != "")
        try Hotkey(sysFunc_Vat, "Off")
    if (sysFunc_Manager != "")
        try Hotkey(sysFunc_Manager, "Off")

    invoiceAction := (*) => DoInvoiceHotkey()
    try {
        Hotkey(sysHK_Invoice, invoiceAction, "On")
        sysFunc_Invoice := sysHK_Invoice
    } catch {
    }

    vatAction := (*) => DoVatHotkey()
    try {
        Hotkey(sysHK_Vat, vatAction, "On")
        sysFunc_Vat := sysHK_Vat
    } catch {
    }

    managerAction := (*) => LaunchGUI()
    try {
        Hotkey(sysHK_Manager, managerAction, "On")
        sysFunc_Manager := sysHK_Manager
    } catch {
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
    global vat_rate
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        ToolTip("Walang na-copy!")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    CleanAmount := StrReplace(A_Clipboard, ",", "")
    if IsNumber(CleanAmount) {
        divisor      := 1 + (vat_rate / 100)
        NetAmount    := Number(CleanAmount) / divisor
        FormattedNet := Round(NetAmount, 2)
        A_Clipboard  := FormattedNet
        Send("^v")
        ToolTip("VAT " . vat_rate . "% Deducted: " . FormattedNet)
        SetTimer(() => ToolTip(), -2000)
    } else {
        ToolTip("Error: Hindi ito numero!")
        SetTimer(() => ToolTip(), -2000)
    }
}

; =========================================================
; CUSTOM HOTKEYS
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
            } catch {
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

SaveProfileSettings(profileName, pfx, num, sfx, dlen, vrate) {
    profileSection := "Profile_" . profileName
    IniWrite(pfx,   "settings.ini", profileSection, "Prefix")
    IniWrite(num,   "settings.ini", profileSection, "LastNumber")
    IniWrite(sfx,   "settings.ini", profileSection, "Suffix")
    IniWrite(dlen,  "settings.ini", profileSection, "DigitLength")
    IniWrite(vrate, "settings.ini", profileSection, "VatRate")
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
                    for p in profiles {
                        if (p == pName)
                            found := true
                    }
                    if (!found)
                        profiles.Push(pName)
                }
            }
        }
    } catch {
    }
    return profiles
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

StyleInput(ctrl) {
    global CLR_INPUT_BG, CLR_INPUT_TEXT
    ctrl.Opt("+Background" . CLR_INPUT_BG)
    ctrl.SetFont("c" . CLR_INPUT_TEXT . " s10", "Segoe UI")
}

StyleInputMono(ctrl) {
    global CLR_INPUT_BG, CLR_INPUT_TEXT
    ctrl.Opt("+Background" . CLR_INPUT_BG)
    ctrl.SetFont("c" . CLR_INPUT_TEXT . " s10", "Consolas")
}

; =========================================================
; MAIN GUI
; =========================================================
LaunchGUI() {
    global mainGui, current_num, prefix, suffix, digit_length, vat_rate
    global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat, sysHK_Manager
    global CLR_HEADER_BG, CLR_ACCENT, CLR_CONTENT_BG, CLR_ACCENT_SOFT
    global CLR_INPUT_BG, CLR_INPUT_TEXT, CLR_LABEL_TEXT, CLR_MUTED
    global CLR_DIVIDER, CLR_PREVIEW_BG, CLR_PREVIEW_TXT

    LoadSettings()

    if (mainGui != "")
        mainGui.Destroy()

    mainGui := Gui("-MaximizeBox", "KeyTap Pro v4.4")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())
    mainGui.BackColor := CLR_CONTENT_BG
    mainGui.SetFont("s10", "Segoe UI")

    ; ===========================================================
    ; DARK HEADER BAND
    ; ===========================================================
    mainGui.SetFont("s13 Bold cE8E4F5", "Segoe UI")
    mainGui.Add("Text", "x18 y10 w300 h22 +BackgroundTrans Background" . CLR_HEADER_BG, "KeyTap Pro")
    mainGui.SetFont("s8 Norm c7C6FA0", "Segoe UI")
    mainGui.Add("Text", "x21 y32 w280 h16 +BackgroundTrans Background" . CLR_HEADER_BG, "v4.4  -  by Jerom Requillo")

    mainGui.SetFont("s8 Norm c8474A8", "Segoe UI")
    mainGui.Add("Text", "x440 y12 w230 h14 Right +BackgroundTrans Background" . CLR_HEADER_BG, "ACTIVE PROFILE")
    mainGui.SetFont("s11 Bold cE8E0F5", "Segoe UI")
    lblHeaderProfile := mainGui.Add("Text", "x440 y26 w230 h18 Right +BackgroundTrans Background" . CLR_HEADER_BG, active_profile)

    mainGui.SetFont("s8 Norm c8474A8", "Segoe UI")
    mainGui.Add("Text", "x18 y56 w120 h14 +BackgroundTrans Background" . CLR_HEADER_BG, "NEXT INVOICE")
    mainGui.SetFont("s12 Bold cC9B3F5", "Consolas")
    lblHeaderInvoice := mainGui.Add("Text", "x18 y70 w350 h18 +BackgroundTrans Background" . CLR_HEADER_BG, GenerateInvoice())

    ; Purple accent line under header
    mainGui.Add("Progress", "x0 y90 w700 h3 Background" . CLR_ACCENT . " c" . CLR_ACCENT, "100")

    ; ===========================================================
    ; TAB CONTROL
    ; ===========================================================
    mainGui.SetFont("s9 Norm", "Segoe UI")
    tabMenu := mainGui.Add("Tab3", "x0 y93 w700 h460",
        ["  Invoice Config  ", "  Custom Hotkeys  ", "  VAT Calculator  ", "  About  "])

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
    Loop 26 {
        keyChoices.Push(Chr(64 + A_Index))
    }
    Loop 12 {
        keyChoices.Push("F" . A_Index)
    }
    for extraKey in ["1","2","3","4","5","6","7","8","9","0","Space","Tab","Enter","Delete","Home","End","PgUp","PgDn","Up","Down","Left","Right"] {
        keyChoices.Push(extraKey)
    }

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

    AddLabel(x, y, w, txt) {
        mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
        return mainGui.Add("Text", "x" x " y" y " w" w " h20", txt)
    }

    AddSection(x, y, txt) {
        mainGui.SetFont("s8 Bold c" . CLR_MUTED, "Segoe UI")
        lbl := mainGui.Add("Text", "x" x " y" y " w640 h16", txt)
        mainGui.SetFont("s9 Norm", "Segoe UI")
        return lbl
    }

    AddDivider(y) {
        mainGui.Add("Text", "x16 y" y " w650 h1 +BackgroundTrans Background" . CLR_DIVIDER)
    }

    ; ===========================================================
    ; TAB 1 - INVOICE CONFIG
    ; ===========================================================
    tabMenu.UseTab(1)

    AddSection(16, 130, "PROFILE")

    mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y152 w70 h22 +0x200", "Profile:")

    profileList := GetProfileList()
    ddProfile := mainGui.Add("DropDownList", "x90 y150 w180 h200", profileList)
    StyleInput(ddProfile)
    for i, p in profileList {
        if (p == active_profile) {
            ddProfile.Value := i
            break
        }
    }

    btnNewProfile := mainGui.Add("Button", "x278 y149 w80 h24", "New")
    btnDelProfile := mainGui.Add("Button", "x364 y149 w80 h24", "Delete")
    btnNewProfile.OnEvent("Click", NewProfile)
    btnDelProfile.OnEvent("Click", DeleteProfile)
    ddProfile.OnEvent("Change", SwitchProfile)

    AddDivider(180)
    AddSection(16, 188, "INVOICE FORMAT")

    AddLabel(16, 212, 90, "Prefix:")
    guiCtrl_Prefix := mainGui.Add("Edit", "x110 y209 w160 h26", prefix)
    StyleInputMono(guiCtrl_Prefix)
    guiCtrl_Prefix.OnEvent("Change", UpdatePreview)

    AddLabel(16, 244, 90, "Next Number:")
    guiCtrl_Num := mainGui.Add("Edit", "x110 y241 w100 h26 Number", current_num)
    StyleInputMono(guiCtrl_Num)
    guiCtrl_Num.OnEvent("Change", UpdatePreview)

    btnReset := mainGui.Add("Button", "x216 y240 w70 h26", "Reset")
    btnReset.OnEvent("Click", (*) => (guiCtrl_Num.Value := "0", UpdatePreview()))

    AddLabel(16, 276, 90, "Suffix:")
    guiCtrl_Suffix := mainGui.Add("Edit", "x110 y273 w160 h26", suffix)
    StyleInputMono(guiCtrl_Suffix)
    guiCtrl_Suffix.OnEvent("Change", UpdatePreview)

    AddLabel(16, 308, 90, "Digit Length:")
    guiCtrl_DigitLen := mainGui.Add("Edit", "x110 y305 w50 h26 Number", digit_length)
    StyleInput(guiCtrl_DigitLen)
    guiCtrl_DigitLen.OnEvent("Change", UpdatePreview)

    AddDivider(338)
    AddSection(16, 345, "INVOICE HOTKEY")

    AddLabel(16, 368, 90, "Trigger Key:")
    ddInvMod := mainGui.Add("DropDownList", "x110 y366 w130 h200", modifierChoices)
    StyleInput(ddInvMod)

    mainGui.SetFont("s11 Bold c" . CLR_ACCENT_SOFT, "Segoe UI")
    mainGui.Add("Text", "x246 y369 w14 h20", "+")

    ddInvKey := mainGui.Add("DropDownList", "x262 y366 w80 h300", keyChoices)
    StyleInput(ddInvKey)

    mainGui.SetFont("s9 Norm c" . CLR_MUTED, "Segoe UI")
    guiCtrl_InvHKLabel := mainGui.Add("Text", "x350 y370 w200 h18", "Current: " . sysHK_Invoice)

    parsedInv := ParseHKString(sysHK_Invoice)
    SetModDD(ddInvMod, parsedInv.modLabel)
    SetKeyDD(ddInvKey, parsedInv.keyStr)

    UpdateInvHKLabel() {
        sym := modSymMap[ddInvMod.Text]
        guiCtrl_InvHKLabel.Value := "Current: " . sym . ddInvKey.Text
    }
    ddInvMod.OnEvent("Change", (*) => UpdateInvHKLabel())
    ddInvKey.OnEvent("Change", (*) => UpdateInvHKLabel())

    AddDivider(400)

    mainGui.SetFont("s9 Norm c" . CLR_MUTED, "Segoe UI")
    mainGui.Add("Text", "x16 y410 w60 h20", "Preview:")
    mainGui.SetFont("s13 Bold c" . CLR_PREVIEW_TXT, "Consolas")
    guiCtrl_PreviewText := mainGui.Add("Text", "x80 y408 w560 h22", GenerateInvoice())
    guiCtrl_PreviewText.Opt("+Background" . CLR_PREVIEW_BG)

    mainGui.SetFont("s8 Norm c" . CLR_MUTED, "Segoe UI")
    infoTxt1 := "Pumili ng Profile -> itakda ang format -> piliin ang hotkey -> i-click Save All Changes."
        . "  Bawat press ng hotkey, awtomatikong +1 ang numero at nase-save."
    mainGui.Add("Edit", "x16 y438 w650 h72 +ReadOnly +Wrap +VScroll -WantReturn", infoTxt1)
        .Opt("+Background" . CLR_PREVIEW_BG)

    ; ===========================================================
    ; TAB 2 - CUSTOM TEXT HOTKEYS
    ; ===========================================================
    tabMenu.UseTab(2)

    mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y130 w45 h22 +0x200", "Filter:")
    editSearch := mainGui.Add("Edit", "x65 y128 w300 h24")
    StyleInput(editSearch)
    btnClearSearch := mainGui.Add("Button", "x371 y127 w55 h25", "Clear")
    btnClearSearch.OnEvent("Click", (*) => (editSearch.Value := "", RefreshListView()))
    editSearch.OnEvent("Change", (*) => RefreshListView(editSearch.Value))

    LV := mainGui.Add("ListView",
        "x16 y158 w650 h155 +Grid -Multi +BackgroundFFFFFF",
        ["Status", "Shortcut Key", "Text / Output"])
    LV.ModifyCol(1, 65)
    LV.ModifyCol(2, 110)
    LV.ModifyCol(3, 453)
    LV.SetFont("s9", "Segoe UI")

    RefreshListView(filterTxt := "") {
        LV.Delete()
        for hk in hotkeyList {
            if (filterTxt != "" && !InStr(hk.key, filterTxt) && !InStr(hk.txt, filterTxt))
                continue
            statusTxt := hk.enabled ? "ON" : "OFF"
            LV.Add(, statusTxt, hk.key, hk.txt)
        }
    }
    RefreshListView()

    AddDivider(320)
    AddSection(16, 328, "ADD / EDIT HOTKEY")

    mainGui.SetFont("s8 Norm c" . CLR_MUTED, "Segoe UI")
    mainGui.Add("Text", "x16 y348 w85 h16", "Modifier:")
    mainGui.Add("Text", "x108 y348 w55 h16", "Key:")
    mainGui.Add("Text", "x170 y348 w300 h16", "Text to Output:")

    ddModifier := mainGui.Add("DropDownList", "x16 y364 w86 h120", modifierChoices)
    StyleInput(ddModifier)
    ddModifier.Value := 1

    ddKey := mainGui.Add("DropDownList", "x108 y364 w56 h300", keyChoices)
    StyleInput(ddKey)
    ddKey.Value := 1

    editTxt := mainGui.Add("Edit", "x170 y364 w496 h54 +Multi +WantReturn +VScroll")
    StyleInput(editTxt)

    mainGui.SetFont("s9 Norm", "Segoe UI")
    btnAdd      := mainGui.Add("Button", "x16 y426 w115 h26", "Add / Update")
    btnDel      := mainGui.Add("Button", "x136 y426 w110 h26", "Delete Line")
    btnToggle   := mainGui.Add("Button", "x252 y426 w120 h26", "Toggle ON/OFF")
    btnMoveUp   := mainGui.Add("Button", "x378 y426 w60 h26",  "Up")
    btnMoveDown := mainGui.Add("Button", "x444 y426 w65 h26",  "Down")

    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    btnToggle.OnEvent("Click", ToggleHotkey)
    btnMoveUp.OnEvent("Click", MoveRowUp)
    btnMoveDown.OnEvent("Click", MoveRowDown)
    LV.OnEvent("Click", SelectHotkey)

    mainGui.SetFont("s8 Italic c" . CLR_MUTED, "Segoe UI")
    mainGui.Add("Text", "x16 y460 w650 h28",
        "Tip: Piliin ang Modifier + Key. Pwedeng multi-line ang Text (Enter = bagong linya).")

    ; ===========================================================
    ; TAB 3 - VAT CALCULATOR
    ; ===========================================================
    tabMenu.UseTab(3)

    mainGui.SetFont("s11 Bold c0066CC", "Segoe UI")
    mainGui.Add("Text", "x16 y130 w500 h24", "Automated VAT Deductor Tool")

    AddDivider(158)

    mainGui.SetFont("s9 Bold c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y168 w130 h20", "Active Profile:")
    mainGui.SetFont("s9 Norm c228B22", "Segoe UI")
    mainGui.Add("Text", "x152 y168 w250 h20", active_profile)

    AddDivider(192)
    AddSection(16, 200, "VAT RATE")

    mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y224 w100 h22 +0x200", "Preset:")
    vatPresets := ["12% (Standard)", "5% (Reduced)", "0% (Zero-rated)", "Custom..."]
    ddVatPreset := mainGui.Add("DropDownList", "x120 y222 w145 h200", vatPresets)
    StyleInput(ddVatPreset)

    mainGui.Add("Text", "x272 y224 w50 h22 +0x200", "Rate:")
    guiCtrl_VatRate := mainGui.Add("Edit", "x318 y222 w65 h26", Format("{:.2f}", vat_rate))
    StyleInput(guiCtrl_VatRate)
    mainGui.SetFont("s10 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x388 y225 w20 h20", "%")

    mainGui.SetFont("s9 Norm c" . CLR_MUTED, "Segoe UI")
    guiCtrl_VatPreview := mainGui.Add("Text", "x412 y225 w200 h20", "")

    SetVatPresetFromRate(r) {
        if (r == 12.0)
            ddVatPreset.Value := 1
        else if (r == 5.0)
            ddVatPreset.Value := 2
        else if (r == 0.0)
            ddVatPreset.Value := 3
        else
            ddVatPreset.Value := 4
    }
    SetVatPresetFromRate(vat_rate)

    UpdateVatPreview() {
        raw := guiCtrl_VatRate.Value
        if (!IsNumber(raw) || Number(raw) < 0 || Number(raw) > 100) {
            guiCtrl_VatPreview.Value := "(invalid)"
            return
        }
        r := Number(raw)
        gross := Round(1000 * (1 + r / 100), 2)
        guiCtrl_VatPreview.Value := gross . " -> 1,000.00"
    }
    UpdateVatPreview()

    OnVatPresetChange(*) {
        if (ddVatPreset.Value == 1)
            guiCtrl_VatRate.Value := "12.00"
        else if (ddVatPreset.Value == 2)
            guiCtrl_VatRate.Value := "5.00"
        else if (ddVatPreset.Value == 3)
            guiCtrl_VatRate.Value := "0.00"
        else
            guiCtrl_VatRate.Focus()
        UpdateVatPreview()
    }
    ddVatPreset.OnEvent("Change", OnVatPresetChange)

    OnVatRateChange(*) {
        v := guiCtrl_VatRate.Value
        if (v == "12" || v == "12.0" || v == "12.00")
            ddVatPreset.Value := 1
        else if (v == "5" || v == "5.0" || v == "5.00")
            ddVatPreset.Value := 2
        else if (v == "0" || v == "0.0" || v == "0.00")
            ddVatPreset.Value := 3
        else
            ddVatPreset.Value := 4
        UpdateVatPreview()
    }
    guiCtrl_VatRate.OnEvent("Change", OnVatRateChange)

    AddDivider(258)
    AddSection(16, 266, "VAT HOTKEY")

    mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y290 w100 h22 +0x200", "Trigger Key:")
    ddVatMod := mainGui.Add("DropDownList", "x120 y288 w130 h200", modifierChoices)
    StyleInput(ddVatMod)

    mainGui.SetFont("s11 Bold c" . CLR_ACCENT_SOFT, "Segoe UI")
    mainGui.Add("Text", "x256 y291 w14 h20", "+")

    ddVatKey := mainGui.Add("DropDownList", "x272 y288 w80 h300", keyChoices)
    StyleInput(ddVatKey)

    mainGui.SetFont("s9 Norm c" . CLR_MUTED, "Segoe UI")
    guiCtrl_VatHKLabel := mainGui.Add("Text", "x360 y291 w200 h18", "Current: " . sysHK_Vat)

    parsedVat := ParseHKString(sysHK_Vat)
    SetModDD(ddVatMod, parsedVat.modLabel)
    SetKeyDD(ddVatKey, parsedVat.keyStr)

    UpdateVatHKLabel() {
        sym := modSymMap[ddVatMod.Text]
        guiCtrl_VatHKLabel.Value := "Current: " . sym . ddVatKey.Text
    }
    ddVatMod.OnEvent("Change", (*) => UpdateVatHKLabel())
    ddVatKey.OnEvent("Change", (*) => UpdateVatHKLabel())

    AddDivider(316)

    mainGui.SetFont("s8 Norm c" . CLR_MUTED, "Segoe UI")
    vatTxt := "PAANO GAMITIN:`n`n"
        . "1. Piliin ang VAT Rate (preset o custom).`n"
        . "2. Piliin ang VAT Hotkey.`n"
        . "3. I-click ang [Save All Changes].`n"
        . "4. I-highlight ang presyo (numero lang, walang peso sign).`n"
        . "5. Pindutin ang iyong napiling VAT Hotkey.`n`n"
        . "PAALALA: Huwag isama ang peso sign, PHP, o $ sa selection."
        . "  Ang net amount ay awtomatikong mare-replace at mananatili sa clipboard."
    mainGui.Add("Edit", "x16 y324 w650 h168 +ReadOnly +Wrap +VScroll -WantReturn", vatTxt)
        .Opt("+Background" . CLR_PREVIEW_BG)

    ; ===========================================================
    ; TAB 4 - ABOUT
    ; ===========================================================
    tabMenu.UseTab(4)

    mainGui.SetFont("s13 Bold c" . CLR_ACCENT, "Segoe UI")
    mainGui.Add("Text", "x16 y130 w500 h26", "KeyTap Pro v4.4")

    mainGui.SetFont("s9 Norm c" . CLR_LABEL_TEXT, "Segoe UI")
    mainGui.Add("Text", "x16 y158 w500 h18", "Version: 4.4.0  -  Reskin Edition")
    mainGui.Add("Text", "x16 y176 w500 h18", "Developer: Jerom Requillo  -  Copyright 2026")

    mainGui.SetFont("s9 Italic c" . CLR_MUTED, "Segoe UI")
    mainGui.Add("Link", "x16 y196 w500 h20",
        'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x16 y214 w500 h20",
        'Repo: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo / KeyTap Pro</a>')

    AddDivider(238)

    mainGui.SetFont("s8 Norm c" . CLR_MUTED, "Segoe UI")
    aboutTxt := "CONFIGURABLE GLOBAL HOTKEYS:`n"
        . "[Invoice Hotkey]  ->  Generate & Type Auto-Invoice Number`n"
        . "[VAT Hotkey]      ->  Deduct VAT from Selected Text`n"
        . "[Alt + F10]       ->  Open Manager (fixed)`n`n"
        . "TROUBLESHOOTING:`n`n"
        . "1. Hotkeys Hindi Gumagana`n"
        . "   Tingnan ang System Tray. I-right-click at piliin ang 'Reload Script'.`n`n"
        . "2. Hindi Nase-save ang Settings`n"
        . "   Siguraduhing hindi Read-Only ang settings.ini.`n`n"
        . "3. App Nag-crash o May Error`n"
        . "   I-check ang custom hotkeys - baka may duplicate o maling format.`n`n"
        . "DEPLOYMENT:`n"
        . "Fully portable. Walang registry entry. Pwedeng i-run mula sa USB o network drive."
    mainGui.Add("Edit", "x16 y248 w650 h250 +ReadOnly +Wrap +VScroll -WantReturn", aboutTxt)
        .Opt("+Background" . CLR_PREVIEW_BG)

    tabMenu.UseTab()

    ; ===========================================================
    ; STATUS BAR
    ; ===========================================================
    SB := mainGui.Add("StatusBar")
    SB.SetParts(220, 200)
    SB.SetText("  Active: " . active_profile, 1)
    SB.SetText("  VAT: " . Format("{:.1f}", vat_rate) . "%", 2)
    SB.SetText("  KeyTap Pro v4.4", 3)

    ; ===========================================================
    ; BOTTOM BUTTONS
    ; ===========================================================
    mainGui.SetFont("s10 Norm", "Segoe UI")
    btnSave   := mainGui.Add("Button", "x430 y565 w130 h32 Default", "Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel := mainGui.Add("Button", "x570 y565 w110 h32", "Close")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())

    mainGui.Show("w700 h610")

    ; ===========================================================
    ; GUI INTERNAL FUNCTIONS
    ; ===========================================================

    UpdatePreview(*) {
        dlen := (guiCtrl_DigitLen.Value == "" || Number(guiCtrl_DigitLen.Value) < 1)
            ? 7 : Number(guiCtrl_DigitLen.Value)
        temp := GenerateInvoice(guiCtrl_Prefix.Value, guiCtrl_Num.Value,
            guiCtrl_Suffix.Value, dlen)
        guiCtrl_PreviewText.Value := temp
        lblHeaderInvoice.Value    := temp
    }

    LoadProfileIntoGui(pName) {
        pSection := "Profile_" . pName
        guiCtrl_Prefix.Value   := IniRead("settings.ini", pSection, "Prefix",      "AAPI")
        guiCtrl_Num.Value      := IniRead("settings.ini", pSection, "LastNumber",  "0")
        guiCtrl_Suffix.Value   := IniRead("settings.ini", pSection, "Suffix",      "S")
        guiCtrl_DigitLen.Value := IniRead("settings.ini", pSection, "DigitLength", "7")
        loadedRate := Float(IniRead("settings.ini", pSection, "VatRate", "12.0"))
        guiCtrl_VatRate.Value  := Format("{:.2f}", loadedRate)
        SetVatPresetFromRate(loadedRate)
        UpdatePreview()
        UpdateVatPreview()
        lblHeaderProfile.Value := pName
        SB.SetText("  Active: " . pName, 1)
        SB.SetText("  VAT: " . Format("{:.1f}", loadedRate) . "%", 2)
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
        SaveProfileSettings(newName, guiCtrl_Prefix.Value, 0, guiCtrl_Suffix.Value, 7, curRate)
        newList := GetProfileList()
        ddProfile.Delete()
        for p in newList {
            ddProfile.Add([p])
        }
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
        for p in newList {
            ddProfile.Add([p])
        }
        ddProfile.Value := 1
        LoadProfileIntoGui("Default")
    }

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
            return "'" . newKey . "' ay ginagamit ng Manager hotkey (Alt+F10)."
        invKey := modSymMap[ddInvMod.Text] . ddInvKey.Text
        if (newKey == invKey)
            return "'" . newKey . "' ay ginagamit ng Invoice hotkey."
        vatKey := modSymMap[ddVatMod.Text] . ddVatKey.Text
        if (newKey == vatKey)
            return "'" . newKey . "' ay ginagamit ng VAT hotkey."
        Loop LV.GetCount() {
            if (A_Index == excludeRow)
                continue
            if (LV.GetText(A_Index, 2) == newKey)
                return "'" . newKey . "' ay duplicate sa row #" . A_Index . "."
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
            MsgBox("Hotkey Conflict!`n`n" . conflictMsg . "`n`nPiliin ang ibang key combination.", "Conflict!", 48)
            return
        }
        storedTxt := StrReplace(editTxt.Value, "`n", "\n")
        storedTxt := StrReplace(storedTxt, "`r", "")
        if (rowToUpdate > 0) {
            existingStatus := LV.GetText(rowToUpdate, 1)
            LV.Modify(rowToUpdate, , existingStatus, newKey, storedTxt)
        } else {
            LV.Add(, "ON", newKey, storedTxt)
        }
        editTxt.Value := ""
        ddModifier.Value := 1
        ddKey.Value := 1
    }

    DeleteHotkey(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng hotkey sa listahan.", "Babala", 48)
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
            MsgBox("Pumili muna ng hotkey sa listahan.", "Babala", 48)
            return
        }
        currentStatus := LV.GetText(selectedRow, 1)
        rawKey := LV.GetText(selectedRow, 2)
        hkTxt  := LV.GetText(selectedRow, 3)
        if (currentStatus == "ON") {
            LV.Modify(selectedRow, , "OFF", rawKey, hkTxt)
            try Hotkey(rawKey, "Off")
        } else {
            LV.Modify(selectedRow, , "ON", rawKey, hkTxt)
            try {
                realTxt   := StrReplace(hkTxt, "\n", "`n")
                boundFunc := CreateHotkeyFunc(realTxt)
                Hotkey(rawKey, boundFunc, "On")
                global activeHotkeys
                activeHotkeys[rawKey] := boundFunc
            } catch {
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

    ; ===========================================================
    ; SAVE ALL SETTINGS
    ; ===========================================================
    SaveSettings(*) {
        global prefix, current_num, suffix, digit_length, vat_rate
        global active_profile, hotkeyList, sysHK_Invoice, sysHK_Vat

        dlen := Number(guiCtrl_DigitLen.Value)
        if (guiCtrl_DigitLen.Value == "" || dlen < 1) {
            MsgBox("Digit Length ay dapat 1 o higit pa!", "Error", 48)
            return
        }
        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' ay hindi pwedeng blangko!", "Error", 48)
            return
        }

        rawVat := guiCtrl_VatRate.Value
        if (!IsNumber(rawVat) || Number(rawVat) < 0 || Number(rawVat) > 100) {
            MsgBox("VAT Rate ay dapat numero sa pagitan ng 0 at 100!", "Error", 48)
            return
        }

        newInvKey  := modSymMap[ddInvMod.Text] . ddInvKey.Text
        newVatKey  := modSymMap[ddVatMod.Text] . ddVatKey.Text
        managerKey := sysHK_Manager

        if (newInvKey == newVatKey) {
            MsgBox("Conflict! Invoice at VAT Hotkey ay parehong '" . newInvKey . "'!", "Conflict!", 48)
            return
        }
        if (newInvKey == managerKey || newVatKey == managerKey) {
            MsgBox("Conflict! Hindi pwedeng gamitin ang '" . managerKey . "' - nakalaan sa Manager.", "Conflict!", 48)
            return
        }

        Loop LV.GetCount() {
            lvKey := LV.GetText(A_Index, 2)
            if (lvKey == newInvKey) {
                MsgBox("Conflict! Invoice Key '" . newInvKey . "' ay ginagamit ng Custom Hotkey sa row #" . A_Index . ".", "Conflict!", 48)
                return
            }
            if (lvKey == newVatKey) {
                MsgBox("Conflict! VAT Key '" . newVatKey . "' ay ginagamit ng Custom Hotkey sa row #" . A_Index . ".", "Conflict!", 48)
                return
            }
        }

        prefix         := guiCtrl_Prefix.Value
        current_num    := Number(guiCtrl_Num.Value)
        suffix         := guiCtrl_Suffix.Value
        digit_length   := dlen
        vat_rate       := Number(rawVat)
        active_profile := ddProfile.Text
        sysHK_Invoice  := newInvKey
        sysHK_Vat      := newVatKey

        IniWrite(active_profile, "settings.ini", "Settings",      "ActiveProfile")
        IniWrite(sysHK_Invoice,  "settings.ini", "SystemHotkeys", "Invoice")
        IniWrite(sysHK_Vat,      "settings.ini", "SystemHotkeys", "Vat")
        IniWrite(sysHK_Manager,  "settings.ini", "SystemHotkeys", "Manager")
        SaveProfileSettings(active_profile, prefix, current_num, suffix, digit_length, vat_rate)

        try IniDelete("settings.ini", "Hotkeys")
        try IniDelete("settings.ini", "HotkeyState")
        hotkeyList := []
        Loop LV.GetCount() {
            hKey      := LV.GetText(A_Index, 2)
            hTxt      := LV.GetText(A_Index, 3)
            hState    := LV.GetText(A_Index, 1)
            isEnabled := (hState == "ON")
            realTxt   := StrReplace(hTxt, "\n", "`n")
            IniWrite(hTxt, "settings.ini", "Hotkeys",      hKey)
            IniWrite(isEnabled ? "1" : "0", "settings.ini", "HotkeyState", hKey)
            hotkeyList.Push({key: hKey, txt: realTxt, enabled: isEnabled})
        }

        RegisterSystemHotkeys()
        RegisterCustomHotkeys()

        MsgBox("Nai-save na lahat!`n`nInvoice Key : " . sysHK_Invoice
            . "`nVAT Key     : " . sysHK_Vat
            . "`nVAT Rate    : " . vat_rate . "% (" . active_profile . ")",
            "Saved", "64 T2.5")
        mainGui.Destroy()
    }
}