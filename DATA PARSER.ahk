#Requires AutoHotkey v2.0
#SingleInstance Force

; Shortcut Key: Windows + Shift + B 
#+b:: {
    ParseSuzukiGroupData()
}

ParseSuzukiGroupData() {
    if (A_Clipboard == "") {
        MsgBox("Mag-copy ka muna ng text, 😂", "Walang Data", 48)
        return
    }
    
    rawData := A_Clipboard
    excelOutput := ""
    
    currentChassis := ""
    lastPrintedChassis := ""  
    
    
    tempPcs := ""
    tempStatus := ""
    
    
    Loop Parse, rawData, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line == "")
            continue
            
        
        isLongVIN := RegExMatch(line, "i)^[A-Z0-9]{17,18}$", &matchChassis)
        isShortChassis := RegExMatch(line, "i)^(MH|DA|JB|MK|HE|HA|MA)[0-9]{2}[A-Z][0-9]{10,12}$", &matchShort) || RegExMatch(line, "i)^mhync22s[0-9]+$", &matchCustom)
        
        if (isLongVIN || isShortChassis) {
            currentChassis := StrUpper(line)
            
            tempPcs := ""
            tempStatus := ""
            continue
        }
        
        
        if !RegExMatch(line, "i)^[0-9][A-Z0-9\-]{9,15}$", &_) { 
            
            
            if RegExMatch(line, "i)^(\d+)\s*pc", &matchPcs) {
                tempPcs := matchPcs[1]
            } else {
                tempPcs := "1" 
            }
            
            
            if RegExMatch(line, "i)-(a/s|b/o|p/s)$", &matchStatus) {
                statusWord := StrUpper(matchStatus[1])
                if (statusWord == "A/S")
                    tempStatus := "ALL SUPPLY"
                else if (statusWord == "B/O")
                    tempStatus := "BACK ORDER"
                else if (statusWord == "P/S")
                    tempStatus := "PARTIAL SUPPLY"
            } else {
                tempStatus := "ALL SUPPLY" 
            }
            
            continue 
        }
        
        
        if RegExMatch(line, "i)^[0-9][A-Z0-9\-]{9,15}$", &matchPart) {
            partNum := StrUpper(matchPart[0])
            
            
            cleanPart := StrReplace(partNum, "-")
            cleanLen := StrLen(cleanPart)
            
            if (cleanLen == 10 || cleanLen == 11) {
                if !(SubStr(partNum, -1) == "-") {
                    partNum := partNum . "-000"
                } else {
                    partNum := partNum . "000"
                }
            }
            
            
            if (tempPcs == "") {
                tempPcs := "1"
            }
            if (tempStatus == "") {
                tempStatus := "All Supply"
            }
            
            
            if (currentChassis != "" && currentChassis != lastPrintedChassis) {
                displayChassis := currentChassis
                lastPrintedChassis := currentChassis
            } else {
                displayChassis := ""
            }
            
            
            if (currentChassis != "") {
                excelOutput .= displayChassis . "`t" . partNum . "`t" . tempPcs . "`t" . tempStatus . "`n"
            }
            
            
            tempPcs := ""
            tempStatus := ""
        }
    }
    
    if (excelOutput == "") {
        ToolTip("❌ No Valid Data Found!")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    
    A_Clipboard := excelOutput
    SoundBeep(1500, 300)
    ToolTip("⚡ All Goods!.")
    SetTimer(() => ToolTip(), -3000)
}