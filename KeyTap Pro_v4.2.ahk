;@Ahk2Exe-SetFileVersion 4.2.0.0
;@Ahk2Exe-SetProductVersion 4.2.0.0
;@Ahk2Exe-SetCompanyName Jerom Requillo
;@Ahk2Exe-SetDescription KeyTap Pro - Workflow Automation Suite
;@Ahk2Exe-SetCopyright Copyright (C) 2026 Jerom Requillo. All rights reserved.

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "🎯 KeyTap pro v4.2"
TrayRecalcMenu()

; Global Variables
global current_num  := "0000000"
global prefix       := "AAPI"
global suffix       := "S"
global digit_length := 7          ; NEW: custom digit length, default 7
global active_profile := "Default" ; NEW: currently active profile name
global mainGui      := ""
global hotkeyList   := []
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
    global current_num, prefix, suffix, digit_length, active_profile, hotkeyList

    ; Load active profile name first
    active_profile := IniRead("settings.ini", "Settings", "ActiveProfile", "Default")

    ; Load settings from the active profile section
    profileSection := "Profile_" . active_profile
    current_num  := IniRead("settings.ini", profileSection, "LastNumber", "0")
    prefix       := IniRead("settings.ini", profileSection, "Prefix", "AAPI")
    suffix       := IniRead("settings.ini", profileSection, "Suffix", "S")
    digit_length := Integer(IniRead("settings.ini", profileSection, "DigitLength", "7"))
    if (digit_length < 1)
        digit_length := 7

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

; NEW: Save just the invoice profile settings (not hotkeys)
SaveProfileSettings(profileName, pfx, num, sfx, dlen) {
    profileSection := "Profile_" . profileName
    IniWrite(pfx,   "settings.ini", profileSection, "Prefix")
    IniWrite(num,   "settings.ini", profileSection, "LastNumber")
    IniWrite(sfx,   "settings.ini", profileSection, "Suffix")
    IniWrite(dlen,  "settings.ini", profileSection, "DigitLength")
}

; NEW: Get list of all saved profile names from settings.ini
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

GenerateInvoice(p := "", n := 0, s := "", dlen := 0) {
    global prefix, current_num, suffix, digit_length
    target_prefix := (p == "")    ? prefix       : p
    target_num    := (n == 0)     ? current_num  : n
    target_suffix := (s == "")    ? suffix       : s
    target_dlen   := (dlen == 0)  ? digit_length : dlen
    formatted_num := Format("{:0" . target_dlen . "}", target_num)
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
    global current_num, active_profile, digit_length, prefix, suffix
    current_num := Number(current_num) + 1
    profileSection := "Profile_" . active_profile
    IniWrite(current_num, "settings.ini", profileSection, "LastNumber")
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
        ToolTip("VAT Deducted: " . FormattedNet)
        SetTimer(() => ToolTip(), -2000)
    } else {
        ToolTip("Error: Hindi ito numero!")
        SetTimer(() => ToolTip(), -2000)
    }
}

; --- MAIN GUI LAUNCHER ---

LaunchGUI() {
    global mainGui, current_num, prefix, suffix, digit_length, active_profile, hotkeyList

    LoadSettings()

    if (mainGui != "")
        mainGui.Destroy()

    mainGui := Gui("-MaximizeBox", "🎯 KeyTap Pro v4.2")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy())
    mainGui.SetFont("s10", "Segoe UI")

    tabMenu := mainGui.Add("Tab3", "x10 y10 w480 h400", ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "About"])

    ; =========================================================
    ; --- TAB 1: INVOICE CONFIGURATION (UPGRADED) ---
    ; =========================================================
    tabMenu.UseTab(1)

    ; --- Profile Selector Row ---
    mainGui.SetFont("bold s9", "Segoe UI")
    mainGui.Add("Text", "x20 y50 w55 h20", "Profile:")
    mainGui.SetFont("s9 Norm", "Segoe UI")

    profileList := GetProfileList()
    ddProfile := mainGui.Add("DropDownList", "x78 y48 w160 h200", profileList)
    ; Set dropdown to active profile
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

    ; --- Separator line ---
    mainGui.Add("Text", "x20 y73 w440 h1 +0x10")  ; etched line

    ; --- Prefix / Number / Suffix ---
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

    ; --- Digit Length ---
    mainGui.Add("Text", "x20 y172 w90 h20", "Digit Length:")
    guiCtrl_DigitLen := mainGui.Add("Edit", "x115 y169 w40 h25 Number", digit_length)
    guiCtrl_DigitLen.OnEvent("Change", UpdatePreview)
    mainGui.SetFont("s8 cGray", "Segoe UI")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; --- Preview ---
    mainGui.SetFont("bold s10", "Segoe UI")
    current_preview := GenerateInvoice()
    guiCtrl_PreviewText := mainGui.Add("Text", "x20 y200 w450 h20 Center +BackgroundTrans", "Preview: " . current_preview)

    mainGui.SetFont("Norm s9 cGray", "Segoe UI")
    invoiceTxt := "
    (
    💡PAANO GAMITIN ANG INVOICE GENERATOR:

    1. Pumili ng Profile o gumawa ng bago sa pamamagitan ng [➕ New].

    2. Itakda ang Prefix, Next Number, Suffix, at Digit Length.

    3. I-click ang [ Save All Changes ] para mai-save.

    4. Pindutin ang [ Alt + F9 ] kahit saan para awtomatikong i-type ang Invoice!

    💡 MAHALAGANG PAALALA:

    • Multiple Profiles: Bawat profile ay may sariling Prefix, Suffix, Digit Length, at sequence number. Ang pagpapalit ng profile ay agad na gagamitin ito sa Alt+F9.

    • Digit Length: Kontrolin kung ilang digit ang numero (e.g., 5 digits: '1' = '00001'). Default ay 7.

    • Auto-Increment: Sa bawat Alt+F9, awtomatikong +1 ang numero at nase-save sa kasalukuyang profile.

    • Reset Button: Ibabalik sa 0 ang sequence number ng kasalukuyang profile.
    )"
    mainGui.Add("Edit", "x20 y225 w450 h165 +ReadOnly +Wrap +VScroll -WantReturn", invoiceTxt)

    mainGui.SetFont("Norm s10 cDefault", "Segoe UI")

    ; =========================================================
    ; --- TAB 2: CUSTOM TEXT HOTKEYS (UNCHANGED) ---
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

    LV := mainGui.Add("ListView", "x20 y74 w440 h130 +Grid -Multi", ["Status", "Shortcut Key", "Text / Name to Output"])
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
    mainGui.Add("Text", "x160 y213 w200 h18", "Text to Output (multi-line ok):")

    modifierChoices := ["Alt (!)", "Ctrl (^)", "Shift (+)", "Ctrl+Alt (^!)", "Alt+Shift (!+)", "Ctrl+Shift (^+)"]
    ddModifier := mainGui.Add("DropDownList", "x20 y231 w82 h120", modifierChoices)
    ddModifier.Value := 1

    keyChoices := []
    Loop 26
        keyChoices.Push(Chr(64 + A_Index))
    Loop 12
        keyChoices.Push("F" . A_Index)
    for extraKey in ["1","2","3","4","5","6","7","8","9","0","Space","Tab","Enter","Delete","Home","End","PgUp","PgDn","Up","Down","Left","Right"]
        keyChoices.Push(extraKey)

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
    mainGui.Add("Text", "x25 y50 w400 h25 c0x0066CC", "🎯 KeyTap Pro v4.2")
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x25 y75 w400 h18", "Version: 4.2.0 (Dynamic ListView)")
    mainGui.Add("Text", "x25 y95 w400 h18", "Developer: Jerom Requillo")

    mainGui.SetFont("italic s9", "Segoe UI")
    mainGui.Add("Link", "x25 y120 w400 h20", 'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x25 y140 w400 h20", 'Repository: <a href="https://github.com/JeromRequillo/KeyTap-Pro">JeromRequillo/🎯 KeyTap Pro v4.2</a>')

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
    btnSave   := mainGui.Add("Button", "x130 y425 w110 h32 Default", "Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel := mainGui.Add("Button", "x260 y425 w110 h32", "Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())

    mainGui.Show("w500 h470")

    ; =========================================================
    ; --- GUI INTERNAL FUNCTIONS ---
    ; =========================================================

    UpdatePreview(*) {
        dlen := (guiCtrl_DigitLen.Value == "" || Number(guiCtrl_DigitLen.Value) < 1) ? 7 : Number(guiCtrl_DigitLen.Value)
        temp_preview := GenerateInvoice(guiCtrl_Prefix.Value, guiCtrl_Num.Value, guiCtrl_Suffix.Value, dlen)
        guiCtrl_PreviewText.Value := "Preview: " . temp_preview
    }

    ; --- Load a profile's values into the GUI fields ---
    LoadProfileIntoGui(pName) {
        pSection := "Profile_" . pName
        guiCtrl_Prefix.Value   := IniRead("settings.ini", pSection, "Prefix",      "AAPI")
        guiCtrl_Num.Value      := IniRead("settings.ini", pSection, "LastNumber",  "0")
        guiCtrl_Suffix.Value   := IniRead("settings.ini", pSection, "Suffix",      "S")
        guiCtrl_DigitLen.Value := IniRead("settings.ini", pSection, "DigitLength", "7")
        UpdatePreview()
    }

    ; --- Switch Profile dropdown handler ---
    SwitchProfile(*) {
        global active_profile
        active_profile := ddProfile.Text
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")
        LoadProfileIntoGui(active_profile)
    }

    ; --- New Profile button ---
    NewProfile(*) {
        global active_profile
        newName := InputBox("Enter a name for the new profile:", "New Profile", "w300 h120").Value
        if (newName == "" || newName == 0)
            return
        ; Check duplicate
        pList := GetProfileList()
        for p in pList {
            if (p == newName) {
                MsgBox("Profile '" . newName . "' ay mayroon na!", "Babala", 48)
                return
            }
        }
        ; Save new profile with current GUI values as starting point
        SaveProfileSettings(newName, guiCtrl_Prefix.Value, 0, guiCtrl_Suffix.Value, 7)
        ; Refresh dropdown
        newList := GetProfileList()
        ddProfile.Delete()
        for p in newList
            ddProfile.Add([p])
        ; Select new profile
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

    ; --- Delete Profile button ---
    DeleteProfile(*) {
        global active_profile
        if (ddProfile.Text == "Default") {
            MsgBox("Hindi pwedeng burahin ang 'Default' profile.", "Babala", 48)
            return
        }
        pName := ddProfile.Text
        confirm := MsgBox("Sigurado ka bang gusto mong burahin ang profile '" . pName . "'?", "Confirm Delete", "YesNo 48")
        if (confirm != "Yes")
            return
        try IniDelete("settings.ini", "Profile_" . pName)
        ; Switch back to Default
        active_profile := "Default"
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")
        ; Refresh dropdown
        newList := GetProfileList()
        ddProfile.Delete()
        for p in newList
            ddProfile.Add([p])
        ddProfile.Value := 1
        LoadProfileIntoGui("Default")
    }

    ; --- Tab 2 internal functions (UNCHANGED) ---

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
        storedTxt := CtrlObj.GetText(RowNumber, 3)
        editTxt.Value := StrReplace(storedTxt, "\n", "`n")
    }

    CheckConflict(newKey, excludeRow := 0) {
        global reservedHotkeys
        for rk in reservedHotkeys {
            if (newKey = rk)
                return "'" . newKey . "' ay reserved ng KeyTap Pro system hotkey!"
        }
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
        rowToUpdate := 0
        Loop LV.GetCount() {
            if (LV.GetText(A_Index, 2) = newKey) {
                rowToUpdate := A_Index
                break
            }
        }
        conflictMsg := CheckConflict(newKey, rowToUpdate)
        if (conflictMsg != "") {
            MsgBox("⚠️ Hotkey Conflict Detected!`n`n" . conflictMsg . "`n`nPiliin ang ibang key combination.", "Conflict!", 48)
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
                realTxt := StrReplace(hkTxt, "\n", "`n")
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

    ; --- Save All Settings ---
    SaveSettings(*) {
        global prefix, current_num, suffix, digit_length, active_profile, hotkeyList

        ; Validate digit length
        dlen := Number(guiCtrl_DigitLen.Value)
        if (guiCtrl_DigitLen.Value == "" || dlen < 1) {
            MsgBox("Digit Length ay dapat 1 o higit pa!", "Error", 48)
            return
        }
        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' cannot be empty!", "Error", 48)
            return
        }

        ; Update globals
        prefix       := guiCtrl_Prefix.Value
        current_num  := Number(guiCtrl_Num.Value)
        suffix       := guiCtrl_Suffix.Value
        digit_length := dlen
        active_profile := ddProfile.Text

        ; Save active profile name
        IniWrite(active_profile, "settings.ini", "Settings", "ActiveProfile")

        ; Save current profile data
        SaveProfileSettings(active_profile, prefix, current_num, suffix, digit_length)

        ; Save hotkeys (unchanged logic)
        try IniDelete("settings.ini", "Hotkeys")
        try IniDelete("settings.ini", "HotkeyState")

        hotkeyList := []
        Loop LV.GetCount() {
            hKey      := LV.GetText(A_Index, 2)
            hTxt      := LV.GetText(A_Index, 3)
            hState    := LV.GetText(A_Index, 1)
            isEnabled := (hState == "✅ ON")
            realTxt   := StrReplace(hTxt, "\n", "`n")
            IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
            IniWrite(isEnabled ? "1" : "0", "settings.ini", "HotkeyState", hKey)
            hotkeyList.Push({key: hKey, txt: realTxt, enabled: isEnabled})
        }

        RegisterCustomHotkeys()

        MsgBox("All settings and dynamic hotkeys updated successfully!", "Success", "64 T1.5")
        mainGui.Destroy()
    }
}
