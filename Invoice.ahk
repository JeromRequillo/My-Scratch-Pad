
current_num := 46434  

F8::
    
    formatted_num := SubStr("0000000" . current_num, -6)
    
    invoice_string := "AAPI" . formatted_num . "S"
    
    Send, %invoice_string%
    
    ; Notification
    ToolTip, Sent: %invoice_string%
    SetTimer, RemoveToolTip, -2000
    
    
    current_num += 1
return

F9::
    InputBox, NewNum, Update Sequence, Input Invoice Number, , 200, 130
    if !ErrorLevel
        current_num := NewNum
return

RemoveToolTip:
    ToolTip
return