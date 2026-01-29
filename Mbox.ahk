; === Настройки ===
DefaultInterval := 500             ; Интервал по умолчанию для новых групп (мс)
KeyDelay := 0                      ; Задержка между клавишами в последовательности (мс)
UseSimulation := false             ; true = Send (симуляция), false = PostMessage (прямая отправка)
ShowStatusGUI := true              ; Показывать окно статуса (true/false)
StatusPosX := 0                    ; X позиция окна статуса
StatusPosY := 0                    ; Y позиция окна статуса
IndicatorEnabled := true           ; Показывать точку-индикатор (true/false)
IndicatorBlink := false            ; Мигать (true/false). Если false: просто зелёный/красный
IndicatorSize := 10                ; Размер точки (px)
IndicatorPosX := 0                 ; X позиция точки
IndicatorPosY := 0                 ; Y позиция точки
IndicatorBlinkInterval := 1000     ; Интервал мигания (мс)

; === Горячие клавиши ===
StartStopKey := "NumpadEnter"      ; Клавиша запуска и остановки 
ChangeKeysKey := "NumpadAdd"       ; Клавиша для сброса и выбора новых клавиш
ExitKey := "NumpadSub"             ; Клавиша выхода из скрипта
ToggleGUIKey := "NumpadDot"        ; Клавиша для показа/скрытия окна статуса

; === Системные настройки ===
#Persistent
SetBatchLines -1
#UseHook

; === Глобальные переменные ===
IsChoosingKeys := False
KeysArray := ""
Toggle := False
Groups := []
CurrentGroup := 1
TotalGroups := 0
IndicatorBlinkState := 0
IndicatorDotHwnd := 0

; === Динамические горячие клавиши ===
Hotkey, % "$" . StartStopKey, ToggleAction
Hotkey, % "$" . ChangeKeysKey, RechooseKeys
Hotkey, % "$" . ToggleGUIKey, ToggleStatusGUI
Hotkey, % ExitKey, ExitApp

InitIndicator()

SetMainHotkeys("Off")
GoSub, ChooseKeys
Return

SetMainHotkeys(state) {
    Global StartStopKey, ChangeKeysKey, ToggleGUIKey
    Hotkey, % "$" . StartStopKey, ToggleAction, %state%
    Hotkey, % "$" . ChangeKeysKey, RechooseKeys, %state%
    Hotkey, % "$" . ToggleGUIKey, ToggleStatusGUI, %state%
}

; === Выбор клавиш ===
ChooseKeys:
    IsChoosingKeys := True
    SetMainHotkeys("Off")
    Gui, Destroy
	Gui, Font, s10
    titleText := "Group " . CurrentGroup . " - Click on the buttons you want the script to press."
    Gui, Add, Text, x10 y10 w380 Center, %titleText%
    Gui, Add, Edit, x25 y35 vKeyList w350 r5 ReadOnly
    Gui, Add, Text, x25 y135, Interval (ms):
    Gui, Add, Edit, x105 y130 vGroupInterval w60, %DefaultInterval%
    Gui, Add, Button, x25 y160 gConfirmKeys, Confirm Selection
    Gui, Add, Button, x+10 gClearKeys, Clear buttons
    Gui, Add, Button, x+10 gAddAnotherGroup, Add Another Group
    Gui, Show, w400 h200, Key Selection
    OnMessage(0x112, "GuiClose")
    KeysArray := ""
    OnMessage(0x100, "KeyDownMsg")
    OnMessage(0x104, "KeyDownMsg")
Return

GuiClose:
    ExitApp
Return

ClearKeys:
    KeysArray := ""
    GuiControl,, KeyList
Return

ConfirmKeys:
    IsChoosingKeys := False
    OnMessage(0x100, False), OnMessage(0x104, False)
    Gui, Submit, NoHide
    GoSub ReEnterPID
Return

AddAnotherGroup:
    IsChoosingKeys := False
    OnMessage(0x100, False), OnMessage(0x104, False)
    Gui, Submit, NoHide
    SaveCurrentGroup()
    CurrentGroup += 1
    GoSub, ChooseKeys
Return

SaveCurrentGroup() {
    Global KeysArray, GroupInterval, DefaultInterval, Groups, TotalGroups
    Group := {}
    Group.keys := KeysArray
    Group.interval := GroupInterval ? GroupInterval : DefaultInterval
    Groups.Push(Group)
    TotalGroups += 1
}

; === Ввод PID / ProcessName ===
ReEnterPID:
    TargetPIDArray := [], TargetProcessArray := [], TargetHwndArray := []
    TotalProcesses := 0
    SetMainHotkeys("Off")
    promptText := "Enter PID or process name.`n`n"
    promptText .= "Example.`n"
	promptText .= "PID:[1234 5678][1234.5678].`n"
    promptText .= "Name:[notepad explorer][notepad.explorer]."

    InputBox, TargetInput, Enter Process Info, %promptText%,
    If ErrorLevel {
        GoSub, ChooseKeys
        Return
    }

    StringSplit, TargetPIDArray, TargetInput, `, `. %A_Space%

    Loop %TargetPIDArray0% {
        Current := Trim(TargetPIDArray%A_Index%)
        If (!Current)
            Continue
        If (Current ~= "^\d+$") {
            Process, Exist, %Current%
            If !ErrorLevel
                MsgBox, PID %Current% not found!
            Else {
                DetectHiddenWindows, On
                hWnd := WinExist("ahk_pid " Current)
                DetectHiddenWindows, Off
                If hWnd {
                    WinGet, ProcessName, ProcessName, ahk_pid %Current%
                    TotalProcesses += 1
                    TargetProcessArray[TotalProcesses] := Trim(ProcessName)
                    TargetPIDArray[TotalProcesses] := Current
                    TargetHwndArray[TotalProcesses] := hWnd
                }
            }
        } Else {
            ProcessName := RegExReplace(Current, "i)\.exe$", "") ".exe"
            Process, Exist, %ProcessName%
            If !ErrorLevel
                MsgBox, Process "%ProcessName%" not found!
            Else {
                WinGet, hWndList, List, ahk_exe %ProcessName%
                If (!hWndList)
                    MsgBox, No window for "%ProcessName%"!
                Else Loop %hWndList% {
                    WinGet, ProcessPID, PID, % "ahk_id " . hWndList%A_Index%
                    TotalProcesses += 1
                    TargetProcessArray[TotalProcesses] := Trim(ProcessName)
                    TargetPIDArray[TotalProcesses] := ProcessPID
                    TargetHwndArray[TotalProcesses] := hWndList%A_Index%
                }
            }
        }
    }

    If (TotalProcesses = 0) {
        MsgBox, No valid processes found! Please try again.
        IsChoosingKeys := True
        OnMessage(0x100, "KeyDownMsg")
        OnMessage(0x104, "KeyDownMsg")
        GoSub, ReEnterPID
        Return
    }

    SaveCurrentGroup()

; === GUI статуса ===
    Gui, Destroy
    Gui, +AlwaysOnTop +ToolWindow -Caption +LastFound
    Gui, Color, 1E1E1E
    Gui, Font, s10 cRed, Consolas
    fullStatus := BuildStatusText("OFF")
    Gui, Add, Text, vStatus, %fullStatus%
    if (ShowStatusGUI)
        Gui, Show, x%StatusPosX% y%StatusPosY% NoActivate AutoSize, Multi-PID Control
    InitIndicator()
    SetMainHotkeys("On")
Return

; === Обновление статуса ===
BuildStatusText(statusMode) {
    Global Groups, TotalGroups, TargetProcessArray, TotalProcesses, TargetPIDArray, KeyDelay
    statusText := "Status: " statusMode
    maxLen := StrLen(statusText)
    Loop %TotalGroups% {
        keys := Groups[A_Index].keys
        if (!RegExMatch(keys, "^\{.*\}$"))
            keys := "{" keys "}"
        keysForCount := Groups[A_Index].keys
        StringSplit, keyArray, keysForCount, %A_Space%
        totalDelay := (keyArray0 - 1) * KeyDelay
        realInterval := Groups[A_Index].interval + totalDelay
        keyText := "G" A_Index ": " keys " (" realInterval "ms)"
        if (StrLen(keyText) > maxLen)
            maxLen := StrLen(keyText)
    }
    if (TotalProcesses > 0) {
        Loop %TotalProcesses% {
            processText := "PID: " Trim(TargetPIDArray[A_Index]) " (" Trim(TargetProcessArray[A_Index]) ")"
            if (StrLen(processText) > maxLen)
                maxLen := StrLen(processText)
        }
    }
    paddingLen := maxLen + 2
    border := "+"
    Loop %paddingLen%
        border .= "-"
    border .= "+"
    statusPadding := ""
    Loop % (maxLen - StrLen(statusText))
        statusPadding .= " "
    fullStatus := border . "`n| " statusText statusPadding " |`n"
    Loop %TotalGroups% {
        keys := Groups[A_Index].keys
        if (!RegExMatch(keys, "^\{.*\}$"))
            keys := "{" keys "}"
        keysForCount := Groups[A_Index].keys
        StringSplit, keyArray, keysForCount, %A_Space%
        totalDelay := (keyArray0 - 1) * KeyDelay
        realInterval := Groups[A_Index].interval + totalDelay
        keyText := "G" A_Index ": " keys " (" realInterval "ms)"
        padding := ""
        Loop % (maxLen - StrLen(keyText))
            padding .= " "
        fullStatus .= "| " keyText padding " |"
        If (A_Index < TotalGroups)
            fullStatus .= "`n"
    }
    if (TotalProcesses > 0) {
        fullStatus .= "`n" . border . "`n"
        Loop %TotalProcesses% {
            processText := "PID: " Trim(TargetPIDArray[A_Index]) " (" Trim(TargetProcessArray[A_Index]) ")"
            processPadding := ""
            Loop % (maxLen - StrLen(processText))
                processPadding .= " "
            fullStatus .= "| " processText processPadding " |"
            If (A_Index < TotalProcesses)
                fullStatus .= "`n"
        }
    }
    Return fullStatus . "`n" . border
}

UpdateStatus() {
    Global Toggle, ShowStatusGUI
    if (!ShowStatusGUI)
        Return
    color := Toggle ? "Green" : "Red"
    GuiControl, +c%color%, Status
    GuiControl,, Status, % BuildStatusText(Toggle ? "ACTIVE" : "OFF")
}

InitIndicator() {
    Global IndicatorEnabled, IndicatorPosX, IndicatorPosY, IndicatorSize
    Global IndicatorBlinkState, IndicatorDotHwnd

    if (!IndicatorEnabled) {
        Gui, Indicator:Destroy
        SetTimer, IndicatorBlinkTimer, Off
        return
    }

    Gui, Indicator:Destroy
    Gui, Indicator:+AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound
    Gui, Indicator:Margin, 0, 0
    Gui, Indicator:Color, 000000
    Gui, Indicator:Add, Progress, hwndIndicatorDotHwnd w%IndicatorSize% h%IndicatorSize% cRed Background000000 Range0-100, 100
    Gui, Indicator:Show, x%IndicatorPosX% y%IndicatorPosY% NoActivate
    IndicatorBlinkState := 0
    UpdateIndicator()
}

UpdateIndicator() {
    Global Toggle, IndicatorEnabled, IndicatorBlink, IndicatorBlinkInterval
    Global IndicatorBlinkState, IndicatorDotHwnd

    if (!IndicatorEnabled) {
        SetTimer, IndicatorBlinkTimer, Off
        return
    }

    if (IndicatorBlink) {
        IndicatorBlinkState := 1
        color := Toggle ? "Green" : "Red"
        GuiControl, Indicator:+c%color%, %IndicatorDotHwnd%
        SetTimer, IndicatorBlinkTimer, %IndicatorBlinkInterval%
    } else {
        SetTimer, IndicatorBlinkTimer, Off
        IndicatorBlinkState := 0
        color := Toggle ? "Green" : "Red"
        GuiControl, Indicator:+c%color%, %IndicatorDotHwnd%
    }
}

IndicatorBlinkTimer:
    Global Toggle, IndicatorEnabled, IndicatorBlink
    Global IndicatorBlinkState, IndicatorDotHwnd
    if (!IndicatorEnabled || !IndicatorBlink) {
        SetTimer, IndicatorBlinkTimer, Off
        IndicatorBlinkState := 0
        GuiControl, Indicator:+cRed, %IndicatorDotHwnd%
        return
    }
    IndicatorBlinkState := !IndicatorBlinkState
    if (Toggle) {
        color := IndicatorBlinkState ? "Green" : "0A2A0A"
    } else {
        color := IndicatorBlinkState ? "Red" : "2A0A0A"
    }
    GuiControl, Indicator:+c%color%, %IndicatorDotHwnd%
Return

; === Подпрограмма: запуск/остановка ===
ToggleAction:
    if (IsChoosingKeys || TotalProcesses = 0 || TotalGroups = 0) {
        Return
    }
    Toggle := !Toggle
    UpdateStatus()
    UpdateIndicator()
    Loop % TotalGroups {
        If (Toggle) {
            SendGroupKeys(A_Index)
            SetTimer, % "SendGroup" . A_Index, % Groups[A_Index].interval
        } Else {
            SetTimer, % "SendGroup" . A_Index, Off
        }
    }
Return

; === Подпрограмма: перенастройка клавиш ===
RechooseKeys:
    If (IsChoosingKeys) {
        MsgBox, Finish key selection first.
        Return
    }
    Loop % TotalGroups
        SetTimer, % "SendGroup" . A_Index, Off
    Groups := [], TotalGroups := 0, CurrentGroup := 1
    KeysArray := ""
    Toggle := False
    UpdateStatus()
    UpdateIndicator()
    SetMainHotkeys("Off")
    GoSub, ChooseKeys
Return

; === Подпрограмма: переключение показа/скрытия GUI статуса ===
ToggleStatusGUI:
    If (IsChoosingKeys || TotalProcesses = 0)
        Return
    If (ShowStatusGUI := !ShowStatusGUI)
    {
        Gui, Show, NoActivate
        UpdateStatus()
    }
    Else
    {
        Gui, Hide
    }
Return

; === Отправка клавиш для групп ===
SendGroup1:
SendGroup2:
SendGroup3:
SendGroup4:
SendGroup5:
    groupNum := RegExReplace(A_ThisLabel, "SendGroup", "")
    SendGroupKeys(groupNum)
Return

; === Отправка клавиш ===
SendGroupKeys(groupIndex) {
    Global Groups, TotalProcesses, TargetHwndArray, KeyDelay, UseSimulation, Toggle
    if (groupIndex > Groups.Length() || !Toggle)
        Return
    keysToSend := Groups[groupIndex].keys
    keysArray := ParseKeys(keysToSend)
    If UseSimulation
    {
        Loop % keysArray.Length()
        {
            If (!Toggle)
                Return
            currentKey := keysArray[A_Index]
            If (RegExMatch(currentKey, "i)^\{Space\}$"))
            {
                Loop %TotalProcesses%
                {
                    hWndTarget := TargetHwndArray[A_Index]
                    ControlSend, , {Space}, ahk_id %hWndTarget%
                }
                Sleep, %KeyDelay%
                Continue
            }
            keyStr := RegExReplace(currentKey, "i)\{(.+)\}", "$1")
            If (InStr(keyStr, "+"))
            {
                modifiers := ""
                mainKey := keyStr
                If (RegExMatch(keyStr, "i)^(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", match))
                {
                    modifiers := match1
                    mainKey := match2
                }
                Else If (RegExMatch(keyStr, "i)^(.+)\+(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", match))
                {
                    modifiers := match1 . "+" . match2
                    mainKey := match3
                }
                sendFormat := RegExReplace(currentKey, "i)\{Shift\+", "+")
                sendFormat := RegExReplace(sendFormat, "i)\{Ctrl\+", "^")
                sendFormat := RegExReplace(sendFormat, "i)\{Alt\+", "!")
                sendFormat := RegExReplace(sendFormat, "i)\{Win\+", "#")
                sendFormat := RegExReplace(sendFormat, "i)\{LWin\+", "#")
                sendFormat := RegExReplace(sendFormat, "i)\{RWin\+", "#")
                sendFormat := RegExReplace(sendFormat, "\}", "")
                Loop %TotalProcesses%
                {
                    hWndTarget := TargetHwndArray[A_Index]
                    If (StrLen(mainKey) = 1)
                    {
                        ControlSend, , {Raw}%sendFormat%, ahk_id %hWndTarget%
                    }
                    Else
                    {
                        ControlSend, , %sendFormat%, ahk_id %hWndTarget%
                    }
                }
            }
            Else If (StrLen(keyStr) = 1 && keyStr != " ")
            {
                Loop %TotalProcesses%
                {
                    hWndTarget := TargetHwndArray[A_Index]
                    ControlSend, , {Raw}%keyStr%, ahk_id %hWndTarget%
                }
            }
            Else
            {
                Loop %TotalProcesses%
                {
                    hWndTarget := TargetHwndArray[A_Index]
                    ControlSend, , %currentKey%, ahk_id %hWndTarget%
                }
            }
            Sleep, %KeyDelay%
        }
        Return
    }
    Loop % keysArray.Length()
    {
        If (!Toggle)
            Return
        currentKey := keysArray[A_Index]
        If (RegExMatch(currentKey, "i)^\{Space\}$"))
        {
            Loop %TotalProcesses%
            {
                DllCall("PostMessage", "Ptr", TargetHwndArray[A_Index], "UInt", 0x0102, "Ptr", 0x20, "Ptr", 0x00000001)
            }
            Sleep, %KeyDelay%
            Continue
        }
        keyStr := RegExReplace(currentKey, "i)\{(.+)\}", "$1")
        If (InStr(keyStr, "+"))
        {
            modifiers := ""
            mainKey := keyStr
            If (RegExMatch(keyStr, "i)^(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", match))
            {
                modifiers := match1
                mainKey := match2
            }
            Else If (RegExMatch(keyStr, "i)^(.+)\+(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", match))
            {
                modifiers := match1 . "+" . match2
                mainKey := match3
            }
            If (StrLen(mainKey) = 1)
            {
                VarSetCapacity(char, 4, 0)
                StrPut(mainKey, &char, "UTF-16")
                charCode := NumGet(char, 0, "UShort")
                Loop %TotalProcesses%
                {
                    hWndTarget := TargetHwndArray[A_Index]
                    If (InStr(modifiers, "Shift"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x100, "Ptr", 0x10, "Ptr", 0)
                    If (InStr(modifiers, "Ctrl"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x100, "Ptr", 0x11, "Ptr", 0)
                    If (InStr(modifiers, "Alt"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x100, "Ptr", 0x12, "Ptr", 0)
                    DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x0102, "Ptr", charCode, "Ptr", 0x00000001)
                    If (InStr(modifiers, "Alt"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x101, "Ptr", 0x12, "Ptr", 0x80000000)
                    If (InStr(modifiers, "Ctrl"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x101, "Ptr", 0x11, "Ptr", 0x80000000)
                    If (InStr(modifiers, "Shift"))
                        DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x101, "Ptr", 0x10, "Ptr", 0x80000000)
                }
            }
            Else
            {
                modifiers := ""
                mainKey := ""
                StringSplit, keyParts, keyStr, +
                Loop %keyParts0%
                {
                    part := Trim(keyParts%A_Index%)
                    If (part = "Shift" || part = "Ctrl" || part = "Alt" || part = "Win" || part = "LWin" || part = "RWin")
                    {
                        modifiers .= (modifiers ? " " : "") . part
                    }
                    Else
                    {
                        mainKey := part
                    }
                }
                If (mainKey != "")
                {
                    vkMain := GetKeyVK(mainKey)
                    If vkMain
                    {
                        Loop %TotalProcesses%
                        {
                            hWndTarget := TargetHwndArray[A_Index]
                            StringSplit, modParts, modifiers, %A_Space%
                            Loop %modParts0%
                            {
                                modVk := GetKeyVK(modParts%A_Index%)
                                If modVk
                                    DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x100, "Ptr", modVk, "Ptr", 0)
                            }
                            DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x100, "Ptr", vkMain, "Ptr", 0)
                            DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x101, "Ptr", vkMain, "Ptr", 0x80000000)
                            Loop %modParts0%
                            {
                                modVk := GetKeyVK(modParts%A_Index%)
                                If modVk
                                    DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x101, "Ptr", modVk, "Ptr", 0x80000000)
                            }
                        }
                    }
                }
            }
            Sleep, %KeyDelay%
        }
        Else If (StrLen(keyStr) = 1 && keyStr != " ")
        {
            VarSetCapacity(char, 4, 0)
            StrPut(keyStr, &char, "UTF-16")
            charCode := NumGet(char, 0, "UShort")
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                DllCall("PostMessage", "Ptr", hWndTarget, "UInt", 0x0102, "Ptr", charCode, "Ptr", 0x00000001)
            }
            Sleep, %KeyDelay%
        }
        Else
        {
            vk := GetKeyVK(keyStr)
            If vk
            {
                Loop %TotalProcesses%
                {
                    DllCall("PostMessage", "Ptr", TargetHwndArray[A_Index], "UInt", 0x100, "Ptr", vk, "Ptr", 0)
                    DllCall("PostMessage", "Ptr", TargetHwndArray[A_Index], "UInt", 0x101, "Ptr", vk, "Ptr", 0x80000000)
                }
            }
            Sleep, %KeyDelay%
        }
    }
}

; === Парсинг строки клавиш с учетом фигурных скобок ===
ParseKeys(keysString) {
    keysArray := []
    pos := 1
    len := StrLen(keysString)
    While (pos <= len)
    {
        ; Пропускаем пробелы
        While (pos <= len && SubStr(keysString, pos, 1) = " ")
            pos++
        If (pos > len)
            Break
        
        ; Проверяем, начинается ли токен с фигурной скобки
        If (SubStr(keysString, pos, 1) = "{")
        {
            ; Ищем закрывающую скобку
            endPos := InStr(keysString, "}", false, pos)
            If (endPos)
            {
                token := SubStr(keysString, pos, endPos - pos + 1)
                keysArray.Push(token)
                pos := endPos + 1
            }
            Else
            {
                ; Если закрывающей скобки нет, берем до конца строки
                token := SubStr(keysString, pos)
                keysArray.Push(token)
                Break
            }
        }
        Else
        {
            ; Обычный токен (до следующего пробела или фигурной скобки)
            endPos := pos
            While (endPos <= len)
            {
                char := SubStr(keysString, endPos, 1)
                If (char = " " || char = "{")
                    Break
                endPos++
            }
            token := SubStr(keysString, pos, endPos - pos)
            If (token != "")
                keysArray.Push(token)
            pos := endPos
        }
    }
    Return keysArray
}

; === Получение VK-кода ===
GetKeyVK(key) {
    static VKTable := {}
    If !VKTable.Count() {
        Loop 26
            VKTable[Chr(64 + A_Index)] := 0x41 + (A_Index - 1)
        Loop 10
            VKTable[A_Index - 1] := 0x30 + (A_Index - 1)
        VKTable["Esc"] := VKTable["Escape"] := 0x1B
        VKTable["Backspace"] := 0x08, VKTable["Tab"] := 0x09, VKTable["Clear"] := 0x0C
        VKTable["Enter"] := 0x0D, VKTable["Shift"] := 0x10, VKTable["Ctrl"] := 0x11, VKTable["Alt"] := 0x12
        VKTable["Space"] := 0x20, VKTable["Left"] := 0x25, VKTable["Up"] := 0x26
        VKTable["Right"] := 0x27, VKTable["Down"] := 0x28
        Loop 12
            VKTable["F" A_Index] := 0x70 + (A_Index - 1)
        Loop 10
            VKTable["Numpad" A_Index - 1] := 0x60 + (A_Index - 1)
        VKTable["Multiply"] := 0x6A, VKTable["Add"] := 0x6B, VKTable["Separator"] := 0x6C
        VKTable["Subtract"] := 0x6D, VKTable["Decimal"] := 0x6E, VKTable["Divide"] := 0x6F
        VKTable["NumpadEnter"] := 0x0D
        VKTable[";"] := 0xBA, VKTable[":"] := 0xBA, VKTable["="] := 0xBB, VKTable["+"] := 0xBB
        VKTable[","] := 0xBC, VKTable["<"] := 0xBC, VKTable["-"] := 0xBD, VKTable["_"] := 0xBD
        VKTable["."] := 0xBE, VKTable[">"] := 0xBE, VKTable["/"] := 0xBF, VKTable["?"] := 0xBF
        VKTable["`"] := 0xC0, VKTable["~"] := 0xC0, VKTable["["] := 0xDB, VKTable["{"] := 0xDB
        VKTable["\"] := 0xDC, VKTable["|"] := 0xDC, VKTable["]"] := 0xDD, VKTable["}"] := 0xDD
        VKTable["'"] := 0xDE, VKTable[""""] := 0xDE
    }
    Return VKTable.HasKey(key) ? VKTable[key] : ""
}

; === Обработка WM_KEYDOWN ===
KeyDownMsg(wParam, lParam) {
    Global KeysArray, IsChoosingKeys
    If (!IsChoosingKeys)
        Return
    ControlGetFocus, FocusedControl
    If (FocusedControl = "Edit2")
        Return
    vk := wParam
    scanCode := (lParam >> 16) & 0xFF
    extended := (lParam >> 24) & 0x01
    isCtrlPressed := GetKeyState("Ctrl", "P")
    isAltPressed := GetKeyState("Alt", "P") 
    isShiftPressed := GetKeyState("Shift", "P")
    isWinPressed := GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
    if (vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0x5B || vk = 0x5C)
        Return
    keyName := ""
    if ((vk >= 0x60 && vk <= 0x6F)) {
        keyName := (vk = 0x6E) ? "Decimal" : (vk = 0x6F) ? "Divide"
                    : (vk = 0x6A) ? "Multiply" : (vk = 0x6B) ? "Add"
                    : (vk = 0x6C) ? "Separator" : (vk = 0x6D) ? "Subtract"
                    : "Numpad" (vk - 0x60)
    }
    else if (vk == 0x0D && extended)
        keyName := "NumpadEnter"
    else {
        keyName := ""
        static KeyList := ["LButton","RButton","MButton","XButton1","XButton2","Backspace","Tab","Clear","Enter","Shift","Ctrl","Alt","Pause","CapsLock","Esc","Space","PageUp","PageDown","End","Home","Left","Up","Right","Down","PrintScreen","Insert","Delete","LWin","RWin","Apps","Sleep","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"]
        For k, v in KeyList
            If (vk == GetKeyVK(v)) {
                keyName := v
                Break
            }
    if (!keyName) {
        VarSetCapacity(scancode, 4), DllCall("MapVirtualKey", "UInt", vk, "Int", 0, "Ptr", &scancode)
        scancode := NumGet(scancode, 0, "UInt")
        VarSetCapacity(keyState, 256, 0), DllCall("GetKeyboardState", "Ptr", &keyState)
        VarSetCapacity(char, 4, 0), res := DllCall("ToUnicode", "UInt", vk, "UInt", scancode, "Ptr", &keyState, "Ptr", &char, "Int", 2, "UInt", 0)
        if (res > 0) {
            char := StrGet(&char, res, "UTF-16")
            keyName := (extended && (scancode >= 0x47 && scancode <= 0x53)) ? "Numpad" char : char
        } else if ((vk >= 0x41 && vk <= 0x5A) || (vk >= 0x30 && vk <= 0x39)) {
            keyName := Chr(vk)
        }
    }
    }
    If (keyName != "") {
        combination := (isWinPressed ? "Win+" : "") . (isCtrlPressed ? "Ctrl+" : "") . (isAltPressed ? "Alt+" : "") . (isShiftPressed ? "Shift+" : "") . keyName
        combination := (InStr(combination, "+") || StrLen(keyName) > 1 || RegExMatch(keyName, "^[A-Z]")) ? "{" combination "}" : keyName
        KeysArray .= (KeysArray ? " " : "") combination
        GuiControl,, KeyList, %KeysArray%
    }
}

; === Подпрограмма выхода ===
ExitApp:
    ExitApp
Return