;@Ahk2Exe-SetFileVersion 4.0.0.0
;@Ahk2Exe-SetProductVersion 4.0.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  DARK MODE COLORS  (0xBBGGRR format para sa AHK)
; ============================================================
global C_BG        := 0x13100F   ; Pinaka-dark na background
global C_SURFACE   := 0x1F1C1B   ; Card/panel background
global C_SURFACE2  := 0x2A2623   ; Elevated surface
global C_ACCENT    := 0xF57B30   ; Orange accent
global C_ACCENT2   := 0xE8945A   ; Lighter accent hover
global C_TEXT      := 0xF0EDE8   ; Primary text (light)
global C_TEXT2     := 0xA09890   ; Secondary/muted text
global C_TEXT3     := 0x5A5250   ; Hint text
global C_BORDER    := 0x3A3330   ; Border color
global C_GREEN     := 0x22A855   ; Success green
global C_RED       := 0x4444EF   ; Error red

; ============================================================
;  GLOBAL STATE
; ============================================================
global current_num   := "0000000"
global prefix        := "AAPI"
global suffix        := "S"
global mainGui       := ""
global hotkeyList    := []
global activeHotkeys := Map()
global currentTab    := 1

; Startup
A_IconTip := "KeyTap Pro v4.0"
TrayRecalcMenu()
LoadSettings()
RegisterCustomHotkeys()
return

; ============================================================
;  TRAY MENU
; ============================================================
TrayRecalcMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Open Manager  (Alt+F10)", (*) => LaunchGUI())
    Tray.Add()
    Tray.Add("Exit", (*) => ExitApp())
}

; ============================================================
;  SETTINGS  (unchanged logic)
; ============================================================
LoadSettings() {
    global current_num, prefix, suffix, hotkeyList
    current_num := IniRead("settings.ini", "Sequence", "LastNumber", "0")
    prefix      := IniRead("settings.ini", "Settings",  "Prefix",     "AAPI")
    suffix      := IniRead("settings.ini", "Settings",  "Suffix",     "S")
    hotkeyList  := []
    try {
        hkSections := IniRead("settings.ini", "Hotkeys")
        Loop Parse, hkSections, "`n", "`r" {
            if (A_LoopField == "") continue
            pos := InStr(A_LoopField, "=")
            if (pos > 0)
                hotkeyList.Push({key: SubStr(A_LoopField,1,pos-1), txt: SubStr(A_LoopField,pos+1)})
        }
    } catch {
        hotkeyList := [{key:"!S", txt:"SAMPLE TXT"}]
    }
}

; ============================================================
;  HOTKEY REGISTRATION  (unchanged logic)
; ============================================================
RegisterCustomHotkeys() {
    global hotkeyList, activeHotkeys
    for hkKey, hkFunc in activeHotkeys
        try Hotkey(hkKey, "Off")
    activeHotkeys := Map()
    for hk in hotkeyList {
        if (hk.key != "" && hk.txt != "") {
            try {
                boundFunc := CreateHotkeyFunc(hk.txt)
                Hotkey(hk.key, boundFunc, "On")
                activeHotkeys[hk.key] := boundFunc
            }
        }
    }
}

CreateHotkeyFunc(txt) => (*) => SendInput(txt)

; ============================================================
;  INVOICE GENERATOR  (unchanged logic)
; ============================================================
GenerateInvoice(p := "", n := 0, s := "") {
    global prefix, current_num, suffix
    target_prefix := (p == "") ? prefix : p
    target_num    := (n == 0)  ? current_num : n
    target_suffix := (s == "") ? suffix : s
    return target_prefix . Format("{:07}", target_num) . target_suffix
}

; ============================================================
;  STATIC HOTKEYS  (unchanged logic)
; ============================================================
!F9:: {
    Critical()
    invoice_string := GenerateInvoice()
    SendInput(invoice_string)
    SoundBeep(750, 50)
    ToolTip("Sent: " invoice_string)
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
        NetAmount    := Number(CleanAmount) / 1.12
        FormattedNet := Round(NetAmount, 2)
        A_Clipboard  := FormattedNet
        Send("^v")
        ToolTip("VAT Deducted: " FormattedNet)
        SetTimer(() => ToolTip(), -2000)
    } else {
        ToolTip("Error: Hindi ito numero!")
        SetTimer(() => ToolTip(), -2000)
    }
}

; ============================================================
;  HELPER – Dark-mode a control via WinAPI
; ============================================================
DarkControl(hwnd) {
    ; Sets text/bg colors via WM_CTLCOLOR* is handled by GUI OnMessage
}

; Set a control's text color and background via SetWindowTheme (explorer dark)
ApplyDarkTheme(hwnd) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

; ============================================================
;  WinAPI HELPERS – draw filled rounded rect
; ============================================================
FillRoundRect(hdc, x, y, w, h, r, color) {
    hBrush := DllCall("CreateSolidBrush", "UInt", color, "Ptr")
    hOld   := DllCall("SelectObject", "Ptr", hdc, "Ptr", hBrush, "Ptr")
    DllCall("RoundRect", "Ptr", hdc, "Int", x, "Int", y, "Int", x+w, "Int", y+h, "Int", r, "Int", r)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hOld)
    DllCall("DeleteObject", "Ptr", hBrush)
}

; ============================================================
;  LAUNCH GUI
; ============================================================
LaunchGUI() {
    global mainGui, current_num, prefix, suffix, hotkeyList, currentTab
    global C_BG, C_SURFACE, C_SURFACE2, C_ACCENT, C_TEXT, C_TEXT2, C_TEXT3, C_BORDER

    LoadSettings()
    if (mainGui != "")
        mainGui.Destroy()

    ; --- MAIN WINDOW ---
    mainGui := Gui("+AlwaysOnTop -Caption +Border", "KeyTap Pro")
    mainGui.BackColor := C_BG
    mainGui.SetFont("s10 c" Format("{:06X}", C_TEXT), "Segoe UI")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())

    WinW := 560
    WinH := 540

    ; --- TITLE BAR (custom drawn) ---
    ; Logo + title text
    mainGui.SetFont("s12 Bold c" Format("{:06X}", C_TEXT), "Segoe UI")
    titLogo := mainGui.Add("Text", "x16 y14 w22 h22 +0x200 BackgroundTrans", "⚡")
    titLbl  := mainGui.Add("Text", "x42 y14 w200 h22 BackgroundTrans", "KeyTap Pro")
    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    verLbl  := mainGui.Add("Text", "x152 y17 w60 h18 BackgroundTrans", "v4.0")

    ; Close / minimize buttons (right side)
    mainGui.SetFont("s9 Bold c" Format("{:06X}", C_TEXT2), "Segoe UI")
    btnClose := mainGui.Add("Button", "x" WinW-38 " y8 w28 h24", "✕")
    btnMin   := mainGui.Add("Button", "x" WinW-70 " y8 w28 h24", "—")

    StyleBtn(btnClose.Hwnd, C_BG, C_TEXT2)
    StyleBtn(btnMin.Hwnd,   C_BG, C_TEXT2)
    btnClose.OnEvent("Click", (*) => mainGui.Destroy())
    btnMin.OnEvent("Click",   (*) => WinMinimize(mainGui.Hwnd))

    ; Draggable titlebar area
    titDrag := mainGui.Add("Text", "x0 y0 w" WinW-80 " h40 BackgroundTrans")
    titDrag.OnEvent("Click", DragWindow)

    ; --- HORIZONTAL SEPARATOR after title bar ---
    mainGui.Add("Text", "x0 y40 w" WinW " h1 0x10 Background" Format("{:06X}", C_BORDER))  ; line

    ; --- TAB NAV BUTTONS ---
    tabY := 50
    global tabBtns := []
    tabDefs := [
        {lbl:"  ⚡  Invoice",   id:1},
        {lbl:"  ⌨  Hotkeys",   id:2},
        {lbl:"  %  VAT Calc",  id:3},
        {lbl:"  ℹ  About",     id:4},
    ]
    tabX := 10
    for t in tabDefs {
        mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
        b := mainGui.Add("Button", "x" tabX " y" tabY " w120 h32", t.lbl)
        StyleTabBtn(b.Hwnd, (t.id == currentTab))
        local _id := t.id
        b.OnEvent("Click", SwitchTabFactory(_id))
        tabBtns.Push(b)
        tabX += 124
    }

    ; Tab underline bar
    mainGui.Add("Text", "x0 y84 w" WinW " h1 0x10 Background" Format("{:06X}", C_BORDER))

    ; ================================================================
    ;  CONTENT PANELS  (one per tab, shown/hidden via Show/Hide)
    ; ================================================================
    panelY := 96

    ; ---- TAB 1: INVOICE ----------------------------------------
    global pnl1 := []
    AppendPnl(pnl1, BuildInvoiceTab(panelY))

    ; ---- TAB 2: HOTKEYS ----------------------------------------
    global pnl2 := []
    AppendPnl(pnl2, BuildHotkeysTab(panelY))

    ; ---- TAB 3: VAT CALC ---------------------------------------
    global pnl3 := []
    AppendPnl(pnl3, BuildVatTab(panelY))

    ; ---- TAB 4: ABOUT ------------------------------------------
    global pnl4 := []
    AppendPnl(pnl4, BuildAboutTab(panelY))

    ; --- BOTTOM BAR separator ---
    mainGui.Add("Text", "x0 y" WinH-50 " w" WinW " h1 0x10 Background" Format("{:06X}", C_BORDER))

    ; --- BOTTOM BUTTONS ---
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    btnClose2 := mainGui.Add("Button", "x" WinW-230 " y" WinH-38 " w100 h28", "✕  Close")
    mainGui.SetFont("s9 Bold c" Format("{:06X}", C_TEXT), "Segoe UI")
    btnSave   := mainGui.Add("Button", "x" WinW-120 " y" WinH-38 " w110 h28", "💾  Save All")

    StyleBtn(btnClose2.Hwnd, C_SURFACE2, C_TEXT2)
    StyleBtnAccent(btnSave.Hwnd)

    btnClose2.OnEvent("Click", (*) => mainGui.Destroy())
    btnSave.OnEvent("Click",   SaveSettings)

    ; Show correct tab
    ShowTab(currentTab)

    mainGui.Show("w" WinW " h" WinH " Center")
}

; ============================================================
;  FACTORY  – returns a closure capturing tab id
; ============================================================
SwitchTabFactory(id) => (*) => SwitchTab(id)

SwitchTab(id) {
    global currentTab, tabBtns
    currentTab := id
    for i, b in tabBtns
        StyleTabBtn(b.Hwnd, (i == id))
    ShowTab(id)
}

ShowTab(id) {
    global pnl1, pnl2, pnl3, pnl4
    panels := [pnl1, pnl2, pnl3, pnl4]
    for i, p in panels {
        for ctrl in p {
            if (i == id) ctrl.Visible := true
            else         ctrl.Visible := false
        }
    }
}

AppendPnl(pnl, items) {
    for item in items
        pnl.Push(item)
}

; ============================================================
;  STYLE HELPERS
; ============================================================
StyleBtn(hwnd, bgColor, txtColor) {
    ; Remove default button look via WinAPI
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", " ", "Str", " ")
}

StyleTabBtn(hwnd, isActive) {
    global C_SURFACE2, C_ACCENT, C_TEXT, C_TEXT2, C_BG
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", " ", "Str", " ")
}

StyleBtnAccent(hwnd) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", " ", "Str", " ")
}

; ============================================================
;  DRAG WINDOW via title bar
; ============================================================
DragWindow(*) {
    global mainGui
    PostMessage(0xA1, 2,,, mainGui)  ; WM_NCLBUTTONDOWN, HTCAPTION
}

; ============================================================
;  LABEL HELPER
; ============================================================
SectionLabel(y, txt) {
    global mainGui, C_ACCENT, C_TEXT2
    mainGui.SetFont("s8 Bold c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrl := mainGui.Add("Text", "x20 y" y " w500 h16 BackgroundTrans", StrUpper(txt))
    return ctrl
}

InfoBox(x, y, w, h, txt) {
    global mainGui, C_SURFACE, C_TEXT2
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrl := mainGui.Add("Edit", "x" x " y" y " w" w " h" h " +ReadOnly +Wrap +VScroll -WantReturn Background" Format("{:06X}", C_SURFACE), txt)
    return ctrl
}

; ============================================================
;  BUILD TAB 1 – INVOICE
; ============================================================
BuildInvoiceTab(panelY) {
    global mainGui, prefix, current_num, suffix
    global C_TEXT, C_TEXT2, C_TEXT3, C_SURFACE, C_SURFACE2, C_ACCENT, C_BORDER
    ctrls := []

    y := panelY + 10
    ctrls.Push(SectionLabel(y, "  Invoice Generator Configuration"))

    y += 26
    ; ---- Prefix row
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Text",  "x24 y" y+4 " w80 h20 BackgroundTrans", "Prefix"))
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT), "Segoe UI")
    global inp_prefix := mainGui.Add("Edit", "x110 y" y " w180 h26 Background" Format("{:06X}", C_SURFACE2) " c" Format("{:06X}", C_TEXT), prefix)
    inp_prefix.OnEvent("Change", (*) => UpdateInvoicePreview())
    ctrls.Push(inp_prefix)

    y += 36
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Text",  "x24 y" y+4 " w80 h20 BackgroundTrans", "Next Number"))
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT), "Segoe UI")
    global inp_num := mainGui.Add("Edit", "x110 y" y " w120 h26 Number Background" Format("{:06X}", C_SURFACE2) " c" Format("{:06X}", C_TEXT), current_num)
    inp_num.OnEvent("Change", (*) => UpdateInvoicePreview())
    ctrls.Push(inp_num)

    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    btnReset := mainGui.Add("Button", "x236 y" y " w60 h26", "↺ Reset")
    DllCall("uxtheme\SetWindowTheme", "Ptr", btnReset.Hwnd, "Str", " ", "Str", " ")
    btnReset.OnEvent("Click", (*) => (inp_num.Value := "0", UpdateInvoicePreview()))
    ctrls.Push(btnReset)

    y += 36
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Text",  "x24 y" y+4 " w80 h20 BackgroundTrans", "Suffix"))
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT), "Segoe UI")
    global inp_suffix := mainGui.Add("Edit", "x110 y" y " w180 h26 Background" Format("{:06X}", C_SURFACE2) " c" Format("{:06X}", C_TEXT), suffix)
    inp_suffix.OnEvent("Change", (*) => UpdateInvoicePreview())
    ctrls.Push(inp_suffix)

    ; --- Preview Panel ---
    y += 44
    previewPnl := mainGui.Add("Text", "x16 y" y " w520 h52 Background" Format("{:06X}", C_SURFACE), "")
    ctrls.Push(previewPnl)

    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT3), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x30 y" y+8  " w100 h16 BackgroundTrans", "LIVE PREVIEW"))
    mainGui.SetFont("s14 Bold c" Format("{:06X}", C_ACCENT), "Segoe UI Semibold")
    global lbl_preview := mainGui.Add("Text", "x30 y" y+24 " w490 h24 BackgroundTrans", GenerateInvoice())
    ctrls.Push(lbl_preview)

    ; --- Info block ---
    y += 66
    ctrls.Push(SectionLabel(y, "  How to Use"))
    y += 22
    infoTxt :=
    "   [1]  Set Prefix, Number, and Suffix above, then click [ Save All ].`n" .
    "   [2]  Press  Alt + F9  anywhere to instantly type the invoice string.`n" .
    "   [3]  Counter auto-increments and saves every time  Alt + F9  is used.`n" .
    "   [TIP] Numbers use 7-digit zero-padding  (e.g.  1  →  0000001)"
    ctrls.Push(InfoBox(16, y, 520, 78, infoTxt))

    return ctrls
}

UpdateInvoicePreview() {
    global inp_prefix, inp_num, inp_suffix, lbl_preview
    try lbl_preview.Value := GenerateInvoice(inp_prefix.Value, inp_num.Value, inp_suffix.Value)
}

; ============================================================
;  BUILD TAB 2 – HOTKEYS
; ============================================================
BuildHotkeysTab(panelY) {
    global mainGui, hotkeyList
    global C_TEXT, C_TEXT2, C_TEXT3, C_SURFACE, C_SURFACE2, C_ACCENT, C_BORDER
    ctrls := []

    y := panelY + 10
    ctrls.Push(SectionLabel(y, "  Custom Text Hotkeys"))

    ; --- ListView ---
    y += 26
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT), "Segoe UI")
    global hkLV := mainGui.Add("ListView",
        "x16 y" y " w520 h160 +Grid -Multi Background" Format("{:06X}", C_SURFACE2),
        ["Shortcut Key", "Text / Output"])
    hkLV.ModifyCol(1, 110)
    hkLV.ModifyCol(2, 388)
    DllCall("uxtheme\SetWindowTheme", "Ptr", hkLV.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

    for hk in hotkeyList
        hkLV.Add(, hk.key, hk.txt)

    hkLV.OnEvent("Click", SelectHotkeyRow)
    ctrls.Push(hkLV)

    ; --- Add/Edit form ---
    y += 172
    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x16  y" y " w100 h16 BackgroundTrans", "Shortcut Key"))
    ctrls.Push(mainGui.Add("Text", "x140 y" y " w200 h16 BackgroundTrans", "Text to Output"))

    y += 18
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT), "Segoe UI")
    global editKey := mainGui.Add("Edit", "x16 y" y " w110 h26 Background" Format("{:06X}", C_SURFACE2) " c" Format("{:06X}", C_TEXT))
    global editTxt := mainGui.Add("Edit", "x140 y" y " w396 h26 Background" Format("{:06X}", C_SURFACE2) " c" Format("{:06X}", C_TEXT))
    ctrls.Push(editKey)
    ctrls.Push(editTxt)

    ; --- Buttons row ---
    y += 34
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    btnAdd := mainGui.Add("Button", "x16  y" y " w130 h28", "➕  Add / Update")
    btnDel := mainGui.Add("Button", "x154 y" y " w110 h28", "✕  Delete")
    DllCall("uxtheme\SetWindowTheme", "Ptr", btnAdd.Hwnd, "Str", " ", "Str", " ")
    DllCall("uxtheme\SetWindowTheme", "Ptr", btnDel.Hwnd, "Str", " ", "Str", " ")
    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    ctrls.Push(btnAdd)
    ctrls.Push(btnDel)

    ; --- Hint ---
    y += 36
    mainGui.SetFont("s8 Italic c" Format("{:06X}", C_TEXT3), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x16 y" y " w520 h28 BackgroundTrans",
        "  Symbols:   !  =  Alt     ^  =  Ctrl     +  =  Shift     #  =  Win`n  Example:   !A  =  Alt+A     ^+S  =  Ctrl+Shift+S"))

    return ctrls
}

SelectHotkeyRow(CtrlObj, RowNumber) {
    global editKey, editTxt
    if (RowNumber == 0) return
    editKey.Value := CtrlObj.GetText(RowNumber, 1)
    editTxt.Value := CtrlObj.GetText(RowNumber, 2)
}

AddUpdateHotkey(*) {
    global hkLV, editKey, editTxt
    if (editKey.Value == "" || editTxt.Value == "") {
        MsgBox("Please fill in both the Shortcut Key and Text fields.", "Missing Info", 48)
        return
    }
    rowToUpdate := 0
    Loop hkLV.GetCount() {
        if (hkLV.GetText(A_Index, 1) == editKey.Value) {
            rowToUpdate := A_Index
            break
        }
    }
    if (rowToUpdate > 0)
        hkLV.Modify(rowToUpdate,, editKey.Value, editTxt.Value)
    else
        hkLV.Add(, editKey.Value, editTxt.Value)
    editKey.Value := ""
    editTxt.Value := ""
}

DeleteHotkey(*) {
    global hkLV, editKey, editTxt
    selectedRow := hkLV.GetNext()
    if (selectedRow == 0) {
        MsgBox("Please select a hotkey from the list first.", "Nothing Selected", 48)
        return
    }
    hkLV.Delete(selectedRow)
    editKey.Value := ""
    editTxt.Value := ""
}

; ============================================================
;  BUILD TAB 3 – VAT CALCULATOR
; ============================================================
BuildVatTab(panelY) {
    global mainGui
    global C_TEXT, C_TEXT2, C_TEXT3, C_SURFACE, C_SURFACE2, C_ACCENT, C_GREEN, C_BORDER
    ctrls := []

    y := panelY + 10
    ctrls.Push(SectionLabel(y, "  Automated VAT Deductor — 12% PH VAT"))

    ; --- Visual flow ---
    y += 30
    ctrls.Push(mainGui.Add("Text", "x16 y" y " w520 h64 Background" Format("{:06X}", C_SURFACE), ""))

    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT3), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x36  y" y+6  " w120 h14 BackgroundTrans", "GROSS AMOUNT"))
    ctrls.Push(mainGui.Add("Text", "x322 y" y+6  " w120 h14 BackgroundTrans", "NET AMOUNT"))
    mainGui.SetFont("s13 Bold c" Format("{:06X}", C_TEXT), "Segoe UI Semibold")
    ctrls.Push(mainGui.Add("Text", "x36  y" y+22 " w180 h28 BackgroundTrans", "₱ 1,120.00"))
    mainGui.SetFont("s13 Bold c" Format("{:06X}", C_GREEN), "Segoe UI Semibold")
    ctrls.Push(mainGui.Add("Text", "x322 y" y+22 " w180 h28 BackgroundTrans", "₱ 1,000.00"))
    mainGui.SetFont("s9 c" Format("{:06X}", C_ACCENT), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x234 y" y+16 " w60 h28 +Center BackgroundTrans", "→ ÷1.12"))

    ; --- Instructions ---
    y += 78
    ctrls.Push(SectionLabel(y, "  How to Use"))
    y += 22
    vatTxt :=
    "   [1]  Highlight/select the price — numbers and commas only.`n" .
    "        DO NOT include currency symbols like ₱, PHP, or $.`n`n" .
    "   [2]  Press  Alt + V  to automatically deduct 12% VAT.`n" .
    "        The selected text is REPLACED with the net amount.`n`n" .
    "   [3]  Result is rounded to 2 decimal places.`n" .
    "        Press  Ctrl + Z  to undo if you made a mistake.`n`n" .
    "   [TIP] The net amount stays in your clipboard after the operation."
    ctrls.Push(InfoBox(16, y, 520, 130, vatTxt))

    return ctrls
}

; ============================================================
;  BUILD TAB 4 – ABOUT
; ============================================================
BuildAboutTab(panelY) {
    global mainGui
    global C_TEXT, C_TEXT2, C_TEXT3, C_SURFACE, C_SURFACE2, C_ACCENT, C_BORDER
    ctrls := []

    y := panelY + 10
    ; --- Hero block ---
    ctrls.Push(mainGui.Add("Text", "x16 y" y " w520 h80 Background" Format("{:06X}", C_SURFACE), ""))
    mainGui.SetFont("s16 Bold c" Format("{:06X}", C_ACCENT), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x32 y" y+10 " w400 h28 BackgroundTrans", "⚡ KeyTap Pro v4.0"))
    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT3), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x32 y" y+40 " w400 h16 BackgroundTrans", "Workflow Automation Suite  ·  AutoHotkey v2.0  ·  © 2026 Jerom Requillo"))
    mainGui.SetFont("s8 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Text", "x32 y" y+58 " w400 h16 BackgroundTrans", "Version 4.0.0  ·  Fully Portable  ·  No Registry Required"))

    ; --- Default Hotkeys ---
    y += 92
    ctrls.Push(SectionLabel(y, "  Default Global Hotkeys"))
    y += 22
    hkInfo :=
    "   Alt + F9    →   Generate and type the next auto-invoice number`n" .
    "   Alt + F10   →   Open this management interface`n" .
    "   Alt + V     →   Deduct 12% VAT from the selected text"
    ctrls.Push(InfoBox(16, y, 520, 58, hkInfo))

    ; --- Links ---
    y += 70
    ctrls.Push(SectionLabel(y, "  Developer Links"))
    y += 22
    mainGui.SetFont("s9 c" Format("{:06X}", C_TEXT2), "Segoe UI")
    ctrls.Push(mainGui.Add("Link", "x20 y" y    " w500 h20",
        'GitHub Profile:   <a href="https://github.com/JeromRequillo">github.com/JeromRequillo</a>'))
    ctrls.Push(mainGui.Add("Link", "x20 y" y+22 " w500 h20",
        'Repository:         <a href="https://github.com/JeromRequillo/KeyTap-Pro">github.com/JeromRequillo/KeyTap-Pro</a>'))

    ; --- Troubleshooting ---
    y += 52
    ctrls.Push(SectionLabel(y, "  Troubleshooting"))
    y += 22
    tsTxt :=
    "   Hotkeys unresponsive?`n" .
    "       Check the system tray for the icon. Right-click → Reload Script.`n`n" .
    "   Settings not saving?`n" .
    "       Ensure settings.ini exists in the same folder and is NOT Read-Only.`n`n" .
    "   Crashes or fatal errors?`n" .
    "       Check for duplicate or malformed hotkey entries in the Hotkeys tab."
    ctrls.Push(InfoBox(16, y, 520, 96, tsTxt))

    return ctrls
}

; ============================================================
;  SAVE SETTINGS  (unchanged logic, same as original)
; ============================================================
SaveSettings(*) {
    global prefix, current_num, suffix, hotkeyList
    global inp_prefix, inp_num, inp_suffix, hkLV, mainGui

    if (inp_num.Value == "") {
        MsgBox("'Next Number' cannot be empty!", "Error", 48)
        return
    }

    prefix      := inp_prefix.Value
    current_num := Format("{:05}", Number(inp_num.Value))
    suffix      := inp_suffix.Value

    IniWrite(prefix,                    "settings.ini", "Settings",  "Prefix")
    IniWrite(Number(inp_num.Value),     "settings.ini", "Sequence",  "LastNumber")
    IniWrite(suffix,                    "settings.ini", "Settings",  "Suffix")

    try IniDelete("settings.ini", "Hotkeys")

    hotkeyList := []
    Loop hkLV.GetCount() {
        hKey := hkLV.GetText(A_Index, 1)
        hTxt := hkLV.GetText(A_Index, 2)
        IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
        hotkeyList.Push({key: hKey, txt: hTxt})
    }

    RegisterCustomHotkeys()

    MsgBox("All settings saved and hotkeys updated!", "Saved ✓", "64 T2")
    mainGui.Destroy()
}
