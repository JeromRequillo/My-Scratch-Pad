#Requires AutoHotkey v2.0
#SingleInstance Force

; --- SYSTEM TRAY CONFIGURATION ---
A_IconTip := "Invoice & Text Manager"
TrayRecalcMenu()

; Global Variables
global current_num := "00000"
global prefix := "AAPI"
global suffix := "S"
global mainGui := "" 
global hotkeyList := [] ; Hahawak sa mga dynamic hotkeys natin [{key: "!B", txt: "text"}, ...]
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
            
            ; Hiwalayin ang Key at Text gamit ang "=" split
            pos := InStr(A_LoopField, "=")
            if (pos > 0) {
                hkKey := SubStr(A_LoopField, 1, pos - 1)
                hkTxt := SubStr(A_LoopField, pos + 1)
                hotkeyList.Push({key: hkKey, txt: hkTxt})
            }
        }
    } catch {
        ; Default hotkeys kung bago o walang laman ang INI
        hotkeyList := [
            {key: "!S", txt: "SAMPLE TXT"},

        ]
    }
}

RegisterCustomHotkeys() {
    global hotkeyList, activeHotkeys
    
    ; 1. I-turn OFF muna ang lahat ng dating rehistradong hotkeys para walang error sa salpukan
    for hkKey, hkFunc in activeHotkeys {
        try Hotkey(hkKey, "Off")
    }
    activeHotkeys := Map() ; Linisin ang tracker

    ; 2. I-rehistro ang mga bago mula sa updated hotkeyList
    for hk in hotkeyList {
        if (hk.key != "" && hk.txt != "") {
            try {
                boundFunc := CreateHotkeyFunc(hk.txt)
                Hotkey(hk.key, boundFunc, "On")
                activeHotkeys[hk.key] := boundFunc ; I-save sa tracker para pwedeng i-off mamaya
            } catch as err {
                ; Laktawan kung may error sa format ng key para hindi mag-crash ang script
            }
        }
    }
}

; Helper function para maiwasan ang closure scope bug ng AHK v2 loops
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

; Alt + F9: Mabilisang pag-type ng invoice string
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

; Alt + F10: Bubuksan ang custom interface
!F10:: LaunchGUI()

; Alt + V: VAT Calculator
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
    
    mainGui := Gui("-MaximizeBox", "Invoice & Text Manager")
    mainGui.OnEvent("Close", (*) => mainGui.Destroy()) 
    mainGui.SetFont("s10", "Segoe UI")
    
    ; Setup Tab Navigation
    tabMenu := mainGui.Add("Tab3", "x10 y10 w480 h350", ["Invoice Config", "Custom Text Hotkeys", "VAT Calculator", "About"])
    
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
    guiCtrl_PreviewText := mainGui.Add("Text", "x20 y175 w460 h20 Center +BackgroundTrans", "Preview: " . current_preview)
    mainGui.SetFont("Norm s10", "Segoe UI")
    
    ; --- TAB 2: CUSTOM TEXT HOTKEYS (NOW DYNAMIC & SCROLLABLE!) ---
    tabMenu.UseTab(2)
    
    ; Nagdagdag tayo ng ListView table na may scrollbar automatically kapag dumami ang keys
    LV := mainGui.Add("ListView", "x20 y50 w440 h150 +Grid -Multi", ["Shortcut Key", "Text / Name to Output"])
    LV.ModifyCol(1, 100)
    LV.ModifyCol(2, 315)
    
    ; I-populate ang ListView mula sa hotkeyList variable
    for hk in hotkeyList {
        LV.Add(, hk.key, hk.txt)
    }

    ; Input Boxes para sa pagdaragdag o pag-edit ng hotkeys
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x20 y210 w80 h20", "Shortcut Key:")
    mainGui.Add("Text", "x110 y210 w200 h20", "Text to Output:")
    
    editKey := mainGui.Add("Edit", "x20 y230 w80 h25")
    editTxt := mainGui.Add("Edit", "x110 y230 w350 h25")
    
    ; Action Buttons para sa Table Control
    btnAdd := mainGui.Add("Button", "x20 y265 w100 h28", "➕ Add / Update")
    btnDel := mainGui.Add("Button", "x130 y265 w100 h28", "❌ Delete Line")
    
    ; Lagyan ng click events ang mga bagong buttons
    btnAdd.OnEvent("Click", AddUpdateHotkey)
    btnDel.OnEvent("Click", DeleteHotkey)
    LV.OnEvent("Click", SelectHotkey) ; Kapag kinlik ang row, mapupunta sa edit boxes ang text

    mainGui.SetFont("s8 cGray Italic", "Segoe UI")
    mainGui.Add("Text", "x20 y305 w440 h35", "Note: Gamitin ang '!' para sa Alt, '^' para sa Ctrl, '+' para sa Shift. (e.g. !A = Alt+A)")
    mainGui.SetFont("s10 Norm", "Segoe UI")

    ; --- TAB 3: VAT CALCULATOR INFO ---
    tabMenu.UseTab(3)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x30 y60 w400 h25 c0x0066CC", "Automated VAT Deductor Tool")
    mainGui.SetFont("s10 Norm", "Segoe UI")
    
    ; GUMAMIT NG CONTINUATION SECTION PARA SA MAHABANG TEXT:
    vatTxt := "
    (
    Paano gamitin:
    1. I-highlight/I-select ang presyo na may VAT (Kahit may kuwit o comma).
    2. Pindutin ang [ Alt + V ].
    3. Awtomatikong mada-deduct ang 12% VAT at mapapalitan ang text!

    💡 MAHALAGANG PAALALA SA VAT TOOL:
    • Numero at kuwit lang ang i-highlight: Huwag isama ang currency symbols tulad ng "₱", "PHP", o "$", pati na rin ang mga letra o spacing (e.g., "₱ 1,500" -> i-highlight lang ang "1,500"). Mag-e-error ang calculator kapag may kasamang letra.
    • Rounding off: Awtomatikong sine-set ng tool ang resulta sa dalawang decimal places (e.g., 133.93).
    • Paano mag-Undo: Kung nagkamali ka ng na-highlight o hindi mo sinasadyang mapalitan ang text, pindutin lang ang [ Ctrl + Z ] sa iyong keyboard para bumalik sa dati ang text.
    • Clipboard backup: Ang huling net amount na kinalkula ay mananatiling naka-copy sa iyong clipboard (ready to paste).
    )"
    
    mainGui.Add("Edit", "x30 y95 w420 h200 +ReadOnly +Wrap +VScroll -WantReturn", vatTxt)
    ; --- TAB 4: ABOUT & CREDITS ---
    tabMenu.UseTab(4)
    mainGui.SetFont("bold s11", "Segoe UI")
    mainGui.Add("Text", "x25 y50 w400 h25 c0x0066CC", "Auto-Increment & Macro Manager")
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.Add("Text", "x25 y75 w400 h18", "Version: 4.0.0 (Dynamic ListView)")
    mainGui.Add("Text", "x25 y95 w400 h18", "Developer: Jerom Requillo")
    
    mainGui.SetFont("italic s9", "Segoe UI")
    mainGui.Add("Link", "x25 y120 w400 h20", 'GitHub: <a href="https://github.com/JeromRequillo">@JeromRequillo</a>')
    mainGui.Add("Link", "x25 y140 w400 h20", 'Repository: <a href="https://github.com/JeromRequillo/Ultimate-System-Master">JeromRequillo/Ultimate-System-Master</a>')
    
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
    
    mainGui.Add("Edit", "x25 y170 w420 h130 +ReadOnly +Wrap +VScroll -WantReturn", aboutTxt)
    
    ; CRITICAL FIX: Sinasabi nito sa GUI na tapos na ang mga elements sa loob ng Tabs
    tabMenu.UseTab()
    
    ; --- BOTTOM BUTTONS (Naka-anchor na sa pinakailalim ng Main Window) ---
    mainGui.SetFont("Norm s10", "Segoe UI")
    btnSave := mainGui.Add("Button", "x130 y375 w110 h32 Default", "Save All Changes")
    btnSave.OnEvent("Click", SaveSettings)
    
    btnCancel := mainGui.Add("Button", "x260 y375 w110 h32", "Close Window")
    btnCancel.OnEvent("Click", (*) => mainGui.Destroy())
    
    mainGui.Show("w500 h420")
    ; --- GUI INTERNAL FUNCTIONS ---
    
    UpdatePreview(*) {
        temp_preview := GenerateInvoice(guiCtrl_Prefix.Value, guiCtrl_Num.Value, guiCtrl_Suffix.Value)
        guiCtrl_PreviewText.Value := "Preview: " . temp_preview
    }

    SelectHotkey(CtrlObj, RowNumber) {
        if (RowNumber == 0)
            return
        editKey.Value := CtrlObj.GetText(RowNumber, 1)
        editTxt.Value := CtrlObj.GetText(RowNumber, 2)
    }

    AddUpdateHotkey(*) {
        if (editKey.Value == "" || editTxt.Value == "") {
            MsgBox("Paki-sulat muna ang Shortcut Key at Text!", "Babala", 48)
            return
        }
        
        rowToUpdate := 0
        Loop LV.GetCount() {
            if (LV.GetText(A_Index, 1) = editKey.Value) {
                rowToUpdate := A_Index
                break
            }
        }
        
        if (rowToUpdate > 0) {
            LV.Modify(rowToUpdate, , editKey.Value, editTxt.Value)
        } else {
            LV.Add(, editKey.Value, editTxt.Value)
        }
        
        editKey.Value := ""
        editTxt.Value := ""
    }

    DeleteHotkey(*) {
        selectedRow := LV.GetNext()
        if (selectedRow == 0) {
            MsgBox("Pumili muna ng hotkey sa listahan na gustong burahin.", "Babala", 48)
            return
        }
        LV.Delete(selectedRow)
        editKey.Value := ""
        editTxt.Value := ""
    }

    SaveSettings(*) {
        ; Tinawag natin ang lahat ng global variables na kailangang i-update
        global prefix, current_num, suffix, hotkeyList

        if (guiCtrl_Num.Value == "") {
            MsgBox("'Next Number' cannot be empty!", "Error", 48)
            return
        }
        
        ; 1. I-update ang Invoice settings sa global memory
        prefix := guiCtrl_Prefix.Value
        current_num := Format("{:05}", Number(guiCtrl_Num.Value)) 
        suffix := guiCtrl_Suffix.Value
        
        ; Isulat sa INI file ang Invoice settings
        IniWrite(prefix, "settings.ini", "Settings", "Prefix")
        IniWrite(Number(guiCtrl_Num.Value), "settings.ini", "Sequence", "LastNumber")
        IniWrite(suffix, "settings.ini", "Settings", "Suffix")
        
        ; 2. I-clear at i-update ang Hotkeys section sa INI at Global Memory
        try IniDelete("settings.ini", "Hotkeys")
        
        hotkeyList := [] ; Reset ang global list bago punuin uli
        Loop LV.GetCount() {
            hKey := LV.GetText(A_Index, 1)
            hTxt := LV.GetText(A_Index, 2)
            
            IniWrite(hTxt, "settings.ini", "Hotkeys", hKey)
            hotkeyList.Push({key: hKey, txt: hTxt})
        }
        
        ; 3. CRITICAL FIX: I-re-register ang custom hotkeys gamit ang bagong listahan
        RegisterCustomHotkeys()
        
        MsgBox("All settings and dynamic hotkeys updated successfully!", "Success", "64 T1.5")
        mainGui.Destroy()
    }
}