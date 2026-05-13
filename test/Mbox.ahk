; === Настройки ===
DefaultInterval := 500                  ; Интервал по умолчанию для новых групп (мс)
KeyDelay := 0                           ; Задержка между клавишами в последовательности (мс)
; UseSimulation=true  — симуляция: клавиши и мышь — ControlSend / ControlClick на тот же HWND цели (TargetHwndArray).
; UseSimulation=false — прямая отправка: клавиши — PostMsgToFocus / PostTapVkFocused; мышь — те же три WM через PostMsgToFocus (MOVE + DOWN + UP).
UseSimulation := false
ShowStatusGUI := true                   ; Показывать окно статуса (true/false)
StatusPosX := 0                         ; X позиция окна статуса
StatusPosY := 0                         ; Y позиция окна статуса
IndicatorEnabled := true                ; Показывать точку-индикатор (true/false)
IndicatorBlink := false                 ; Мигать (true/false). Если false: просто зелёный/красный
IndicatorSize := 10                     ; Размер точки (px)
IndicatorPosX := 0                      ; X позиция точки
IndicatorPosY := 0                      ; Y позиция точки
IndicatorBlinkInterval := 1000          ; Интервал мигания (мс)
IndicatorColorOn := "Green"             ; Цвет точки при активном скрипте
IndicatorColorOff := "Red"              ; Цвет точки при остановленном скрипте
IndicatorBgColor := "000000"            ; Цвет фона мини-индикатора
IndicatorBorderColorLocked := "Yellow"  ; Цвет обводки при LOCKED
IndicatorBorderThickness := 1           ; Толщина обводки при LOCKED (px)

; === Горячие клавиши ===
StartStopKey := "NumpadEnter"           ; Клавиша запуска и остановки 
ChangeKeysKey := "NumpadAdd"            ; Клавиша для сброса и выбора новых клавиш
ExitKey := "NumpadSub"                  ; Клавиша выхода из скрипта
ToggleGUIKey := "NumpadDot"             ; Клавиша для показа/скрытия окна статуса
DisableAllKey := "NumpadMult"           ; Клавиша полного отключения/включения всех биндов
ToggleModeKey := "Numpad0"              ; Переключение: симуляция (ControlSend) / прямая отправка (WM)

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
GlobalBindsDisabled := False
ChoosePendingVk := 0
ChoosePendingToken := ""
ChoosePendingStart := 0
ChooseHoldWaitUpVk := 0
ChoosePendingMouseBtn := 0
ChoosePendingMouseToken := ""
ChoosePendingMouseStart := 0
ChooseHoldWaitUpMouse := 0
HeldInfinite := []

; === Динамические горячие клавиши ===
Hotkey, % "$" . StartStopKey, ToggleAction
Hotkey, % "$" . ChangeKeysKey, RechooseKeys
Hotkey, % "$" . ToggleGUIKey, ToggleStatusGUI
Hotkey, % ExitKey, ExitApp
Hotkey, % "$" . DisableAllKey, ToggleBindLock
Hotkey, % "$" . ToggleModeKey, ToggleSendMode

InitIndicator()

SetMainHotkeys("Off")
GoSub, ChooseKeys
Return

SetMainHotkeys(state) {
    Global StartStopKey, ChangeKeysKey, ToggleGUIKey, ToggleModeKey, GlobalBindsDisabled
    effectiveState := GlobalBindsDisabled ? "Off" : state
    Hotkey, % "$" . StartStopKey, ToggleAction, %effectiveState%
    Hotkey, % "$" . ChangeKeysKey, RechooseKeys, %effectiveState%
    Hotkey, % "$" . ToggleGUIKey, ToggleStatusGUI, %effectiveState%
    Hotkey, % "$" . ToggleModeKey, ToggleSendMode, %effectiveState%
}

ToggleBindLock:
    Global GlobalBindsDisabled, IsChoosingKeys, TotalProcesses, TotalGroups
    GlobalBindsDisabled := !GlobalBindsDisabled
    if (GlobalBindsDisabled) {
        SetMainHotkeys("Off")
    } else {
        if (!IsChoosingKeys && TotalProcesses > 0 && TotalGroups > 0)
            SetMainHotkeys("On")
    }
    UpdateStatus()
    InitIndicator()
Return

ToggleSendMode:
    Global UseSimulation, IsChoosingKeys, TotalProcesses, TotalGroups
    if (IsChoosingKeys)
        Return
    UseSimulation := !UseSimulation
    UpdateStatus()
    ToolTip, % UseSimulation ? "Режим: симуляция (ControlSend)" : "Режим: прямая отправка (WM)"
    SetTimer, ToggleSendModeTipOff, -1500
Return

ToggleSendModeTipOff:
    ToolTip
Return

; === Захват кликов мыши в окне выбора клавиш ===
#If (IsChoosingKeys && WinActive("Key Selection"))
~LButton::
    MouseChooseButtonDown(1, "{LButton}")
Return
~LButton Up::
    MouseChooseButtonUp(1)
Return
~RButton::
    MouseChooseButtonDown(2, "{RButton}")
Return
~RButton Up::
    MouseChooseButtonUp(2)
Return
#If

ChooseFlushKeyboardPendingIfAny() {
    Global KeysArray, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart
    if (!ChoosePendingVk)
        return
    SetTimer, ChooseHoldDetectTimer, Off
    KeysArray .= (KeysArray ? " " : "") . ChoosePendingToken
    GuiControl,, KeyList, %KeysArray%
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
}

ChooseFlushMousePendingIfAny() {
    Global KeysArray, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart
    if (!ChoosePendingMouseBtn)
        return
    SetTimer, ChooseMouseHoldDetectTimer, Off
    KeysArray .= (KeysArray ? " " : "") . ChoosePendingMouseToken
    GuiControl,, KeyList, %KeysArray%
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
}

MouseChooseButtonDown(btn, token) {
    Global IsChoosingKeys, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart, ChooseHoldWaitUpMouse
    if (!IsChoosingKeys || !WinActive("Key Selection"))
        return
    MouseGetPos, , , , ctrl, 1
    if (RegExMatch(ctrl, "i)^Button\d+$"))
        return
    if (ctrl = "Edit2")
        return
    ChooseFlushKeyboardPendingIfAny()
    if (ChoosePendingMouseBtn && ChoosePendingMouseBtn != btn)
        ChooseFlushMousePendingIfAny()
    if (ChooseHoldWaitUpMouse && ChooseHoldWaitUpMouse = btn)
        return
    if (ChoosePendingMouseBtn = btn)
        return
    ChoosePendingMouseBtn := btn
    ChoosePendingMouseToken := token
    ChoosePendingMouseStart := A_TickCount
    SetTimer, ChooseMouseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, -1000
}

MouseChooseButtonUp(btn) {
    Global KeysArray, IsChoosingKeys, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart
    Global ChooseHoldWaitUpMouse, DefaultInterval
    if (!IsChoosingKeys)
        return
    if (ChooseHoldWaitUpMouse && ChooseHoldWaitUpMouse = btn) {
        ChooseHoldWaitUpMouse := 0
        return
    }
    if (!ChoosePendingMouseBtn || ChoosePendingMouseBtn != btn)
        return
    SetTimer, ChooseMouseHoldDetectTimer, Off
    elapsed := A_TickCount - ChoosePendingMouseStart
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingMouseToken)
    if (elapsed < 1000)
        KeysArray .= (KeysArray ? " " : "") . ChoosePendingMouseToken
    else
        KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    GuiControl,, KeyList, %KeysArray%
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
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    OnMessage(0x100, "KeyDownMsg")
    OnMessage(0x101, "KeyUpMsg")
Return

GuiClose:
    ExitApp
Return

ClearKeys:
    KeysArray := ""
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    GuiControl,, KeyList
Return

ConfirmKeys:
    IsChoosingKeys := False
    OnMessage(0x100, False), OnMessage(0x101, False)
    Gui, Submit, NoHide
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    GoSub ReEnterPID
Return

AddAnotherGroup:
    IsChoosingKeys := False
    OnMessage(0x100, False), OnMessage(0x101, False)
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    Gui, Submit, NoHide
    SaveCurrentGroup()
    CurrentGroup += 1
    GoSub, ChooseKeys
Return

SaveCurrentGroup() {
    Global KeysArray, GroupInterval, DefaultInterval, Groups, TotalGroups
    Group := {}
    Group.keys := KeysArray
    gi := Trim(GroupInterval)
    if (gi = "")
        Group.interval := DefaultInterval
    else
        Group.interval := gi + 0
    Groups.Push(Group)
    TotalGroups += 1
}

; === Ввод PID / ProcessName ===
ReEnterPID:
    SetMainHotkeys("Off")
    Loop {
        TargetPIDArray := [], TargetProcessArray := [], TargetHwndArray := []
        TotalProcesses := 0
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
                        r := DllCall("user32\GetAncestor", "Ptr", hWnd, "UInt", 2, "Ptr")
                        if (r)
                            hWnd := r
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
                    DetectHiddenWindows, On
                    WinGet, hWndList, List, ahk_exe %ProcessName%
                    If (!hWndList) {
                        DetectHiddenWindows, Off
                        MsgBox, No window for "%ProcessName%"!
                    } Else {
                        tpBefore := TotalProcesses
                        seenRoot := {}
                        Loop %hWndList% {
                            h := hWndList%A_Index% + 0
                            r := DllCall("user32\GetAncestor", "Ptr", h, "UInt", 2, "Ptr")
                            if (!r)
                                r := h
                            if (seenRoot[r])
                                Continue
                            vis := DllCall("user32\IsWindowVisible", "Ptr", r)
                            ico := DllCall("user32\IsIconic", "Ptr", r)
                            if (!vis && !ico)
                                Continue
                            seenRoot[r] := 1
                            WinGet, ProcessPID, PID, ahk_id %r%
                            TotalProcesses += 1
                            TargetProcessArray[TotalProcesses] := Trim(ProcessName)
                            TargetPIDArray[TotalProcesses] := ProcessPID
                            TargetHwndArray[TotalProcesses] := r
                        }
                        if (TotalProcesses = tpBefore && hWndList) {
                            h0 := hWndList1 + 0
                            r0 := DllCall("user32\GetAncestor", "Ptr", h0, "UInt", 2, "Ptr")
                            if (!r0)
                                r0 := h0
                            WinGet, ProcessPID, PID, ahk_id %r0%
                            TotalProcesses += 1
                            TargetProcessArray[TotalProcesses] := Trim(ProcessName)
                            TargetPIDArray[TotalProcesses] := ProcessPID
                            TargetHwndArray[TotalProcesses] := r0
                        }
                        DetectHiddenWindows, Off
                    }
                }
            }
        }

        If (TotalProcesses = 0) {
            MsgBox, No valid processes found! Please try again.
            Continue
        }
        Break
    }

    IsChoosingKeys := False
    SaveCurrentGroup()

; === GUI статуса ===
    Gui, Destroy
    Gui, +AlwaysOnTop +ToolWindow -Caption +LastFound
    Gui, Color, 1E1E1E
    Gui, Font, s10 cRed, Consolas
    fullStatus := BuildStatusText("OFF")
    borderOnly := BuildBorderMask(fullStatus)
    innerStatus := BuildInnerStatusText(fullStatus)
    Gui, Add, Text, vStatusBorder, %borderOnly%
    Gui, Add, Text, xp yp vStatus BackgroundTrans, %innerStatus%
    if (ShowStatusGUI)
        Gui, Show, x%StatusPosX% y%StatusPosY% NoActivate AutoSize, Multi-PID Control
    InitIndicator()
    SetMainHotkeys("On")
Return

; === Обновление статуса ===
BuildStatusText(statusMode) {
    Global Groups, TotalGroups, TargetProcessArray, TotalProcesses, TargetPIDArray, KeyDelay, UseSimulation
    statusText := "Status: " statusMode
    baseStatus := "Status: ACTIVE (LOCKED)"
    maxLen := StrLen(baseStatus)
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
    modePlain := UseSimulation ? "Mode: CtrlSend" : "Mode: WM post"
    if (StrLen(modePlain) > maxLen)
        maxLen := StrLen(modePlain)
    paddingLen := maxLen + 2
    border := "+"
    Loop %paddingLen%
        border .= "-"
    border .= "+"
    statusPadding := ""
    Loop % (maxLen - StrLen(statusText))
        statusPadding .= " "
    fullStatus := border . "`n| " statusText statusPadding " |`n"
    modePad := ""
    Loop % (maxLen - StrLen(modePlain))
        modePad .= " "
    fullStatus .= "| " modePlain modePad " |`n"
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

BuildInnerStatusText(fullStatus) {
    lines := StrSplit(fullStatus, "`n")
    inner := ""
    maxIndex := lines.MaxIndex()
    Loop % maxIndex {
        line := lines[A_Index]
        len := StrLen(line)
        if (RegExMatch(line, "^\+[-]+\+$")) {
            innerLine := ""
            Loop % len
                innerLine .= " "
        }
        else if (len >= 2 && SubStr(line, 1, 1) = "|" && SubStr(line, len, 1) = "|") {
            innerLine := " "
            if (len > 2)
                innerLine .= SubStr(line, 2, len - 2)
            innerLine .= " "
        }
        else {
            innerLine := line
        }
        inner .= innerLine
        if (A_Index < maxIndex)
            inner .= "`n"
    }
    return inner
}

BuildBorderMask(fullStatus) {
    lines := StrSplit(fullStatus, "`n")
    mask := ""
    maxIndex := lines.MaxIndex()
    Loop % maxIndex {
        line := lines[A_Index]
        len := StrLen(line)
        if (RegExMatch(line, "^\+[-]+\+$")) {
            borderLine := line
        }
        else if (len >= 2 && SubStr(line, 1, 1) = "|" && SubStr(line, len, 1) = "|") {
            borderLine := "|"
            if (len > 2) {
                spaces := ""
                Loop % (len - 2)
                    spaces .= " "
                borderLine .= spaces
            }
            borderLine .= "|"
        }
        else {
            borderLine := ""
            Loop % len
                borderLine .= " "
        }
        mask .= borderLine
        if (A_Index < maxIndex)
            mask .= "`n"
    }
    return mask
}

UpdateStatus() {
    Global Toggle, ShowStatusGUI, GlobalBindsDisabled
    if (!ShowStatusGUI)
        Return
    if (GlobalBindsDisabled) {
        mode := Toggle ? "ACTIVE (LOCKED)" : "OFF (LOCKED)"
    } else {
        mode := Toggle ? "ACTIVE" : "OFF"
    }
    innerColor := Toggle ? "Green" : "Red"
    borderColor := GlobalBindsDisabled ? "Yellow" : innerColor
    fullStatus := BuildStatusText(mode)
    borderOnly := BuildBorderMask(fullStatus)
    innerStatusText := BuildInnerStatusText(fullStatus)
    GuiControl, +c%borderColor%, StatusBorder
    GuiControl, +c%innerColor%, Status
    GuiControl,, StatusBorder, %borderOnly%
    GuiControl,, Status, %innerStatusText%
}

InitIndicator() {
    Global IndicatorEnabled, IndicatorPosX, IndicatorPosY, IndicatorSize
    Global IndicatorBlinkState, IndicatorDotHwnd, GlobalBindsDisabled
    Global IndicatorBgColor, IndicatorBorderColorLocked, IndicatorBorderThickness
    Global IndicatorColorOn, IndicatorColorOff

    if (!IndicatorEnabled) {
        Gui, Indicator:Destroy
        SetTimer, IndicatorBlinkTimer, Off
        return
    }

    Gui, Indicator:Destroy
    Gui, Indicator:+AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound
    Gui, Indicator:Margin, 0, 0

    if (GlobalBindsDisabled) {
        bt := Round(IndicatorBorderThickness)
        if (bt < 1)
            bt := 1
        maxBt := Floor(IndicatorSize / 2)
        if (bt > maxBt)
            bt := maxBt
        innerSize := IndicatorSize - (bt * 2)
        if (innerSize < 1)
            innerSize := 1
        offset := (IndicatorSize - innerSize) // 2
        Gui, Indicator:Color, %IndicatorBorderColorLocked%
    } else {
        innerSize := IndicatorSize
        offset := 0
        Gui, Indicator:Color, %IndicatorBgColor%
    }

    Gui, Indicator:Add, Progress, x%offset% y%offset% hwndIndicatorDotHwnd w%innerSize% h%innerSize% c%IndicatorColorOff% Background%IndicatorBgColor% Range0-100, 100
    Gui, Indicator:Show, x%IndicatorPosX% y%IndicatorPosY% w%IndicatorSize% h%IndicatorSize% NoActivate
    IndicatorBlinkState := 0
    UpdateIndicator()
}

UpdateIndicator() {
    Global Toggle, IndicatorEnabled, IndicatorBlink, IndicatorBlinkInterval
    Global IndicatorBlinkState, IndicatorDotHwnd, GlobalBindsDisabled
    Global IndicatorColorOn, IndicatorColorOff

    if (!IndicatorEnabled) {
        SetTimer, IndicatorBlinkTimer, Off
        return
    }

    innerColor := Toggle ? IndicatorColorOn : IndicatorColorOff
    GuiControl, Indicator:+c%innerColor%, %IndicatorDotHwnd%

    if (IndicatorBlink) {
        IndicatorBlinkState := 1
        SetTimer, IndicatorBlinkTimer, %IndicatorBlinkInterval%
    } else {
        SetTimer, IndicatorBlinkTimer, Off
        IndicatorBlinkState := 0
    }
}

IndicatorBlinkTimer:
    Global Toggle, IndicatorEnabled, IndicatorBlink, GlobalBindsDisabled
    Global IndicatorBlinkState, IndicatorDotHwnd
    Global IndicatorColorOn, IndicatorColorOff, IndicatorBgColor
    if (!IndicatorEnabled || !IndicatorBlink) {
        SetTimer, IndicatorBlinkTimer, Off
        IndicatorBlinkState := 0
        innerColor := Toggle ? IndicatorColorOn : IndicatorColorOff
        GuiControl, Indicator:+c%innerColor%, %IndicatorDotHwnd%
        return
    }
    IndicatorBlinkState := !IndicatorBlinkState
    baseColor := Toggle ? IndicatorColorOn : IndicatorColorOff
    altColor := IndicatorBgColor
    innerColor := IndicatorBlinkState ? baseColor : altColor
    GuiControl, Indicator:+c%innerColor%, %IndicatorDotHwnd%
Return

; === Подпрограмма: запуск/остановка ===
ToggleDeferredSendGroups:
    SetTimer, ToggleDeferredSendGroups, Off
    Global Toggle, TotalGroups
    if (!Toggle)
        Return
    Loop % TotalGroups {
        If (Toggle)
            SendGroupKeys(A_Index)
    }
Return

ToggleAction:
    if (IsChoosingKeys || TotalProcesses = 0 || TotalGroups = 0) {
        Return
    }
    Toggle := !Toggle
    if (!Toggle) {
        ReleaseAllHeldInfinite()
        SetTimer, ToggleDeferredSendGroups, Off
    }
    UpdateStatus()
    UpdateIndicator()
    Loop % TotalGroups {
        If (Toggle) {
            SetTimer, % "SendGroup" . A_Index, % Groups[A_Index].interval
        } Else {
            SetTimer, % "SendGroup" . A_Index, Off
        }
    }
    if (Toggle)
        SetTimer, ToggleDeferredSendGroups, -1
Return

; === Подпрограмма: перенастройка клавиш ===
RechooseKeys:
    If (IsChoosingKeys) {
        MsgBox, Finish key selection first.
        Return
    }
    ReleaseAllHeldInfinite()
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

PostMsgModsDownFlags(hWndTarget, shiftOn, ctrlOn, altOn) {
    if (shiftOn)
        PostMsgToFocus(hWndTarget, 0x100, 0x10, PostMsgKeyLP(0x10, 0, hWndTarget))
    if (ctrlOn)
        PostMsgToFocus(hWndTarget, 0x100, 0x11, PostMsgKeyLP(0x11, 0, hWndTarget))
    if (altOn)
        PostMsgToFocus(hWndTarget, 0x100, 0x12, PostMsgKeyLP(0x12, 0, hWndTarget))
}

PostMsgModsUpFlags(hWndTarget, shiftOn, ctrlOn, altOn) {
    if (altOn)
        PostMsgToFocus(hWndTarget, 0x101, 0x12, PostMsgKeyLP(0x12, 1, hWndTarget))
    if (ctrlOn)
        PostMsgToFocus(hWndTarget, 0x101, 0x11, PostMsgKeyLP(0x11, 1, hWndTarget))
    if (shiftOn)
        PostMsgToFocus(hWndTarget, 0x101, 0x10, PostMsgKeyLP(0x10, 1, hWndTarget))
}

PostMsgModsDownFromString(hWndTarget, modifiers) {
    if (InStr(modifiers, "Shift"))
        PostMsgToFocus(hWndTarget, 0x100, 0x10, PostMsgKeyLP(0x10, 0, hWndTarget))
    if (InStr(modifiers, "Ctrl"))
        PostMsgToFocus(hWndTarget, 0x100, 0x11, PostMsgKeyLP(0x11, 0, hWndTarget))
    if (InStr(modifiers, "Alt"))
        PostMsgToFocus(hWndTarget, 0x100, 0x12, PostMsgKeyLP(0x12, 0, hWndTarget))
}

PostMsgModsUpFromString(hWndTarget, modifiers) {
    if (InStr(modifiers, "Alt"))
        PostMsgToFocus(hWndTarget, 0x101, 0x12, PostMsgKeyLP(0x12, 1, hWndTarget))
    if (InStr(modifiers, "Ctrl"))
        PostMsgToFocus(hWndTarget, 0x101, 0x11, PostMsgKeyLP(0x11, 1, hWndTarget))
    if (InStr(modifiers, "Shift"))
        PostMsgToFocus(hWndTarget, 0x101, 0x10, PostMsgKeyLP(0x10, 1, hWndTarget))
}

PostMsgModsDownFromList(hWndTarget, modifiers) {
    StringSplit, modParts, modifiers, %A_Space%
    Loop %modParts0% {
        modVk := GetKeyVK(modParts%A_Index%)
        If modVk
            PostMsgToFocus(hWndTarget, 0x100, modVk, PostMsgKeyLP(modVk, 0, hWndTarget))
    }
}

PostMsgModsUpFromList(hWndTarget, modifiers) {
    StringSplit, modParts, modifiers, %A_Space%
    Loop %modParts0% {
        modVk := GetKeyVK(modParts%A_Index%)
        If modVk
            PostMsgToFocus(hWndTarget, 0x101, modVk, PostMsgKeyLP(modVk, 1, hWndTarget))
    }
}

TokenToHoldKeyspec(token) {
    if (RegExMatch(token, "^\{(.+)\}$", m))
        return m1
    return token
}

ParseKeyspecModsMain(keyspec, ByRef modifiers, ByRef mainKey) {
    modifiers := ""
    mainKey := keyspec
    if (RegExMatch(keyspec, "i)^(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", m)) {
        modifiers := m1
        mainKey := m2
    } else if (RegExMatch(keyspec, "i)^(.+)\+(Shift|Ctrl|Alt|Win|LWin|RWin)\+(.+)$", m)) {
        modifiers := m1 . "+" . m2
        mainKey := m3
    }
}

ModDownString(modifiers) {
    s := ""
    if (InStr(modifiers, "Shift"))
        s .= "{Shift down}"
    if (InStr(modifiers, "Ctrl"))
        s .= "{Ctrl down}"
    if (InStr(modifiers, "Alt"))
        s .= "{Alt down}"
    if (InStr(modifiers, "Win") || InStr(modifiers, "LWin") || InStr(modifiers, "RWin"))
        s .= "{LWin down}"
    return s
}

ModUpString(modifiers) {
    s := ""
    if (InStr(modifiers, "Win") || InStr(modifiers, "LWin") || InStr(modifiers, "RWin"))
        s .= "{LWin up}"
    if (InStr(modifiers, "Alt"))
        s .= "{Alt up}"
    if (InStr(modifiers, "Ctrl"))
        s .= "{Ctrl up}"
    if (InStr(modifiers, "Shift"))
        s .= "{Shift up}"
    return s
}

SendKeyspec_SimDown(h, keyspec) {
    ParseKeyspecModsMain(keyspec, modS, mainK)
    if (modS != "") {
        md := ModDownString(modS)
        ds := md . "{" . mainK . " down}"
        ControlSend,, %ds%, ahk_id %h%
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        btnLr := InStr(mainK, "R") ? "Right" : "Left"
        ControlClick, x%mcX% y%mcY%, ahk_id %h%,, %btnLr%, 1, NA D
        return
    }
    if (mainK = " ") {
        ControlSend,, {Space down}, ahk_id %h%
        return
    }
    if (StrLen(mainK) = 1 && mainK != " ") {
        ControlSend,, {Blind}{%mainK% down}, ahk_id %h%
        return
    }
    vk := GetKeyVK(mainK)
    if (vk) {
        vkH := VkToHex(vk)
        ControlSend,, {vk%vkH% down}, ahk_id %h%
    }
}

SendKeyspec_SimUp(h, keyspec) {
    ParseKeyspecModsMain(keyspec, modS, mainK)
    if (modS != "") {
        mu := ModUpString(modS)
        us := "{" . mainK . " up}" . mu
        ControlSend,, %us%, ahk_id %h%
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        btnLr := InStr(mainK, "R") ? "Right" : "Left"
        ControlClick, x%mcX% y%mcY%, ahk_id %h%,, %btnLr%, 1, NA U
        return
    }
    if (mainK = " ") {
        ControlSend,, {Space up}, ahk_id %h%
        return
    }
    if (StrLen(mainK) = 1 && mainK != " ") {
        ControlSend,, {Blind}{%mainK% up}, ahk_id %h%
        return
    }
    vk := GetKeyVK(mainK)
    if (vk) {
        vkH := VkToHex(vk)
        ControlSend,, {vk%vkH% up}, ahk_id %h%
    }
}

SendKeyspec_PostDown(h, keyspec) {
    ParseKeyspecModsMain(keyspec, modS, mainK)
    if (modS != "") {
        PostMsgModsDownFromString(h, modS)
        vk := GetKeyVK(mainK)
        if (vk)
            PostMsgToFocus(h, 0x100, vk, PostMsgKeyLP(vk, 0, h))
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        PostMsgToFocus(h, 0x200, 0, lPar)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x204, 2, lPar)
        else
            PostMsgToFocus(h, 0x201, 1, lPar)
        return
    }
    if (StrLen(mainK) = 1 && mainK != " ") {
        ch0 := Ord(mainK)
        if (ch0 >= 0x30 && ch0 <= 0x39) {
            lpDn := PostMsgKeyLP(ch0, 0, h)
            PostMsgToFocus(h, 0x100, ch0, lpDn)
            return
        }
        tidL := DllCall("user32\GetWindowThreadProcessId", "Ptr", h, "Ptr", 0, "UInt")
        hklL := DllCall("user32\GetKeyboardLayout", "UInt", tidL, "Ptr")
        vkSc := DllCall("user32\VkKeyScanExW", "UShort", ch0, "Ptr", hklL, "Short")
        if (vkSc != -1 && vkSc != 0xffff) {
            vk := vkSc & 0xff
            shiftOn := (vkSc >> 8) & 1
            ctrlOn := (vkSc >> 8) & 2
            altOn := (vkSc >> 8) & 4
            PostMsgModsDownFlags(h, shiftOn, ctrlOn, altOn)
            PostMsgToFocus(h, 0x100, vk, PostMsgKeyLP(vk, 0, h))
        }
        return
    }
    vk := GetKeyVK(mainK)
    if (vk) {
        lpDn := PostMsgKeyLP(vk, 0, h)
        PostMsgToFocus(h, 0x100, vk, lpDn)
    }
}

SendKeyspec_PostUp(h, keyspec) {
    ParseKeyspecModsMain(keyspec, modS, mainK)
    if (modS != "") {
        vk := GetKeyVK(mainK)
        if (vk)
            PostMsgToFocus(h, 0x101, vk, PostMsgKeyLP(vk, 1, h))
        PostMsgModsUpFromString(h, modS)
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x205, 0, lPar)
        else
            PostMsgToFocus(h, 0x202, 0, lPar)
        return
    }
    if (StrLen(mainK) = 1 && mainK != " ") {
        ch0 := Ord(mainK)
        if (ch0 >= 0x30 && ch0 <= 0x39) {
            PostMsgToFocus(h, 0x101, ch0, PostMsgKeyLP(ch0, 1, h))
            return
        }
        tidL := DllCall("user32\GetWindowThreadProcessId", "Ptr", h, "Ptr", 0, "UInt")
        hklL := DllCall("user32\GetKeyboardLayout", "UInt", tidL, "Ptr")
        vkSc := DllCall("user32\VkKeyScanExW", "UShort", ch0, "Ptr", hklL, "Short")
        if (vkSc != -1 && vkSc != 0xffff) {
            vk := vkSc & 0xff
            shiftOn := (vkSc >> 8) & 1
            ctrlOn := (vkSc >> 8) & 2
            altOn := (vkSc >> 8) & 4
            PostMsgToFocus(h, 0x101, vk, PostMsgKeyLP(vk, 1, h))
            PostMsgModsUpFlags(h, shiftOn, ctrlOn, altOn)
        }
        return
    }
    vk := GetKeyVK(mainK)
    if (vk)
        PostMsgToFocus(h, 0x101, vk, PostMsgKeyLP(vk, 1, h))
}

ReleaseAllHeldInfinite() {
    Global HeldInfinite, TotalProcesses, TargetHwndArray
    if (!HeldInfinite.Length())
        return
    Loop % HeldInfinite.Length() {
        e := HeldInfinite[A_Index]
        Loop %TotalProcesses% {
            h := TargetHwndArray[A_Index]
            if (e.s)
                SendKeyspec_SimUp(h, e.k)
            else
                SendKeyspec_PostUp(h, e.k)
        }
    }
    HeldInfinite := []
}

VkToHex(vk) {
    vk := vk & 255
    SetFormat, IntegerFast, H
    h := vk + 0
    SetFormat, IntegerFast, D
    if (SubStr(h, 1, 2) = "0x")
        h := SubStr(h, 3)
    if (StrLen(h) = 1)
        h := "0" . h
    return h
}

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
    If UseSimulation {
        SendGroupKeys_Simulated(keysArray)
        Return
    }
    SendGroupKeys_Posted(keysArray)
}

SendGroupKeys_Simulated(keysArray) {
    Global Toggle, TotalProcesses, TargetHwndArray, KeyDelay
    Loop % keysArray.Length()
    {
        If (!Toggle)
            Return
        currentKey := keysArray[A_Index]
        If (RegExMatch(currentKey, "i)^{HOLD(\d+)\|(.+)\}$", hm)) {
            if (!Toggle)
                Return
            holdMs := hm1 + 0
            keyspec := hm2
            Global HeldInfinite, TotalProcesses, TargetHwndArray, KeyDelay
            Loop %TotalProcesses% {
                hW := TargetHwndArray[A_Index]
                SendKeyspec_SimDown(hW, keyspec)
            }
            if (holdMs > 0) {
                Sleep, %holdMs%
                if (!Toggle) {
                    Loop %TotalProcesses% {
                        SendKeyspec_SimUp(TargetHwndArray[A_Index], keyspec)
                    }
                    Return
                }
                Loop %TotalProcesses% {
                    SendKeyspec_SimUp(TargetHwndArray[A_Index], keyspec)
                }
            } else {
                HeldInfinite.Push({s: 1, k: keyspec})
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(LButton|LClick|Click)\}$"))
        {
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                SendLeftClickAtCursor(hWndTarget, True)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(RButton|RClick)\}$"))
        {
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                SendRightClickAtCursor(hWndTarget, True)
            }
            Sleep, %KeyDelay%
            Continue
        }
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
                    ksMod := "{Raw}" . sendFormat
                    ControlSend, , %ksMod%, ahk_id %hWndTarget%
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
                ksOne := "{Text}" . keyStr
                ControlSend, , %ksOne%, ahk_id %hWndTarget%
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
}

SendGroupKeys_Posted(keysArray) {
    Global Toggle, TotalProcesses, TargetHwndArray, KeyDelay
    Loop % keysArray.Length()
    {
        If (!Toggle)
            Return
        currentKey := keysArray[A_Index]
        If (RegExMatch(currentKey, "i)^{HOLD(\d+)\|(.+)\}$", hm)) {
            if (!Toggle)
                Return
            holdMs := hm1 + 0
            keyspec := hm2
            Global HeldInfinite, TotalProcesses, TargetHwndArray, KeyDelay
            Loop %TotalProcesses% {
                hW := TargetHwndArray[A_Index]
                SendKeyspec_PostDown(hW, keyspec)
            }
            if (holdMs > 0) {
                Sleep, %holdMs%
                if (!Toggle) {
                    Loop %TotalProcesses% {
                        SendKeyspec_PostUp(TargetHwndArray[A_Index], keyspec)
                    }
                    Return
                }
                Loop %TotalProcesses% {
                    SendKeyspec_PostUp(TargetHwndArray[A_Index], keyspec)
                }
            } else {
                HeldInfinite.Push({s: 0, k: keyspec})
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(LButton|LClick|Click)\}$"))
        {
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                SendLeftClickAtCursor(hWndTarget, False)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(RButton|RClick)\}$"))
        {
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                SendRightClickAtCursor(hWndTarget, False)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{Space\}$"))
        {
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                PostTapVkFocused(hWndTarget, 0x20)
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
                    PostMsgModsDownFromString(hWndTarget, modifiers)
                    PostMsgToFocus(hWndTarget, 0x0102, charCode, 1)
                    PostMsgModsUpFromString(hWndTarget, modifiers)
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
                            PostMsgModsDownFromList(hWndTarget, modifiers)
                            PostMsgToFocus(hWndTarget, 0x100, vkMain, PostMsgKeyLP(vkMain, 0, hWndTarget))
                            PostMsgToFocus(hWndTarget, 0x101, vkMain, PostMsgKeyLP(vkMain, 1, hWndTarget))
                            PostMsgModsUpFromList(hWndTarget, modifiers)
                        }
                    }
                }
            }
            Sleep, %KeyDelay%
        }
        Else If (StrLen(keyStr) = 1 && keyStr != " ")
        {
            ch0 := Ord(keyStr)
            Loop %TotalProcesses%
            {
                hWndTarget := TargetHwndArray[A_Index]
                if (ch0 >= 0x30 && ch0 <= 0x39) {
                    PostTapVkFocused(hWndTarget, ch0)
                } else {
                    tidL := DllCall("user32\GetWindowThreadProcessId", "Ptr", hWndTarget, "Ptr", 0, "UInt")
                    hklL := DllCall("user32\GetKeyboardLayout", "UInt", tidL, "Ptr")
                    vkSc := DllCall("user32\VkKeyScanExW", "UShort", ch0, "Ptr", hklL, "Short")
                    if (vkSc != -1 && vkSc != 0xffff) {
                        vk := vkSc & 0xff
                        shiftOn := (vkSc >> 8) & 1
                        ctrlOn := (vkSc >> 8) & 2
                        altOn := (vkSc >> 8) & 4
                        PostMsgModsDownFlags(hWndTarget, shiftOn, ctrlOn, altOn)
                        PostMsgToFocus(hWndTarget, 0x100, vk, PostMsgKeyLP(vk, 0, hWndTarget))
                        PostMsgToFocus(hWndTarget, 0x101, vk, PostMsgKeyLP(vk, 1, hWndTarget))
                        PostMsgModsUpFlags(hWndTarget, shiftOn, ctrlOn, altOn)
                    } else {
                        if (ch0 = 0x451 || ch0 = 0x401 || ch0 = 96)
                            PostTapVkFocused(hWndTarget, 0xC0)
                        else {
                            VarSetCapacity(char, 4, 0)
                            StrPut(keyStr, &char, "UTF-16")
                            charCode := NumGet(char, 0, "UShort")
                            PostMsgToFocus(hWndTarget, 0x0102, charCode, 1)
                        }
                    }
                }
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
                    hWndTarget := TargetHwndArray[A_Index]
                    PostTapVkFocused(hWndTarget, vk)
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
        While (pos <= len && SubStr(keysString, pos, 1) = " ")
            pos++
        If (pos > len)
            Break
        
        If (SubStr(keysString, pos, 1) = "{")
        {
            endPos := InStr(keysString, "}", false, pos)
            If (endPos)
            {
                token := SubStr(keysString, pos, endPos - pos + 1)
                keysArray.Push(token)
                pos := endPos + 1
            }
            Else
            {
                token := SubStr(keysString, pos)
                keysArray.Push(token)
                Break
            }
        }
        Else
        {
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

CursorOverTargetHwnd(hTop) {
    if (!hTop)
        return 0
    MouseGetPos, , , hUnder
    hUnder += 0
    if (!hUnder)
        return 0
    rT := KeyTargetGameRoot(hTop)
    rU := KeyTargetGameRoot(hUnder)
    return (rT && rU && rT = rU)
}

ResolveClickClientCoords(hWnd, ByRef cX, ByRef cY) {
    cX := 0, cY := 0
    if (!hWnd)
        return
    if (CursorOverTargetHwnd(hWnd)) {
        MouseGetPos, sX, sY
        VarSetCapacity(pt, 8, 0)
        NumPut(sX, pt, 0, "Int")
        NumPut(sY, pt, 4, "Int")
        DllCall("user32\ScreenToClient", "Ptr", hWnd, "Ptr", &pt)
        cX := NumGet(pt, 0, "Int")
        cY := NumGet(pt, 4, "Int")
        return
    }
    VarSetCapacity(rc, 16, 0)
    if (!DllCall("user32\GetClientRect", "Ptr", hWnd, "Ptr", &rc))
        return
    cw := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    ch := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    if (cw < 1 || ch < 1) {
        prevDhw := A_DetectHiddenWindows
        DetectHiddenWindows, On
        WinGetPos, wx, wy, ww, wh, ahk_id %hWnd%
        DetectHiddenWindows, %prevDhw%
        if (ww < 1 || wh < 1)
            return
        sx := wx + Floor(ww / 2)
        sy := wy + Floor(wh / 2)
        VarSetCapacity(pt2, 8, 0)
        NumPut(sx, pt2, 0, "Int")
        NumPut(sy, pt2, 4, "Int")
        DllCall("user32\ScreenToClient", "Ptr", hWnd, "Ptr", &pt2)
        cX := NumGet(pt2, 0, "Int")
        cY := NumGet(pt2, 4, "Int")
        return
    }
    cX := Floor(cw / 2)
    cY := Floor(ch / 2)
}

SendLeftClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    ResolveClickClientCoords(hWndTarget, cX, cY)
    if (useSimulation) {
        ControlClick, x%cX% y%cY%, ahk_id %hWndTarget%,, Left, 1, NA
        return
    }
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    PostMsgToFocus(hWndTarget, 0x200, 0, lParam)
    PostMsgToFocus(hWndTarget, 0x201, 1, lParam)
    PostMsgToFocus(hWndTarget, 0x202, 0, lParam)
}

SendRightClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    ResolveClickClientCoords(hWndTarget, cX, cY)
    if (useSimulation) {
        ControlClick, x%cX% y%cY%, ahk_id %hWndTarget%,, Right, 1, NA
        return
    }
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    PostMsgToFocus(hWndTarget, 0x200, 0, lParam)
    PostMsgToFocus(hWndTarget, 0x204, 2, lParam)
    PostMsgToFocus(hWndTarget, 0x205, 0, lParam)
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

_PostMsgKeyLParamRaw(vk, keyUp, targetHwnd) {
    tid := targetHwnd ? DllCall("user32\GetWindowThreadProcessId", "Ptr", targetHwnd, "Ptr", 0, "UInt") : 0
    hkl := DllCall("user32\GetKeyboardLayout", "UInt", tid, "Ptr")
    scan := DllCall("user32\MapVirtualKeyExW", "UInt", vk, "UInt", 0, "Ptr", hkl, "UInt")
    lp := 1 | (scan << 16)
    if (keyUp)
        lp |= 0xC0000000
    return lp
}

KeyTargetGameRoot(hWndTop) {
    if (!hWndTop)
        return 0
    r := DllCall("user32\GetAncestor", "Ptr", hWndTop, "UInt", 2, "Ptr")
    return r ? r : hWndTop
}

PostMsgKeyLP(vk, keyUp, hWndTop) {
    return _PostMsgKeyLParamRaw(vk, keyUp, KeyTargetGameRoot(hWndTop))
}

DeliverActivateRootSync(root) {
    if (!root)
        return 0
    return DllCall("user32\SendMessageW", "Ptr", root, "UInt", 0x0006, "Ptr", 1, "Ptr", 0, "Int")
}

PostMsgToFocus(hWndTop, msg, wParam, lParam) {
    if (!hWndTop)
        return 0
    root := KeyTargetGameRoot(hWndTop)
    if (!root)
        return 0
    DeliverActivateRootSync(root)
    return DllCall("user32\PostMessageW", "Ptr", root, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Int")
}

PostTapVkFocused(hWndTop, vk) {
    if (!hWndTop || !vk)
        Return
    root := KeyTargetGameRoot(hWndTop)
    if (!root)
        Return
    lpDn := PostMsgKeyLP(vk, 0, hWndTop)
    lpUp := PostMsgKeyLP(vk, 1, hWndTop)
    DeliverActivateRootSync(root)
    DllCall("user32\PostMessageW", "Ptr", root, "UInt", 0x100, "Ptr", vk, "Ptr", lpDn, "Int")
    DllCall("user32\PostMessageW", "Ptr", root, "UInt", 0x101, "Ptr", vk, "Ptr", lpUp, "Int")
}

; === Обработка WM_KEYDOWN / WM_KEYUP (выбор клавиш) ===
ChooseMouseHoldDetectTimer:
    Global KeysArray, IsChoosingKeys, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChooseHoldWaitUpMouse, DefaultInterval
    if (!IsChoosingKeys || !ChoosePendingMouseBtn)
        return
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingMouseToken)
    KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    GuiControl,, KeyList, %KeysArray%
    ChooseHoldWaitUpMouse := ChoosePendingMouseBtn
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    SetTimer, ChooseMouseHoldDetectTimer, Off
return

ChooseHoldDetectTimer:
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChooseHoldWaitUpVk, DefaultInterval
    if (!IsChoosingKeys || !ChoosePendingVk)
        return
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingToken)
    KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    GuiControl,, KeyList, %KeysArray%
    ChooseHoldWaitUpVk := ChoosePendingVk
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    SetTimer, ChooseHoldDetectTimer, Off
return

KeyDownMsg(wParam, lParam) {
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart, ChooseHoldWaitUpVk
    If (!IsChoosingKeys)
        Return
    ControlGetFocus, FocusedControl
    If (FocusedControl = "Edit2")
        Return
    ChooseFlushMousePendingIfAny()
    vk := wParam
    if (ChooseHoldWaitUpVk && vk = ChooseHoldWaitUpVk)
        Return
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
    } else if (vk == 0x0D && extended) {
        keyName := "NumpadEnter"
    } else {
        static KeyList := ["LButton","RButton","MButton","XButton1","XButton2","Backspace","Tab","Clear","Enter","Shift","Ctrl","Alt","Pause","CapsLock","Esc","Space","PageUp","PageDown","End","Home","Left","Up","Right","Down","PrintScreen","Insert","Delete","LWin","RWin","Apps","Sleep","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"]
        For k, v in KeyList {
            If (vk == GetKeyVK(v)) {
                keyName := v
                Break
            }
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
    If (keyName = "")
        Return
    combination := (isWinPressed ? "Win+" : "") . (isCtrlPressed ? "Ctrl+" : "") . (isAltPressed ? "Alt+" : "") . (isShiftPressed ? "Shift+" : "") . keyName
    needBrace := (InStr(combination, "+") || StrLen(keyName) > 1 || RegExMatch(keyName, "^[A-Z]"))
    if (!needBrace && StrLen(keyName) = 1) {
        ac := Asc(SubStr(keyName, 1, 1))
        if (ac = 96 || ac = 37 || ac = 59 || ac = 91 || ac = 93 || ac = 94 || ac = 44 || ac > 127)
            needBrace := true
    }
    token := needBrace ? "{" combination "}" : keyName
    if (ChoosePendingVk && ChoosePendingVk != vk) {
        SetTimer, ChooseHoldDetectTimer, Off
        KeysArray .= (KeysArray ? " " : "") . ChoosePendingToken
        GuiControl,, KeyList, %KeysArray%
        ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    }
    if (ChoosePendingVk = vk)
        Return
    ChoosePendingVk := vk
    ChoosePendingToken := token
    ChoosePendingStart := A_TickCount
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseHoldDetectTimer, -1000
}

KeyUpMsg(wParam, lParam) {
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart, ChooseHoldWaitUpVk, DefaultInterval
    If (!IsChoosingKeys)
        Return
    ControlGetFocus, FocusedControl
    If (FocusedControl = "Edit2")
        Return
    vk := wParam
    if (vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0x5B || vk = 0x5C)
        Return
    if (ChooseHoldWaitUpVk && vk = ChooseHoldWaitUpVk) {
        ChooseHoldWaitUpVk := 0
        Return
    }
    if (!ChoosePendingVk || vk != ChoosePendingVk)
        Return
    SetTimer, ChooseHoldDetectTimer, Off
    elapsed := A_TickCount - ChoosePendingStart
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingToken)
    if (elapsed < 1000)
        KeysArray .= (KeysArray ? " " : "") . ChoosePendingToken
    else
        KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    GuiControl,, KeyList, %KeysArray%
}

; === Подпрограмма выхода ===
ExitApp:
    ReleaseAllHeldInfinite()
    ExitApp
Return