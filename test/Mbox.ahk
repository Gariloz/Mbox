; === Настройки ===
DefaultInterval := 500                  ; Интервал по умолчанию для новых групп (мс)
KeyDelay := 0                           ; Задержка между клавишами в последовательности (мс); для WM-мыши — доп. пауза после SetCursorPos (минимум несколько мс)
; UseSimulation=true  — симуляция: клавиши и мышь — ControlSend / ControlClick на HWND из списка целей этой группы.
; UseSimulation=false — прямая отправка: клавиши — PostMsgToFocus / PostTapVkFocused; мышь — те же три WM через PostMsgToFocus (MOVE + DOWN + UP).
UseSimulation := false
ShowStatusGUI := true                   ; Показывать окно статуса (true/false)
StatusPosX := 0                         ; X позиция окна статуса
StatusPosY := 0                         ; Y позиция окна статуса
StatusFontSize := 9                     ; Размер шрифта окна статуса (компактнее = меньше число)
StatusGuiMaxChars := 52                 ; Макс. длина строки в символах; длиннее — «...»
ProcessInputBoxW := 380                 ; Ширина (px), по умолчанию у InputBox ~372 — не растягиваем широко
ProcessInputBoxH := 230                 ; Высота (px), чтобы примеры текста помещались
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
ToggleModeKey := "NumpadDiv"            ; Переключение: симуляция (ControlSend) / прямая отправка (WM)

; === Системные настройки ===
#Persistent
#SingleInstance Force
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
PendingGroupForTargets := 0
LastPromptTargetsOk := false
SendGroup_ExecHwnds := ""
SendGroup_ExecN := 0
SendGroup_MouseFixed := false
SendGroup_MouseCX := ""
SendGroup_MouseCY := ""
SendGroup_MouseNoMove := false
MouseCoordPendingGi := 0
MccPickHw := 0
MouseCoordModalResult := 0
; 0 = нет итога, 1 = отмена (крестик/Escape/окно пропало), 2 = OK, 3 = Default (курсор)
MouseCoordExitReason := 0
KeyPickHwnd := 0
StatusBarHwnd := 0
MousePostSnapLock := 0
MousePostSnapOx := 0
MousePostSnapOy := 0
MousePostSnapHaveSave := false

; === Динамические горячие клавиши ===
Hotkey, % "$" . StartStopKey, ToggleAction
Hotkey, % "$" . ChangeKeysKey, RechooseKeys
Hotkey, % "$" . ToggleGUIKey, ToggleStatusGUI
; В v1 третий параметр Hotkey — имя метки; «ExitApp» без метки даёт Target label does not exist
Hotkey, % ExitKey, MboxDoExit
Hotkey, % "$" . DisableAllKey, ToggleBindLock
Hotkey, % "$" . ToggleModeKey, ToggleSendMode

OnExit, MboxOnExitCleanup

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
    Global GlobalBindsDisabled, IsChoosingKeys, TotalGroups
    GlobalBindsDisabled := !GlobalBindsDisabled
    if (GlobalBindsDisabled) {
        SetMainHotkeys("Off")
    } else if (!IsChoosingKeys && GroupsConfigured()) {
        SetMainHotkeys("On")
    }
    UpdateStatus()
    InitIndicator()
Return

ToggleSendMode:
    Global UseSimulation, TotalGroups
    UseSimulation := !UseSimulation
    UpdateStatus()
    ToolTip, % UseSimulation ? "Режим: симуляция (ControlSend)" : "Режим: прямая отправка (WM)"
    SetTimer, ToggleSendModeTipOff, -1500
Return

ToggleSendModeTipOff:
    ToolTip
Return

; === Захват кликов мыши в окне выбора клавиш ===
; Нельзя привязывать LButton Up к WinActive("Key Selection"): между Down и Up фокус/активное окно
; может смениться — тогда Up не срабатывает, таймер даёт ложный «удержание» мыши.
#If (IsChoosingKeys)
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
    KeyPickRefreshList()
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
}

ChooseFlushMousePendingIfAny() {
    Global KeysArray, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart
    if (!ChoosePendingMouseBtn)
        return
    SetTimer, ChooseMouseHoldDetectTimer, Off
    KeysArray .= (KeysArray ? " " : "") . ChoosePendingMouseToken
    KeyPickRefreshList()
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
}

KeyPickRefreshList() {
    Global KeysArray, KeyPickHwnd
    if (!KeyPickHwnd || !WinExist("ahk_id " . KeyPickHwnd))
        return
    Gui, KeyPick:Default
    GuiControl,, KeyList, %KeysArray%
}

; Фокус на списке клавиш: иначе при фокусе на кнопке пробел «нажимает» кнопку (Clear и т.д.), а не добавляет Space.
KeyPickFocusKeyList() {
    Global KeyPickHwnd
    if (!KeyPickHwnd || !WinExist("ahk_id " . KeyPickHwnd))
        return
    Gui, KeyPick:Default
    GuiControl, Focus, KeyList
}

MouseChooseButtonDown(btn, token) {
    Global IsChoosingKeys, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart, ChooseHoldWaitUpMouse, KeyPickHwnd
    if (!IsChoosingKeys || !KeyPickHwnd || !WinActive("ahk_id " . KeyPickHwnd))
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
    Gui, KeyPick:Default
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
    KeyPickRefreshList()
}

; === Выбор клавиш ===
ChooseKeys:
    Global StatusBarHwnd, KeyPickHwnd
    IsChoosingKeys := True
    SetMainHotkeys("Off")
    if (StatusBarHwnd && WinExist("ahk_id " . StatusBarHwnd)) {
        Gui, StatusBar:Destroy
        StatusBarHwnd := 0
    }
    Gui, KeyPick:New, +HwndKeyPickHwnd +LabelKeyPick
    Gui, KeyPick:Font, s10
    titleText := "Group " . CurrentGroup . " - Click on the buttons you want the script to press."
    Gui, KeyPick:Add, Text, x10 y10 w380 Center, %titleText%
    Gui, KeyPick:Add, Edit, x25 y35 vKeyList w350 r5 ReadOnly
    Gui, KeyPick:Add, Text, x25 y135, Interval (ms):
    Gui, KeyPick:Add, Edit, x105 y130 vGroupInterval w60, %DefaultInterval%
    Gui, KeyPick:Add, Button, x25 y160 gConfirmKeys, Confirm Selection
    Gui, KeyPick:Add, Button, x+10 gClearKeys -Tabstop, Clear buttons
    Gui, KeyPick:Add, Button, x+10 gAddAnotherGroup -Tabstop, Add Another Group
    Gui, KeyPick:Show, w400 h200, Key Selection
    KeysArray := ""
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    OnMessage(0x100, "KeyDownMsg")
    OnMessage(0x101, "KeyUpMsg")
    KeyPickRefreshList()
    KeyPickFocusKeyList()
Return

GuiClose:
    ExitApp
Return

; Закрытие только окна выбора клавиш (без глобального OnMessage 0x112 на все окна скрипта)
KeyPickGuiClose:
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
    KeyPickRefreshList()
    KeyPickFocusKeyList()
Return

ConfirmKeys:
    Global MouseCoordExitReason
    Gui, KeyPick:Default
    ChooseFlushKeyboardPendingIfAny()
    ChooseFlushMousePendingIfAny()
    OnMessage(0x100, False), OnMessage(0x101, False)
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    Gui, KeyPick:Submit, NoHide
    IsChoosingKeys := False
    Gui, KeyPick:Hide
    SaveCurrentGroup()
    PendingGroupForTargets := TotalGroups
    Gosub, PromptTargetsIntoGroup
    if (!LastPromptTargetsOk)
        Return
    Gosub, PromptMouseCoordsForGroup
    if (MouseCoordExitReason = 1) {
        Gosub, CancelMouseCoordWizardReturnToKeyPick
        Return
    }
    Gosub, FinishSetupAfterTargets
Return

AddAnotherGroup:
    Global MouseCoordExitReason
    Gui, KeyPick:Default
    ChooseFlushKeyboardPendingIfAny()
    ChooseFlushMousePendingIfAny()
    OnMessage(0x100, False), OnMessage(0x101, False)
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    Gui, KeyPick:Submit, NoHide
    IsChoosingKeys := False
    Gui, KeyPick:Hide
    SaveCurrentGroup()
    PendingGroupForTargets := TotalGroups
    Gosub, PromptTargetsIntoGroup
    if (!LastPromptTargetsOk)
        Return
    Gosub, PromptMouseCoordsForGroup
    if (MouseCoordExitReason = 1) {
        Gosub, CancelMouseCoordWizardReturnToKeyPick
        Return
    }
    CurrentGroup += 1
    GoSub, ChooseKeys
Return

SaveCurrentGroup() {
    Global KeysArray, GroupInterval, DefaultInterval, Groups, TotalGroups
    Group := {}
    Group.keys := KeysArray
    Group.mouseClickFixed := false
    Group.mouseClickNoMove := false
    gi := Trim(GroupInterval)
    if (gi = "")
        Group.interval := DefaultInterval
    else
        Group.interval := gi + 0
    Groups.Push(Group)
    TotalGroups += 1
}

GroupsConfigured() {
    Global Groups, TotalGroups
    if (TotalGroups < 1)
        return false
    Loop % TotalGroups {
        g := Groups[A_Index]
        if (!IsObject(g))
            return false
        tgt := g.tgtHwnds
        if (!IsObject(tgt) || tgt.Length() < 1)
            return false
    }
    return true
}

PromptTargetsIntoGroup:
    Global Groups, PendingGroupForTargets, TotalGroups, TotalProcesses, TargetPIDArray, TargetProcessArray, TargetHwndArray
    Global ProcessInputBoxW, ProcessInputBoxH
    LastPromptTargetsOk := false
    gi := PendingGroupForTargets
    if (gi < 1 || gi > TotalGroups)
        Return
    Loop {
        TargetPIDArray := [], TargetProcessArray := [], TargetHwndArray := []
        TotalProcesses := 0
        promptText := "Group " . gi . " — targets only for this group.`n`n"
        promptText .= "PID or process name.`n`n"
        promptText .= "Example.`n"
        promptText .= "PID:[1234 5678][1234.5678].`n"
        promptText .= "Name:[notepad explorer][notepad.explorer]."

        ibW := ProcessInputBoxW + 0
        ibH := ProcessInputBoxH + 0
        InputBox, TargetInput, Enter Process Info, %promptText%, , %ibW%, %ibH%
        If ErrorLevel {
            Groups.RemoveAt(TotalGroups)
            TotalGroups -= 1
            Gosub, ChooseKeys
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
    g := Groups[gi]
    g.tgtHwnds := []
    g.tgtPids := []
    g.tgtProcs := []
    Loop % TotalProcesses {
        g.tgtHwnds.Push(TargetHwndArray[A_Index])
        g.tgtPids.Push(TargetPIDArray[A_Index])
        g.tgtProcs.Push(TargetProcessArray[A_Index])
    }
    LastPromptTargetsOk := true
Return

CancelMouseCoordWizardReturnToKeyPick:
    Global Groups, TotalGroups, KeysArray, GroupInterval, KeyPickHwnd, MouseCoordExitReason
    Global IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart, ChooseHoldWaitUpVk
    Global ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart, ChooseHoldWaitUpMouse
    if (TotalGroups < 1) {
        MouseCoordExitReason := 0
        Return
    }
    g := Groups[TotalGroups]
    KeysArray := g.keys
    GroupInterval := g.interval
    Groups.RemoveAt(TotalGroups)
    TotalGroups -= 1
    MouseCoordExitReason := 0
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    ChooseHoldWaitUpVk := 0
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    ChooseHoldWaitUpMouse := 0
    SetTimer, ChooseHoldDetectTimer, Off
    SetTimer, ChooseMouseHoldDetectTimer, Off
    IsChoosingKeys := True
    OnMessage(0x100, "KeyDownMsg")
    OnMessage(0x101, "KeyUpMsg")
    if (!KeyPickHwnd || !WinExist("ahk_id " . KeyPickHwnd)) {
        Gosub, ChooseKeys
        Return
    }
    Gui, KeyPick:Default
    GuiControl,, GroupInterval, %GroupInterval%
    KeyPickRefreshList()
    Gui, KeyPick:Show, w400 h200, Key Selection
    KeyPickFocusKeyList()
Return

PromptMouseCoordsForGroup:
    Global Groups, TotalGroups, MouseCoordPendingGi, MouseCoordModalResult, MouseCoordExitReason
    MouseCoordExitReason := 0
    MouseCoordPendingGi := TotalGroups
    if (MouseCoordPendingGi < 1 || MouseCoordPendingGi > Groups.Length())
        Return
    g := Groups[MouseCoordPendingGi]
    if (!GroupKeysNeedMouse(g.keys))
        Return
    if (!IsObject(g.tgtHwnds) || g.tgtHwnds.Length() < 1)
        Return
    MouseCoordModalResult := 0
    Gosub, ShowMouseCoordGuiModal
Return

ShowMouseCoordGuiModal:
    Global Groups, MouseCoordPendingGi, MccPickHw, MouseCoordModalResult, KeyPickHwnd, MouseCoordExitReason
    hRef := (Groups[MouseCoordPendingGi].tgtHwnds[1]) + 0
    root := KeyTargetGameRoot(hRef)
    if (!root) {
        MouseCoordExitReason := 3
        MouseCoordModalResult := 1
        Return
    }
    MccPickHw := 0
    Gui, MouseCoordPick:New, +HwndMccPickHw +AlwaysOnTop +LabelMouseCoordPick
    Gui, MouseCoordPick:Margin, 8, 8
    Gui, MouseCoordPick:Font, s8
    Gui, MouseCoordPick:Add, Text, xm w360, Click = client coords of target window root.`nLive / Click follow the cursor until "Manual entry" is checked.
    Gui, MouseCoordPick:Add, Checkbox, xm y+8 vMcManual, Manual entry
    Gui, MouseCoordPick:Add, Checkbox, xm y+6 vMcNoMove, WM: click without moving system cursor (fixed coords OR window center; game must honor WM)
    Gui, MouseCoordPick:Add, Text, xm y+8 section w44, Live X
    Gui, MouseCoordPick:Add, Text, vMcLiveXM w78 ys, 0
    Gui, MouseCoordPick:Add, Text, x+10 ys w44, Live Y
    Gui, MouseCoordPick:Add, Text, vMcLiveYM ys w78, 0
    Gui, MouseCoordPick:Add, Text, xm y+10 section w44, Click X
    Gui, MouseCoordPick:Add, Edit, vMcSetX w78 ys, 0
    Gui, MouseCoordPick:Add, Text, x+10 ys w44, Click Y
    Gui, MouseCoordPick:Add, Edit, vMcSetY ys w78, 0
    Gui, MouseCoordPick:Add, Button, xm y+10 w72 h22 gMouseCoordGuiOK, OK
    Gui, MouseCoordPick:Add, Button, x+8 yp w200 h22 gMouseCoordGuiSkip, Default (cursor / center)
    Gui, MouseCoordPick:Show, AutoSize Center, Mouse click coordinates
    Gui, MouseCoordPick:+HwndMccPickHw
    SetTimer, MouseCoordLiveTimer, 50
    Gosub, MouseCoordLiveTimer
    While (MouseCoordModalResult = 0) {
        if (MccPickHw && !WinExist("ahk_id " . MccPickHw)) {
            MouseCoordModalResult := 1
            if (MouseCoordExitReason = 0)
                MouseCoordExitReason := 1
            Break
        }
        Sleep, 10
    }
    SetTimer, MouseCoordLiveTimer, Off
    if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
        Gui, KeyPick:Default
Return

MouseCoordLiveTimer:
    Global Groups, MouseCoordPendingGi, MccPickHw, KeyPickHwnd
    if (!MccPickHw || !WinExist("ahk_id " . MccPickHw))
        Return
    Gui, MouseCoordPick:Default
    gi := MouseCoordPendingGi
    if (gi < 1 || gi > Groups.Length()) {
        if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
            Gui, KeyPick:Default
        Return
    }
    g := Groups[gi]
    if (!IsObject(g.tgtHwnds) || g.tgtHwnds.Length() < 1) {
        if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
            Gui, KeyPick:Default
        Return
    }
    hRef := g.tgtHwnds[1] + 0
    root := KeyTargetGameRoot(hRef)
    if (!root) {
        if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
            Gui, KeyPick:Default
        Return
    }
    CoordMode, Mouse, Screen
    MouseGetPos, mcx, mcy
    VarSetCapacity(pt, 8, 0)
    NumPut(mcx, pt, 0, "Int")
    NumPut(mcy, pt, 4, "Int")
    if (DllCall("user32\ScreenToClient", "UPtr", root, "Ptr", &pt)) {
        cx := NumGet(pt, 0, "Int")
        cy := NumGet(pt, 4, "Int")
        GuiControl,, McLiveXM, %cx%
        GuiControl,, McLiveYM, %cy%
        GuiControlGet, mcMan,, McManual
        if ((mcMan + 0) = 0) {
            GuiControl,, McSetX, %cx%
            GuiControl,, McSetY, %cy%
        }
    }
    if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
        Gui, KeyPick:Default
Return

MouseCoordGuiOK:
    SetTimer, MouseCoordLiveTimer, Off
    Global Groups, MouseCoordPendingGi, MccPickHw, MouseCoordModalResult, KeyPickHwnd, MouseCoordExitReason
    MouseCoordExitReason := 2
    MouseCoordModalResult := 1
    Gui, MouseCoordPick:Submit, NoHide
    gi := MouseCoordPendingGi
    if (gi >= 1 && gi <= Groups.Length()) {
        g := Groups[gi]
        g.mouseClickFixed := true
        g.mouseClientX := McSetX + 0
        g.mouseClientY := McSetY + 0
        GuiControlGet, mcnm,, McNoMove
        g.mouseClickNoMove := (mcnm + 0) != 0
    }
    Gui, MouseCoordPick:Destroy
    MccPickHw := 0
    if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
        Gui, KeyPick:Default
Return

MouseCoordGuiSkip:
    SetTimer, MouseCoordLiveTimer, Off
    Global Groups, MouseCoordPendingGi, MccPickHw, MouseCoordModalResult, KeyPickHwnd, MouseCoordExitReason
    MouseCoordExitReason := 3
    MouseCoordModalResult := 1
    gi := MouseCoordPendingGi
    if (gi >= 1 && gi <= Groups.Length()) {
        g := Groups[gi]
        g.mouseClickFixed := false
        Gui, MouseCoordPick:Default
        GuiControlGet, mcnm,, McNoMove
        g.mouseClickNoMove := (mcnm + 0) != 0
    }
    Gui, MouseCoordPick:Destroy
    MccPickHw := 0
    if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
        Gui, KeyPick:Default
Return

MouseCoordPickGuiClose:
MouseCoordPickGuiEscape:
    Global Groups, MouseCoordPendingGi, MccPickHw, MouseCoordModalResult, KeyPickHwnd, MouseCoordExitReason
    SetTimer, MouseCoordLiveTimer, Off
    alreadyDone := (MouseCoordModalResult != 0)
    if (!alreadyDone) {
        MouseCoordExitReason := 1
        MouseCoordModalResult := 1
    }
    if (MccPickHw && WinExist("ahk_id " . MccPickHw)) {
        if (!alreadyDone) {
            gi := MouseCoordPendingGi
            if (gi >= 1 && gi <= Groups.Length()) {
                g := Groups[gi]
                g.mouseClickFixed := false
                g.mouseClickNoMove := false
            }
        }
        Gui, MouseCoordPick:Destroy
    }
    MccPickHw := 0
    if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd))
        Gui, KeyPick:Default
Return

FinishSetupAfterTargets:
    Global StatusBarHwnd, KeyPickHwnd
    IsChoosingKeys := False
    Gui, KeyPick:Destroy
    KeyPickHwnd := 0
    Gui, Destroy
    if (StatusBarHwnd && WinExist("ahk_id " . StatusBarHwnd)) {
        Gui, StatusBar:Destroy
        StatusBarHwnd := 0
    }
    Gui, StatusBar:New, +AlwaysOnTop +ToolWindow -Caption +HwndStatusBarHwnd
    Gui, StatusBar:Color, 1E1E1E
    Gui, StatusBar:Font, s%StatusFontSize% cRed, Consolas
    fullStatus := BuildStatusText("OFF")
    borderOnly := BuildBorderMask(fullStatus)
    innerStatus := BuildInnerStatusText(fullStatus)
    Gui, StatusBar:Add, Text, vStatusBorder, %borderOnly%
    Gui, StatusBar:Add, Text, xp yp vStatus BackgroundTrans, %innerStatus%
    if (ShowStatusGUI) {
        statusGuiX := StatusPosX + 0
        statusGuiY := StatusPosY + 0
        Gui, StatusBar:Show, x%statusGuiX% y%statusGuiY% NoActivate AutoSize, Multi-PID Control
    }
    InitIndicator()
    SetMainHotkeys("On")
Return

; === Обновление статуса ===
TruncateStatusLine(s, maxC) {
    if (maxC < 4)
        return SubStr(s, 1, maxC)
    if (StrLen(s) <= maxC)
        return s
    return SubStr(s, 1, maxC - 3) . "..."
}

BuildStatusText(statusMode) {
    Global Groups, TotalGroups, KeyDelay, UseSimulation, StatusGuiMaxChars
    mc := StatusGuiMaxChars
    statusText := TruncateStatusLine("Status: " statusMode, mc)
    modePlain := TruncateStatusLine(UseSimulation ? "Mode: CtrlSend" : "Mode: WM post", mc)
    maxLen := StrLen(statusText)
    if (StrLen(modePlain) > maxLen)
        maxLen := StrLen(modePlain)
    lines := []
    lines.Push(statusText)
    lines.Push(modePlain)
    Loop %TotalGroups% {
        keys := Groups[A_Index].keys
        if (!RegExMatch(keys, "^\{.*\}$"))
            keys := "{" keys "}"
        keysForCount := Groups[A_Index].keys
        StringSplit, keyArray, keysForCount, %A_Space%
        totalDelay := (keyArray0 - 1) * KeyDelay
        realInterval := Groups[A_Index].interval + totalDelay
        tgtStr := ""
        gp := Groups[A_Index].tgtPids
        gpr := Groups[A_Index].tgtProcs
        if (IsObject(gp) && gp.Length() > 0) {
            Loop % gp.Length() {
                tgtStr .= (tgtStr ? ", " : "") . "PID " . Trim(gp[A_Index]) . " (" . Trim(gpr[A_Index]) . ")"
            }
        }
        head := "G" A_Index ": " keys " (" realInterval "ms)"
        if (Groups[A_Index].mouseClickFixed)
            head .= " [mouse " . Groups[A_Index].mouseClientX . "," . Groups[A_Index].mouseClientY . "]"
        if (Groups[A_Index].mouseClickNoMove)
            head .= " [WM no-cursor]"
        line1 := TruncateStatusLine(head, mc)
        lines.Push(line1)
        if (StrLen(line1) > maxLen)
            maxLen := StrLen(line1)
        if (tgtStr != "") {
            line2 := TruncateStatusLine(tgtStr, mc)
            lines.Push(line2)
            if (StrLen(line2) > maxLen)
                maxLen := StrLen(line2)
        }
    }
    if (maxLen < 18)
        maxLen := 18
    border := "+"
    Loop % (maxLen + 2)
        border .= "-"
    border .= "+"
    fullStatus := border . "`n"
    Loop % lines.MaxIndex() {
        ln := lines[A_Index]
        pad := ""
        Loop % (maxLen - StrLen(ln))
            pad .= " "
        fullStatus .= "| " ln pad " |`n"
    }
    Return RTrim(fullStatus, "`r`n") . "`n" . border
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
    Global Toggle, ShowStatusGUI, GlobalBindsDisabled, StatusBarHwnd
    if (!ShowStatusGUI)
        Return
    if (!StatusBarHwnd || !WinExist("ahk_id " . StatusBarHwnd))
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
    GuiControl, StatusBar:+c%borderColor%, StatusBorder
    GuiControl, StatusBar:+c%innerColor%, Status
    GuiControl, StatusBar:, StatusBorder, %borderOnly%
    GuiControl, StatusBar:, Status, %innerStatusText%
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
    if (IsChoosingKeys || !GroupsConfigured()) {
        Return
    }
    Toggle := !Toggle
    if (!Toggle) {
        SetTimer, ToggleDeferredSendGroups, Off
        Loop % TotalGroups {
            SetTimer, % "SendGroup" . A_Index, Off
        }
        ; Сначала обновляем статус/индикатор, затем тяжёлое снятие удержаний — иначе GUI «отстаёт»
        UpdateStatus()
        UpdateIndicator()
        ReleaseAllHeldInfinite()
    } else {
        UpdateStatus()
        UpdateIndicator()
        Loop % TotalGroups {
            SetTimer, % "SendGroup" . A_Index, % Groups[A_Index].interval
        }
        SetTimer, ToggleDeferredSendGroups, -1
    }
Return

; === Подпрограмма: перенастройка клавиш ===
RechooseKeys:
    ReleaseAllHeldInfinite()
    if (IsChoosingKeys) {
        OnMessage(0x100, False), OnMessage(0x101, False)
        SetTimer, ChooseHoldDetectTimer, Off
        SetTimer, ChooseMouseHoldDetectTimer, Off
        ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
        ChooseHoldWaitUpVk := 0
        ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
        ChooseHoldWaitUpMouse := 0
        Global KeyPickHwnd
        if (KeyPickHwnd && WinExist("ahk_id " . KeyPickHwnd)) {
            Gui, KeyPick:Destroy
            KeyPickHwnd := 0
        }
        IsChoosingKeys := False
    }
    Loop % TotalGroups
        SetTimer, % "SendGroup" . A_Index, Off
    Groups := [], TotalGroups := 0, CurrentGroup := 1
    KeysArray := ""
    Toggle := False
    UpdateStatus()
    UpdateIndicator()
    GoSub, ChooseKeys
Return

; === Подпрограмма: переключение показа/скрытия GUI статуса ===
ToggleStatusGUI:
    If (!GroupsConfigured())
        Return
    If (ShowStatusGUI := !ShowStatusGUI)
    {
        statusGuiX := StatusPosX + 0
        statusGuiY := StatusPosY + 0
        Gui, StatusBar:Show, x%statusGuiX% y%statusGuiY% NoActivate AutoSize
        UpdateStatus()
    }
    Else
    {
        Gui, StatusBar:Hide
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
        ResolveGroupClickClientCoords(h, true, mcX, mcY)
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
        ResolveGroupClickClientCoords(h, true, mcX, mcY)
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
        ResolveGroupClickClientCoords(h, false, mcX, mcY)
        PostWmMouseSnapBegin(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        SendMsgToFocus(h, 0x200, 0, lPar)
        if (RegExMatch(mainK, "i)^RButton$"))
            SendMsgToFocus(h, 0x204, 2, lPar)
        else
            SendMsgToFocus(h, 0x201, 1, lPar)
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
        Global SendGroup_MouseNoMove
        ResolveGroupClickClientCoords(h, false, mcX, mcY)
        if (SendGroup_MouseNoMove) {
            lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
            if (RegExMatch(mainK, "i)^RButton$"))
                SendMsgToFocus(h, 0x205, 0, lPar)
            else
                SendMsgToFocus(h, 0x202, 0, lPar)
            Sleep, 0
            PostWmMouseSnapEnd()
            return
        }
        PostWmMouseMoveCursorToRootClient(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        if (RegExMatch(mainK, "i)^RButton$"))
            SendMsgToFocus(h, 0x205, 0, lPar)
        else
            SendMsgToFocus(h, 0x202, 0, lPar)
        Sleep, 0
        PostWmMouseSnapEnd()
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
    Global HeldInfinite, SendGroup_MouseFixed, SendGroup_MouseCX, SendGroup_MouseCY, SendGroup_MouseNoMove
    if (HeldInfinite.Length()) {
        prevF := SendGroup_MouseFixed, prevX := SendGroup_MouseCX, prevY := SendGroup_MouseCY, prevNM := SendGroup_MouseNoMove
        Loop % HeldInfinite.Length() {
            e := HeldInfinite[A_Index]
            SendGroup_MouseFixed := e.mouseFixed
            SendGroup_MouseCX := e.mouseCX
            SendGroup_MouseCY := e.mouseCY
            SendGroup_MouseNoMove := e.mouseNoMove ? true : false
            if (IsObject(e.h)) {
                Loop % e.h.Length() {
                    h := e.h[A_Index]
                    if (e.s)
                        SendKeyspec_SimUp(h, e.k)
                    else
                        SendKeyspec_PostUp(h, e.k)
                }
            }
        }
        SendGroup_MouseFixed := prevF
        SendGroup_MouseCX := prevX
        SendGroup_MouseCY := prevY
        SendGroup_MouseNoMove := prevNM
        HeldInfinite := []
    }
    PostWmMouseSnapResetIfAny()
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

SnapshotExecHwnds() {
    Global SendGroup_ExecHwnds, SendGroup_ExecN
    a := []
    Loop % SendGroup_ExecN
        a.Push(SendGroup_ExecHwnds[A_Index])
    return a
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
    Global Groups, KeyDelay, UseSimulation, Toggle, SendGroup_ExecHwnds, SendGroup_ExecN
    Global SendGroup_MouseFixed, SendGroup_MouseCX, SendGroup_MouseCY, SendGroup_MouseNoMove
    if (groupIndex > Groups.Length() || !Toggle)
        Return
    g := Groups[groupIndex]
    if (!IsObject(g.tgtHwnds) || g.tgtHwnds.Length() < 1)
        Return
    SendGroup_ExecHwnds := g.tgtHwnds
    SendGroup_ExecN := g.tgtHwnds.Length()
    SendGroup_MouseFixed := false
    SendGroup_MouseCX := ""
    SendGroup_MouseCY := ""
    SendGroup_MouseNoMove := g.mouseClickNoMove ? true : false
    if (g.mouseClickFixed) {
        SendGroup_MouseFixed := true
        SendGroup_MouseCX := g.mouseClientX + 0
        SendGroup_MouseCY := g.mouseClientY + 0
    }
    keysArray := ParseKeys(g.keys)
    If UseSimulation {
        SendGroupKeys_Simulated(keysArray)
        SendGroup_MouseFixed := false
        SendGroup_MouseCX := ""
        SendGroup_MouseCY := ""
        SendGroup_MouseNoMove := false
        Return
    }
    SendGroupKeys_Posted(keysArray)
    SendGroup_MouseFixed := false
    SendGroup_MouseCX := ""
    SendGroup_MouseCY := ""
    SendGroup_MouseNoMove := false
}

SendGroupKeys_Simulated(keysArray) {
    Global Toggle, SendGroup_ExecHwnds, SendGroup_ExecN, KeyDelay
    Global SendGroup_MouseFixed, SendGroup_MouseCX, SendGroup_MouseCY, SendGroup_MouseNoMove
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
            Global HeldInfinite, KeyDelay
            Loop %SendGroup_ExecN% {
                hW := SendGroup_ExecHwnds[A_Index]
                SendKeyspec_SimDown(hW, keyspec)
            }
            if (holdMs > 0) {
                Sleep, %holdMs%
                if (!Toggle) {
                    Loop %SendGroup_ExecN% {
                        SendKeyspec_SimUp(SendGroup_ExecHwnds[A_Index], keyspec)
                    }
                    Return
                }
                Loop %SendGroup_ExecN% {
                    SendKeyspec_SimUp(SendGroup_ExecHwnds[A_Index], keyspec)
                }
            } else {
                HeldInfinite.Push({s: 1, k: keyspec, h: SnapshotExecHwnds(), mouseFixed: SendGroup_MouseFixed, mouseCX: SendGroup_MouseCX, mouseCY: SendGroup_MouseCY, mouseNoMove: SendGroup_MouseNoMove})
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(LButton|LClick|Click)\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                SendLeftClickAtCursor(hWndTarget, True)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(RButton|RClick)\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                SendRightClickAtCursor(hWndTarget, True)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{Space\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
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
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
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
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                ksOne := "{Text}" . keyStr
                ControlSend, , %ksOne%, ahk_id %hWndTarget%
            }
        }
        Else
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                ControlSend, , %currentKey%, ahk_id %hWndTarget%
            }
        }
        Sleep, %KeyDelay%
    }
}

SendGroupKeys_Posted(keysArray) {
    Global Toggle, SendGroup_ExecHwnds, SendGroup_ExecN, KeyDelay
    Global SendGroup_MouseFixed, SendGroup_MouseCX, SendGroup_MouseCY, SendGroup_MouseNoMove
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
            Global HeldInfinite, KeyDelay
            Loop %SendGroup_ExecN% {
                hW := SendGroup_ExecHwnds[A_Index]
                SendKeyspec_PostDown(hW, keyspec)
            }
            if (holdMs > 0) {
                Sleep, %holdMs%
                if (!Toggle) {
                    Loop %SendGroup_ExecN% {
                        SendKeyspec_PostUp(SendGroup_ExecHwnds[A_Index], keyspec)
                    }
                    Return
                }
                Loop %SendGroup_ExecN% {
                    SendKeyspec_PostUp(SendGroup_ExecHwnds[A_Index], keyspec)
                }
            } else {
                HeldInfinite.Push({s: 0, k: keyspec, h: SnapshotExecHwnds(), mouseFixed: SendGroup_MouseFixed, mouseCX: SendGroup_MouseCX, mouseCY: SendGroup_MouseCY, mouseNoMove: SendGroup_MouseNoMove})
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(LButton|LClick|Click)\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                SendLeftClickAtCursor(hWndTarget, False)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{(RButton|RClick)\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
                SendRightClickAtCursor(hWndTarget, False)
            }
            Sleep, %KeyDelay%
            Continue
        }
        If (RegExMatch(currentKey, "i)^\{Space\}$"))
        {
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
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
                Loop %SendGroup_ExecN%
                {
                    hWndTarget := SendGroup_ExecHwnds[A_Index]
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
                        Loop %SendGroup_ExecN%
                        {
                            hWndTarget := SendGroup_ExecHwnds[A_Index]
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
            Loop %SendGroup_ExecN%
            {
                hWndTarget := SendGroup_ExecHwnds[A_Index]
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
                Loop %SendGroup_ExecN%
                {
                    hWndTarget := SendGroup_ExecHwnds[A_Index]
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

GroupKeysNeedMouse(keys) {
    if (keys = "")
        return false
    return RegExMatch(keys, "i)\{(LButton|RButton|MButton|LClick|RClick|Click)\}")
}

MapClientPointBetweenHwnds(cxFrom, cyFrom, hWndFrom, hWndTo, ByRef outX, ByRef outY) {
    outX := cxFrom + 0, outY := cyFrom + 0
    if (!hWndFrom || !hWndTo)
        return
    VarSetCapacity(pt, 8, 0)
    NumPut(cxFrom + 0, pt, 0, "Int")
    NumPut(cyFrom + 0, pt, 4, "Int")
    if (!DllCall("user32\ClientToScreen", "Ptr", hWndFrom, "Ptr", &pt))
        return
    if (!DllCall("user32\ScreenToClient", "Ptr", hWndTo, "Ptr", &pt))
        return
    outX := NumGet(pt, 0, "Int")
    outY := NumGet(pt, 4, "Int")
}

PostWmMouseMoveCursorToRootClient(hWndTarget, clientX, clientY) {
    root := KeyTargetGameRoot(hWndTarget)
    if (!root)
        return
    VarSetCapacity(scPt, 8, 0)
    NumPut(clientX + 0, scPt, 0, "Int")
    NumPut(clientY + 0, scPt, 4, "Int")
    if (!DllCall("user32\ClientToScreen", "Ptr", root, "Ptr", &scPt))
        return
    sx := NumGet(scPt, 0, "Int")
    sy := NumGet(scPt, 4, "Int")
    DllCall("user32\SetCursorPos", "Int", sx, "Int", sy)
    PostWmMouseAfterCursorMove()
}

PostWmMouseAfterCursorMove() {
    Global KeyDelay
    kd := KeyDelay + 0
    settle := kd + 3
    if (settle < 3)
        settle := 3
    if (settle > 50)
        settle := 50
    Sleep, %settle%
}

PostWmMouseSnapBegin(hWndTarget, clientX, clientY) {
    Global SendGroup_MouseNoMove, MousePostSnapLock, MousePostSnapOx, MousePostSnapOy, MousePostSnapHaveSave
    if (SendGroup_MouseNoMove) {
        MousePostSnapLock++
        PostWmMouseAfterCursorMove()
        return
    }
    if (!MousePostSnapHaveSave) {
        VarSetCapacity(pt, 8, 0)
        if (DllCall("user32\GetCursorPos", "Ptr", &pt)) {
            MousePostSnapOx := NumGet(pt, 0, "Int")
            MousePostSnapOy := NumGet(pt, 4, "Int")
            MousePostSnapHaveSave := true
        }
    }
    MousePostSnapLock++
    PostWmMouseMoveCursorToRootClient(hWndTarget, clientX, clientY)
}

PostWmMouseSnapEnd() {
    Global MousePostSnapLock, MousePostSnapOx, MousePostSnapOy, MousePostSnapHaveSave
    if (MousePostSnapLock < 1)
        return
    MousePostSnapLock--
    if (MousePostSnapLock = 0 && MousePostSnapHaveSave) {
        DllCall("user32\SetCursorPos", "Int", MousePostSnapOx, "Int", MousePostSnapOy)
        MousePostSnapHaveSave := false
    }
}

PostWmMouseSnapResetIfAny() {
    Global MousePostSnapLock, MousePostSnapOx, MousePostSnapOy, MousePostSnapHaveSave
    if (MousePostSnapLock < 1)
        return
    if (MousePostSnapHaveSave)
        DllCall("user32\SetCursorPos", "Int", MousePostSnapOx, "Int", MousePostSnapOy)
    MousePostSnapLock := 0
    MousePostSnapHaveSave := false
}

ResolveClickClientCoords(hWnd, ByRef cX, ByRef cY) {
    cX := 0, cY := 0
    if (!hWnd)
        return
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

ResolveGroupClickClientCoords(hWndTarget, forControlClick, ByRef cX, ByRef cY) {
    Global SendGroup_MouseFixed, SendGroup_MouseCX, SendGroup_MouseCY, SendGroup_ExecHwnds
    if (SendGroup_MouseFixed && SendGroup_MouseCX != "" && SendGroup_MouseCY != "") {
        r1 := SendGroup_ExecHwnds.Length() >= 1 ? KeyTargetGameRoot(SendGroup_ExecHwnds[1]) : KeyTargetGameRoot(hWndTarget)
        if (forControlClick) {
            MapClientPointBetweenHwnds(SendGroup_MouseCX + 0, SendGroup_MouseCY + 0, r1, hWndTarget, cX, cY)
        } else {
            rT := KeyTargetGameRoot(hWndTarget)
            if (r1 && rT)
                MapClientPointBetweenHwnds(SendGroup_MouseCX + 0, SendGroup_MouseCY + 0, r1, rT, cX, cY)
            else {
                cX := SendGroup_MouseCX + 0
                cY := SendGroup_MouseCY + 0
            }
        }
    } else {
        ResolveClickClientCoords(hWndTarget, cX, cY)
        if (!forControlClick) {
            rT := KeyTargetGameRoot(hWndTarget)
            if (rT && (hWndTarget + 0) != (rT + 0))
                MapClientPointBetweenHwnds(cX + 0, cY + 0, hWndTarget, rT, cX, cY)
        }
    }
}

SendLeftClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    Global SendGroup_MouseNoMove
    ResolveGroupClickClientCoords(hWndTarget, useSimulation, cX, cY)
    if (useSimulation) {
        ControlClick, x%cX% y%cY%, ahk_id %hWndTarget%,, Left, 1, NA
        return
    }
    if (SendGroup_MouseNoMove) {
        PostWmMouseAfterCursorMove()
        lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
        SendMsgToFocus(hWndTarget, 0x200, 0, lParam)
        SendMsgToFocus(hWndTarget, 0x201, 1, lParam)
        SendMsgToFocus(hWndTarget, 0x202, 0, lParam)
        Sleep, 0
        return
    }
    VarSetCapacity(savePt, 8, 0)
    DllCall("user32\GetCursorPos", "Ptr", &savePt)
    ox := NumGet(savePt, 0, "Int"), oy := NumGet(savePt, 4, "Int")
    PostWmMouseMoveCursorToRootClient(hWndTarget, cX, cY)
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    SendMsgToFocus(hWndTarget, 0x200, 0, lParam)
    SendMsgToFocus(hWndTarget, 0x201, 1, lParam)
    SendMsgToFocus(hWndTarget, 0x202, 0, lParam)
    Sleep, 0
    DllCall("user32\SetCursorPos", "Int", ox, "Int", oy)
}

SendRightClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    Global SendGroup_MouseNoMove
    ResolveGroupClickClientCoords(hWndTarget, useSimulation, cX, cY)
    if (useSimulation) {
        ControlClick, x%cX% y%cY%, ahk_id %hWndTarget%,, Right, 1, NA
        return
    }
    if (SendGroup_MouseNoMove) {
        PostWmMouseAfterCursorMove()
        lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
        SendMsgToFocus(hWndTarget, 0x200, 0, lParam)
        SendMsgToFocus(hWndTarget, 0x204, 2, lParam)
        SendMsgToFocus(hWndTarget, 0x205, 0, lParam)
        Sleep, 0
        return
    }
    VarSetCapacity(savePt, 8, 0)
    DllCall("user32\GetCursorPos", "Ptr", &savePt)
    ox := NumGet(savePt, 0, "Int"), oy := NumGet(savePt, 4, "Int")
    PostWmMouseMoveCursorToRootClient(hWndTarget, cX, cY)
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    SendMsgToFocus(hWndTarget, 0x200, 0, lParam)
    SendMsgToFocus(hWndTarget, 0x204, 2, lParam)
    SendMsgToFocus(hWndTarget, 0x205, 0, lParam)
    Sleep, 0
    DllCall("user32\SetCursorPos", "Int", ox, "Int", oy)
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
    ; Не блокируем поток скрипта синхронным SendMessage:
    ; при зависшем целевом окне это "замораживает" хоткеи/трей/ExitApp.
    return DllCall("user32\PostMessageW", "Ptr", root, "UInt", 0x0006, "Ptr", 1, "Ptr", 0, "Int")
}

PostMsgToFocus(hWndTop, msg, wParam, lParam) {
    if (!hWndTop)
        return 0
    root := KeyTargetGameRoot(hWndTop)
    if (!root)
        return 0
    return DllCall("user32\PostMessageW", "Ptr", root, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Int")
}

SendMsgToFocus(hWndTop, msg, wParam, lParam) {
    if (!hWndTop)
        return 0
    root := KeyTargetGameRoot(hWndTop)
    if (!root)
        return 0
    ; Историческое имя функции сохранено, но отправка теперь асинхронная:
    ; это предотвращает блокировку всего скрипта при зависшем target window.
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
    Gui, KeyPick:Default
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingMouseToken)
    KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    KeyPickRefreshList()
    ChooseHoldWaitUpMouse := ChoosePendingMouseBtn
    ChoosePendingMouseBtn := 0, ChoosePendingMouseToken := "", ChoosePendingMouseStart := 0
    SetTimer, ChooseMouseHoldDetectTimer, Off
return

ChooseHoldDetectTimer:
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChooseHoldWaitUpVk, DefaultInterval
    if (!IsChoosingKeys || !ChoosePendingVk)
        return
    Gui, KeyPick:Default
    GuiControlGet, hm,, GroupInterval
    if (hm = "")
        holdMs := DefaultInterval
    else
        holdMs := hm + 0
    if (holdMs < 0)
        holdMs := 0
    keyspec := TokenToHoldKeyspec(ChoosePendingToken)
    KeysArray .= (KeysArray ? " " : "") . "{HOLD" . holdMs . "|" . keyspec . "}"
    KeyPickRefreshList()
    ChooseHoldWaitUpVk := ChoosePendingVk
    ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
    SetTimer, ChooseHoldDetectTimer, Off
return

KeyDownMsg(wParam, lParam) {
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart, ChooseHoldWaitUpVk, KeyPickHwnd
    If (!IsChoosingKeys || !KeyPickHwnd)
        Return
    if (!WinActive("ahk_id " . KeyPickHwnd))
        Return
    Gui, KeyPick:Default
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
        KeyPickRefreshList()
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
    Global KeysArray, IsChoosingKeys, ChoosePendingVk, ChoosePendingToken, ChoosePendingStart, ChooseHoldWaitUpVk, DefaultInterval, KeyPickHwnd
    If (!IsChoosingKeys || !KeyPickHwnd)
        Return
    Gui, KeyPick:Default
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
    KeyPickRefreshList()
}

; === Подпрограмма выхода ===
MboxDoExit:
    ExitApp
Return

MboxOnExitCleanup:
    ReleaseAllHeldInfinite()
    return