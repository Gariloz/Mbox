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
; Устанавливаем точность таймера 1ms для точных интервалов
DllCall("winmm\timeBeginPeriod", "UInt", 1)

; === Глобальные переменные ===
IsChoosingKeys := False
KeysArray := ""
Toggle := False
Groups := []
CurrentGroup := 1
TotalGroups := 0
QpcFreq := 0
NextFire := []
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
KeyListArmed := false   ; Захват клавиш активен (каретка мигает в списке клавиш)

; === Система таймеров (до 3 штук) ===
Timers0 := 0            ; Количество таймеров
TimerEnabled := false   ; Запущены ли таймеры
Timers1_Name := "", Timers1_Duration := 0, Timers1_Remaining := 0, Timers1_Active := false, Timers1_Start := 0
Timers2_Name := "", Timers2_Duration := 0, Timers2_Remaining := 0, Timers2_Active := false, Timers2_Start := 0
Timers3_Name := "", Timers3_Duration := 0, Timers3_Remaining := 0, Timers3_Active := false, Timers3_Start := 0

; === Горячие клавиши таймеров ===
Hotkey, % "$NumpadDiv", ToggleAllTimers, Off
Hotkey, % "$Numpad7", ToggleTimer1, Off
Hotkey, % "$Numpad8", ToggleTimer2, Off
Hotkey, % "$Numpad9", ToggleTimer3, Off

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
    ; Таймерные клавиши — активны вместе с основными биндами
    Hotkey, $NumpadDiv, ToggleAllTimers, %effectiveState%
    Hotkey, $Numpad7, ToggleTimer1, %effectiveState%
    Hotkey, $Numpad8, ToggleTimer2, %effectiveState%
    Hotkey, $Numpad9, ToggleTimer3, %effectiveState%
}

ToggleBindLock:
    Global GlobalBindsDisabled, IsChoosingKeys, TotalProcesses, TotalGroups
    ; При активном захвате клавиш — записать NumpadMult как бинд, не переключать LOCK
    if (CaptureGlobalKeyAsBind(0x6A, "NumpadMult"))
        Return
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
    ; Сначала маршрутизация (вкл/выкл захвата), затем запись клика если захват активен
    ChooseMouseClickRouting()
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

; --- Маршрутизация кликов ---
ChooseMouseClickRouting() {
    Global IsChoosingKeys, KeyListArmed, hKeyList, hGroupInterval
    if (!IsChoosingKeys)
        return
    MouseGetPos, mx, my, , ctrlHwnd, 2
    ; Клик по белому полю при АКТИВНОМ захвате → запись бинда происходит в ButtonDown
    if (ctrlHwnd && ctrlHwnd = hKeyList && KeyListArmed)
        return
    ; Клик вне зоны захвата → гасим захват
    if (KeyListArmed) {
        KeyListArmed := false
        UpdateCaptureState()
    }
    ; Снимаем каретку с интервала, если кликнули не по самому интервалу
    if (!(ctrlHwnd && ctrlHwnd = hGroupInterval))
        ControlFocus, Button1, Key Selection
}

; --- Обновление визуального индикатора захвата ---
UpdateCaptureState() {
    Global KeyListArmed, IsChoosingKeys
    if (!IsChoosingKeys)
        return
    if (KeyListArmed) {
        GuiControl, +cGreen, CaptureState
        GuiControl,, CaptureState, [ ЗАХВАТ АКТИВЕН — нажимай клавиши и кнопки ]
        ; Зелёный фон поля списка
        GuiControl, +BackgroundLime, KeyList
        ; Снимаем фокус с поля интервала, чтобы клавиши в него не печатались
        ControlFocus, Button1, Key Selection
    } else {
        GuiControl, +cRed, CaptureState
        GuiControl,, CaptureState, [ Клик по белому полю ниже, затем нажимай кнопки ]
        ; Обычный белый фон
        GuiControl, +BackgroundWhite, KeyList
    }
}

; --- Глобальные хоткеи при активном захвате записываются как бинды ---
; Возвращает true если клавиша перехвачена и записана (действие хоткея не выполняется)
CaptureGlobalKeyAsBind(vk, keyName) {
    Global IsChoosingKeys, KeyListArmed, KeysArray
    static lastVk := 0, lastT := 0
    if (!IsChoosingKeys || !KeyListArmed)
        return false
    ; Анти-автоповтор (клавиша удержана)
    if (vk = lastVk && A_TickCount - lastT < 500)
        return true
    lastVk := vk, lastT := A_TickCount
    ChooseFlushKeyboardPendingIfAny()
    ChooseFlushMousePendingIfAny()
    token := "{" keyName "}"
    KeysArray .= (KeysArray ? " " : "") . token
    GuiControl,, KeyList, %KeysArray%
    SoundBeep, 600, 60
    return true
}

MouseChooseButtonDown(btn, token) {
    Global IsChoosingKeys, ChoosePendingMouseBtn, ChoosePendingMouseToken, ChoosePendingMouseStart, ChooseHoldWaitUpMouse
    Global KeyListArmed, hKeyList, hGroupInterval
    if (!IsChoosingKeys || !WinActive("Key Selection"))
        return
    MouseGetPos, mx, my, , ctrlHwnd, 2
    inKeyList := (ctrlHwnd && ctrlHwnd = hKeyList)
    ; Клик по белому полю при выключенном захвате = ТОЛЬКО активация (не бинд)
    if (inKeyList && !KeyListArmed) {
        KeyListArmed := true
        UpdateCaptureState()
        return
    }
    ; Клик по контролам GUI (интервал) — не бинд никогда
    if (ctrlHwnd && ctrlHwnd = hGroupInterval)
        return
    ; Клик по кнопкам — не бинд, кнопка сама сработает
    MouseGetPos, , , , ctrlClass, 1
    if (RegExMatch(ctrlClass, "i)^Button\d+$"))
        return
    ; Дальше записываем ТОЛЬКО при активном захвате
    if (!KeyListArmed)
        return
    ; --- Здесь клик записывается как бинд ---
    ; Учитываем зажатые модификаторы (Shift/Ctrl/Alt/Win) для мышиных биндов
    mods := ""
    if (GetKeyState("Shift", "P"))
        mods .= "Shift+"
    if (GetKeyState("Ctrl", "P"))
        mods .= "Ctrl+"
    if (GetKeyState("Alt", "P"))
        mods .= "Alt+"
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        mods .= "Win+"
    ; Зажатые обычные клавиши (CapsLock, буквы, Esc и т.д.) тоже модификаторы
    if (GetKeyState("CapsLock", "T"))
        mods .= "CapsLock+"
    static trackVk := [0x1B, 0x09, 0x08, 0x2E, 0x2D, 0x24, 0x23, 0x22, 0x21, 0x20]
    Loop % trackVk.Length() {
        tvk := trackVk[A_Index]
        if (GetKeyState("vk" . VkToHex(tvk), "P")) {
            kn := VkKeyName(tvk)
            if (kn != "" && !InStr(mods, kn . "+"))
                mods .= kn . "+"
        }
    }
    ; Ожидающая отслеживаемая клавиша (ChoosePendingVk) — тоже модификатор
    Global ChoosePendingVk, ChoosePendingToken
    if (ChoosePendingVk && ChoosePendingToken != "") {
        pendKey := TokenToHoldKeyspec(ChoosePendingToken)
        pendKey := RegExReplace(pendKey, "^\{?", "")
        pendKey := RegExReplace(pendKey, "\}?$", "")
        if (pendKey != "" && !InStr(mods, pendKey . "+"))
            mods .= pendKey . "+"
    }
    if (mods != "")
        token := "{" . mods . SubStr(token, 2)  ; {Mod+LButton
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
        holdMs := 0
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
    KeyListArmed := false
    SetMainHotkeys("Off")
    Gui, Destroy
    Gui, Font, s10
    titleText := "Group " . CurrentGroup . " - Click on the buttons you want the script to press."
    Gui, Add, Text, x10 y10 w380 Center, %titleText%
    ; Индикатор состояния захвата клавиш
    Gui, Font, s9 cRed Bold
    Gui, Add, Text, x25 y30 w350 vCaptureState Center, [ Клик по белому полю ниже, затем нажимай кнопки ]
    Gui, Font, s10 cBlack
    ; Рамка-подпись вокруг зоны захвата
    Gui, Add, GroupBox, x15 y46 w370 h100, Клавиши для записи — КЛИКНИ СЮДА
    ; Поле списка клавиш — Text (без каретки)
    Gui, Add, Text, x25 y64 w350 h76 Border BackgroundWhite hwndhKeyList vKeyList,
    Gui, Add, Text, x25 y152, Interval (ms):
    Gui, Add, Edit, x105 y147 vGroupInterval w60 hwndhGroupInterval, %DefaultInterval%
    Gui, Add, Button, x25 y175 gConfirmKeys hwndhConfirmBtn, Confirm Selection
    Gui, Add, Button, x+10 gClearKeys, Clear buttons
    Gui, Add, Button, x+10 gAddAnotherGroup, Add Another Group
    Gui, Add, Button, x25 y205 gAddTimerGui, Add Timer
    timerInfo := BuildTimerListShort()
    Gui, Add, Text, x120 y209 w260 vTimerInfoText, %timerInfo%
    Gui, Show, w400 h240, Key Selection
    ; Убираем фокус с поля интервала (чтобы клавиши не печатались в него)
    ControlFocus, Button1, Key Selection
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
    OnMessage(0x104, "KeyDownMsg")   ; WM_SYSKEYDOWN (Alt-комбинации, F10)
    OnMessage(0x105, "KeyUpMsg")     ; WM_SYSKEYUP
Return

GuiClose:
    ExitApp
Return

ClearKeys:
    KeysArray := ""
    KeyListArmed := false
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
    KeyListArmed := false
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
    KeyListArmed := false
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
    StartProcessMonitor()
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
    ; === Блок таймеров в статусе ===
    timerLines := BuildTimerStatusLines()
    if (timerLines != "") {
        fullStatus .= "`n" . border . "`n"
        Loop, Parse, timerLines, `n
        {
            tLine := A_LoopField
            tPadding := ""
            Loop % (maxLen - StrLen(tLine))
                tPadding .= " "
            fullStatus .= "| " tLine tPadding " |"
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
    ; Защита: GUI статуса может не существовать (идёт выбор клавиш)
    GuiControlGet, sbExist,, StatusBorder
    if (sbExist = "")
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
    ; Пересчитать размер окна под новый текст (уменьшение и увеличение)
    Gui, Show, NoActivate AutoSize
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

; Возвращает текущее время в МИКРОСЕКУНДАХ (высокое разрешение)
QpcNowUsec() {
    Global QpcFreq
    static freq := 0
    if (!freq) {
        DllCall("kernel32\QueryPerformanceFrequency", "Int64*", freq)
        if (!freq)
            freq := 1000000
    }
    DllCall("kernel32\QueryPerformanceCounter", "Int64*", qpc)
    return (qpc * 1000000) // freq
}

; === Подпрограмма: точный движок отправки (абсолютное расписание, QPC, без дрейфа) ===
ToggleDeferredSendGroups:
    SetTimer, ToggleDeferredSendGroups, Off
    Global Toggle, TotalGroups, NextFire
    if (!Toggle)
        Return
    Loop {
        if (!Toggle)
            Return
        nowU := QpcNowUsec()
        ; Отправляем все группы, чей срок наступил
        Loop % TotalGroups {
            idx := A_Index
            if (nowU >= NextFire[idx]) {
                SendGroupKeys(idx)
                ivlU := Groups[idx].interval * 1000  ; мс -> мкс
                ; Абсолютное расписание: следующий тик = старый срок + интервал (дрейф не копится)
                if (NextFire[idx] > 0 && nowU - NextFire[idx] < ivlU)
                    NextFire[idx] := NextFire[idx] + ivlU
                else
                    NextFire[idx] := nowU + ivlU
            }
        }
        if (!Toggle)
            Return
        ; Ближайшее событие
        minDelayU := 0x7FFFFFFF
        Loop % TotalGroups {
            d := NextFire[A_Index] - nowU
            if (d < 1)
                d := 1
            if (d < minDelayU)
                minDelayU := d
        }
        if (!Toggle)
            Return
        if (minDelayU > 2000) {
            ; Далеко (>2мс): таймер, проснуться за 1.5мс до момента
            timerMs := (minDelayU - 1500) // 1000
            if (timerMs < 1)
                timerMs := 1
            SetTimer, ToggleDeferredSendGroups, % -timerMs
            Return
        }
        ; Последние 2мс: активное ожидание на QPC (максимальная точность)
        targetU := nowU + minDelayU
        while (QpcNowUsec() < targetU) {
            Sleep, 0  ; отдаёт квант, но не теряет точность
            if (!Toggle)
                Return
        }
        ; Момент настал (погрешность < 0.1мс) — цикл продолжается, отправка сразу
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
        UpdateStatus()
        UpdateIndicator()
        Return
    }
    ; Инициализация абсолютного расписания (в микросекундах QPC)
    Global NextFire
    nowU := QpcNowUsec()
    Loop % TotalGroups {
        NextFire[A_Index] := nowU + (Groups[A_Index].interval * 1000)
    }
    UpdateStatus()
    UpdateIndicator()
    SetTimer, ToggleDeferredSendGroups, -1
Return

; === Подпрограмма: перенастройка клавиш ===
RechooseKeys:
    If (IsChoosingKeys) {
        MsgBox, Finish key selection first.
        Return
    }
    ReleaseAllHeldInfinite()
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
    ShowStatusGUI := !ShowStatusGUI
    If (ShowStatusGUI)
    {
        ; Защита: если позиции пустые/невалидные — показать в сохранённых при создании
        if (StatusPosX = "" || StatusPosY = "")
            Gui, Show, NoActivate AutoSize
        else
            Gui, Show, x%StatusPosX% y%StatusPosY% NoActivate AutoSize
        UpdateStatus()
    }
    Else
    {
        ; Сохраняем позицию перед скрытием (только если окно реально существует)
        IfWinExist, Multi-PID Control
        {
            WinGetPos, StatusPosX, StatusPosY,,, Multi-PID Control
            if (StatusPosX = "" || StatusPosY = "") {
                StatusPosX := 0
                StatusPosY := 0
            }
        }
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
    ; Модификатором может быть ЛЮБАЯ клавиша слева от последнего "+"
    ; Формат: {Mod1+Mod2+Main} — моды зажимаются, main нажимается
    modifiers := ""
    mainKey := keyspec
    plusPos := InStr(keyspec, "+", false, 0)  ; последний "+"
    if (plusPos > 1) {
        modifiers := SubStr(keyspec, 1, plusPos - 1)
        mainKey := SubStr(keyspec, plusPos + 1)
        ; Разбиваем моды по "+"
        modifiers := StrReplace(modifiers, "+", " ")
    }
}

SendKeyspec_SimDown(h, keyspec) {
    ParseKeyspecModsMain(keyspec, modS, mainK)
    if (modS != "") {
        ; Любые модификаторы: зажимаем каждый по VK
        StringSplit, modParts, modS, %A_Space%
        Loop %modParts0% {
            mvk := GetKeyVK(modParts%A_Index%)
            if (mvk) {
                mvkH := VkToHex(mvk)
                ControlSend,, {Blind}{vk%mvkH% down}, ahk_id %h%
            }
        }
        ds := "{" . mainK . " down}"
        ControlSend,, {Blind}%ds%, ahk_id %h%
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton|MButton|XButton1|XButton2)$")) {
        ; Асинхронная мышь: PostMessage без SendMessage - не блокирует поток
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        root := KeyTargetGameRoot(h)
        if (!root)
            return
        if (modS != "")
            PostMsgModsDownFromList(h, modS)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x204, 2, lPar)
        else if (RegExMatch(mainK, "i)^MButton$"))
            PostMsgToFocus(h, 0x207, 4, lPar)
        else if (RegExMatch(mainK, "i)^XButton1$"))
            PostMsgToFocus(h, 0x20B, 8, lPar)
        else if (RegExMatch(mainK, "i)^XButton2$"))
            PostMsgToFocus(h, 0x20B, 16, lPar)
        else
            PostMsgToFocus(h, 0x201, 1, lPar)
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
        us := "{" . mainK . " up}"
        ControlSend,, {Blind}%us%, ahk_id %h%
        ; Отпускаем моды в обратном порядке
        StringSplit, modParts, modS, %A_Space%
        i := modParts0
        Loop %modParts0% {
            mvk := GetKeyVK(modParts%i%)
            if (mvk) {
                mvkH := VkToHex(mvk)
                ControlSend,, {Blind}{vk%mvkH% up}, ahk_id %h%
            }
            i -= 1
        }
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton|MButton|XButton1|XButton2)$")) {
        ; Асинхронная мышь: PostMessage
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x205, 0, lPar)
        else if (RegExMatch(mainK, "i)^MButton$"))
            PostMsgToFocus(h, 0x208, 0, lPar)
        else if (RegExMatch(mainK, "i)^XButton1$"))
            PostMsgToFocus(h, 0x20C, 8, lPar)
        else if (RegExMatch(mainK, "i)^XButton2$"))
            PostMsgToFocus(h, 0x20C, 16, lPar)
        else
            PostMsgToFocus(h, 0x202, 0, lPar)
        if (modS != "")
            PostMsgModsUpFromList(h, modS)
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
        ; Любые модификаторы (включая обычные клавиши) зажимаются
        PostMsgModsDownFromList(h, modS)
        vk := GetKeyVK(mainK)
        if (vk)
            PostMsgToFocus(h, 0x100, vk, PostMsgKeyLP(vk, 0, h))
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton|MButton|XButton1|XButton2)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        ; Зажимаем моды перед кликом
        if (modS != "")
            PostMsgModsDownFromList(h, modS)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x204, 2, lPar)
        else if (RegExMatch(mainK, "i)^MButton$"))
            PostMsgToFocus(h, 0x207, 4, lPar)
        else if (RegExMatch(mainK, "i)^XButton1$"))
            PostMsgToFocus(h, 0x20B, 8, lPar)
        else if (RegExMatch(mainK, "i)^XButton2$"))
            PostMsgToFocus(h, 0x20B, 16, lPar)
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
        PostMsgModsUpFromList(h, modS)
        return
    }
    if (RegExMatch(mainK, "i)^(LButton|RButton|MButton|XButton1|XButton2)$")) {
        ResolveClickClientCoords(h, mcX, mcY)
        lPar := ((mcY & 0xFFFF) << 16) | (mcX & 0xFFFF)
        if (RegExMatch(mainK, "i)^RButton$"))
            PostMsgToFocus(h, 0x205, 0, lPar)
        else if (RegExMatch(mainK, "i)^MButton$"))
            PostMsgToFocus(h, 0x208, 0, lPar)
        else if (RegExMatch(mainK, "i)^XButton1$"))
            PostMsgToFocus(h, 0x20C, 8, lPar)
        else if (RegExMatch(mainK, "i)^XButton2$"))
            PostMsgToFocus(h, 0x20C, 16, lPar)
        else
            PostMsgToFocus(h, 0x202, 0, lPar)
        ; Отпускаем моды после клика
        if (modS != "")
            PostMsgModsUpFromList(h, modS)
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

; --- Имя клавиши по VK (для отслеживания зажатых) ---
VkKeyName(vk) {
    static names := {}
    if (!names.Count()) {
        names[0x14] := "CapsLock"
        names[0x1B] := "Esc"
        names[0x09] := "Tab"
        names[0x08] := "Backspace"
        names[0x2E] := "Delete"
        names[0x2D] := "Insert"
        names[0x24] := "Home"
        names[0x23] := "End"
        names[0x22] := "PageDown"
        names[0x21] := "PageUp"
        names[0x20] := "Space"
        names[0x2C] := "PrintScreen"
        names[0x13] := "Pause"
        Loop 26
            names[0x40 + A_Index] := Chr(0x40 + A_Index)
        Loop 10
            names[0x2F + A_Index] := Chr(0x2F + A_Index)
        Loop 12
            names[0x6F + A_Index] := "F" . A_Index
    }
    return names.HasKey(vk) ? names[vk] : ""
}

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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
        if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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
            if (KeyDelay > 0)
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

ResolveClickClientCoords(hWnd, ByRef cX, ByRef cY) {
    cX := 0, cY := 0
    if (!hWnd)
        return
    ; Всегда используем реальные координаты курсора (без центрирования)
    MouseGetPos, sX, sY
    VarSetCapacity(pt, 8, 0)
    NumPut(sX, pt, 0, "Int")
    NumPut(sY, pt, 4, "Int")
    DllCall("user32\ScreenToClient", "Ptr", hWnd, "Ptr", &pt)
    cX := NumGet(pt, 0, "Int")
    cY := NumGet(pt, 4, "Int")
}

SendLeftClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    ; Получаем координаты курсора относительно окна
    ResolveClickClientCoords(hWndTarget, cX, cY)
    ; Только PostMessage - курсор НЕ двигается!
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    PostMsgToFocus(hWndTarget, 0x0200, 0, lParam)  ; WM_MOUSEMOVE
    PostMsgToFocus(hWndTarget, 0x201, 1, lParam)   ; WM_LBUTTONDOWN
    PostMsgToFocus(hWndTarget, 0x202, 0, lParam)   ; WM_LBUTTONUP
}

SendRightClickAtCursor(hWndTarget, useSimulation := False) {
    if (!hWndTarget)
        return
    ; Получаем координаты курсора относительно окна
    ResolveClickClientCoords(hWndTarget, cX, cY)
    ; Только PostMessage - курсор НЕ двигается!
    lParam := ((cY & 0xFFFF) << 16) | (cX & 0xFFFF)
    PostMsgToFocus(hWndTarget, 0x0200, 0, lParam)  ; WM_MOUSEMOVE
    PostMsgToFocus(hWndTarget, 0x204, 2, lParam)   ; WM_RBUTTONDOWN
    PostMsgToFocus(hWndTarget, 0x205, 0, lParam)   ; WM_RBUTTONUP
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

PostMsgToFocus(hWndTop, msg, wParam, lParam) {
    if (!hWndTop)
        return 0
    root := KeyTargetGameRoot(hWndTop)
    if (!root)
        return 0
    ; Просто отправляем сообщение без активации - PostMessage работает и так
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
        holdMs := 0
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
        holdMs := 0
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
    Global KeyListArmed
    If (!IsChoosingKeys)
        Return
    ; Фильтр поля интервала: только цифры, Backspace, Delete, стрелки (по HWND — надёжно)
    Global hGroupInterval
    ; Определяем HWND контрола с фокусом через GetGUIThreadInfo
    ; x64: cbSize=72, hwndFocus на смещении 16
    VarSetCapacity(gti, 72, 0)
    NumPut(72, gti, 0, "UInt")
    DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", &gti)
    focusedHwnd := NumGet(gti, 16, "Ptr")
    If (focusedHwnd && focusedHwnd = hGroupInterval)
    {
        vk := wParam
        isDigit := (vk >= 0x30 && vk <= 0x39) || (vk >= 0x60 && vk <= 0x69)
        isNavKey := (vk = 0x08 || vk = 0x2E || vk = 0x25 || vk = 0x26 || vk = 0x27 || vk = 0x28 || vk = 0x24 || vk = 0x23) ; BS Del Left Up Right Down Home End
        ; Ctrl-комбинации разрешаем (Ctrl+A выделить всё, Ctrl+C/V/X)
        ctrlHeld := GetKeyState("Ctrl", "P")
        If (isDigit || isNavKey || ctrlHeld)
            Return  ; разрешаем системе обработать
        Return 1  ; блокируем остальные символы
    }
    If (!KeyListArmed)
        Return
    ChooseFlushMousePendingIfAny()
    vk := wParam
    if (ChooseHoldWaitUpVk && vk = ChooseHoldWaitUpVk)
        Return
    ; Блокируем системное действие навигационных клавиш (Enter/Space/Tab/Esc
    ; иначе они "нажимают" сфокусированную кнопку GUI и меняют фокус)
    if (vk = 0x0D || vk = 0x20 || vk = 0x09 || vk = 0x1B || vk = 0x08)
        Return 1
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
            ; Имя по раскладке через GetKeyNameText (надёжно при Ctrl/Alt, даёт "Ф"/"A")
            sc := DllCall("user32\MapVirtualKeyW", "UInt", vk, "UInt", 0, "UInt")
            scanFull := (sc << 16) | ((extended & 1) << 24)
            VarSetCapacity(kbName, 128, 0)
            len := DllCall("user32\GetKeyNameTextW", "Int", scanFull, "Ptr", &kbName, "Int", 64)
            if (len > 0) {
                keyName := StrGet(&kbName, len, "UTF-16")
                ; Очистка от суффиксов типа "(Numpad 5)"
                keyName := RegExReplace(keyName, "\s*\(.*\)\s*$", "")
            } else if ((vk >= 0x41 && vk <= 0x5A) || (vk >= 0x30 && vk <= 0x39)) {
                keyName := Chr(vk)
            }
        }
    }
    If (keyName = "")
        Return
    ; === Определяем какие ещё клавиши зажаты (кроме стандартных модов) ===
    heldKeys := ""
    if (isCtrlPressed)
        heldKeys .= "Ctrl "
    if (isAltPressed)
        heldKeys .= "Alt "
    if (isShiftPressed)
        heldKeys .= "Shift "
    if (isWinPressed)
        heldKeys .= "Win "
    ; CapsLock как модификатор
    if (GetKeyState("CapsLock", "T") && vk != 0x14)
        heldKeys .= "CapsLock "
    ; Другие зажатые клавиши из списка отслеживания
    static trackVk := [0x14, 0x1B, 0x09, 0x08, 0x2E, 0x2D, 0x24, 0x23, 0x22, 0x21, 0x20]  ; Caps Esc Tab BS Del Ins Home End PgDn PgUp Space
    Loop % trackVk.Length() {
        tvk := trackVk[A_Index]
        if (tvk = vk)
            continue
        if (GetKeyState("vk" . VkToHex(tvk), "P"))
            heldKeys .= VkKeyName(tvk) . " "
    }
    ; Если есть уже отслеживаемая зажатая клавиша (ChoosePendingVk) — она тоже модификатор
    if (ChoosePendingVk && ChoosePendingVk != vk && ChoosePendingToken != "") {
        pendKey := TokenToHoldKeyspec(ChoosePendingToken)
        ; Берём имя без скобок
        pendKey := RegExReplace(pendKey, "^\{?", "")
        pendKey := RegExReplace(pendKey, "\}?$", "")
        heldKeys .= pendKey . " "
    }
    ; === Собираем комбинацию: моды + текущая клавиша ===
    combination := ""
    if (heldKeys != "") {
        ; Убираем дубли, формируем "Mod1+Mod2"
        StringSplit, hkParts, heldKeys, %A_Space%
        Loop %hkParts0% {
            part := hkParts%A_Index%
            if (part != "" && !InStr(combination, part . "+") && !InStr(combination, "+" . part . "+"))
                combination .= part . "+"
        }
    }
    combination .= keyName
    needBrace := (InStr(combination, "+") || StrLen(keyName) > 1 || RegExMatch(keyName, "^[A-Z]"))
    if (!needBrace && StrLen(keyName) = 1) {
        ac := Asc(SubStr(keyName, 1, 1))
        if (ac = 96 || ac = 37 || ac = 59 || ac = 91 || ac = 93 || ac = 94 || ac = 44 || ac > 127)
            needBrace := true
    }
    token := needBrace ? "{" combination "}" : keyName
    ; === Есть отслеживаемая клавиша? НЕ флашим — объединяем в комбинацию ===
    if (ChoosePendingVk && ChoosePendingVk != vk && ChoosePendingToken != "") {
        ; Вытаскиваем её имя, добавляем в начало комбинации
        pendSpec := TokenToHoldKeyspec(ChoosePendingToken)
        pendMain := pendSpec
        pPlus := InStr(pendSpec, "+", false, 0)
        if (pPlus > 1) {
            pendMods := SubStr(pendSpec, 1, pPlus - 1)
            pendMain := SubStr(pendSpec, pPlus + 1)
        } else {
            pendMods := ""
        }
        ; Новая комбинация: pendMods + pendMain + (уже собранные моды) + keyName
        newComb := ""
        if (pendMods != "")
            newComb .= pendMods . "+"
        newComb .= pendMain . "+"
        ; Добавляем моды из heldKeys (без дублирования pendMain)
        if (heldKeys != "") {
            StringSplit, hkParts2, heldKeys, %A_Space%
            Loop %hkParts2_0% {
                part := hkParts2%A_Index%
                if (part != "" && part != pendMain && !InStr(newComb, part . "+") && !InStr(newComb, "+" . part . "+"))
                    newComb .= part . "+"
            }
        }
        newComb .= keyName
        token := "{" newComb "}"
        ; Сбрасываем pending — теперь он часть комбинации
        SetTimer, ChooseHoldDetectTimer, Off
        ChoosePendingVk := 0, ChoosePendingToken := "", ChoosePendingStart := 0
        ; Начинаем отслеживать всю комбинацию как новую pending
        ChoosePendingVk := vk
        ChoosePendingToken := token
        ChoosePendingStart := A_TickCount
        SetTimer, ChooseHoldDetectTimer, -1000
        Return
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
    Global KeyListArmed
    If (!IsChoosingKeys)
        Return
    If (!KeyListArmed)
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
        holdMs := 0
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
    ; При активном захвате клавиш — записать NumpadSub как бинд, не выходить
    if (CaptureGlobalKeyAsBind(0x6D, "NumpadSub"))
        Return
    ReleaseAllHeldInfinite()
    SetTimer, TimerTick, Off
    ; Восстанавливаем стандартную точность таймера
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    ExitApp
Return

; ======================================================================
; === СИСТЕМА ТАЙМЕРОВ ===
; ======================================================================

; --- Открытие окна добавления таймера ---
AddTimerGui:
    KeyListArmed := false
    Gui, TimerWin:Destroy
    Gui, TimerWin:Add, Text, x10 y10, Timer name:
    Gui, TimerWin:Add, Edit, x10 y30 w220 vNewTimerName, % "Timer " (Timers0 + 1)
    Gui, TimerWin:Add, Text, x10 y60, Duration (seconds):
    Gui, TimerWin:Add, Edit, x10 y80 w220 vNewTimerDuration
    Gui, TimerWin:Add, Button, x10 y110 w100 gSaveNewTimer, OK
    Gui, TimerWin:Add, Button, x+10 y110 w100 gTimerWinCancel, Cancel
    Gui, TimerWin:Show, w240 h150, Add Timer
Return

TimerWinCancel:
    Gui, TimerWin:Destroy
Return

TimerWinGuiClose:
    Gui, TimerWin:Destroy
Return

SaveNewTimer:
    Gui, TimerWin:Submit
    if (NewTimerName = "" || NewTimerDuration = "" || NewTimerDuration < 1) {
        MsgBox, 48, Add Timer, Enter name and duration (seconds, > 0).
        return
    }
    if (Timers0 >= 3) {
        MsgBox, 48, Add Timer, Maximum 3 timers.
        return
    }
    Timers0 += 1
    idx := Timers0
    Timers%idx%_Name := NewTimerName
    Timers%idx%_Duration := NewTimerDuration + 0
    Timers%idx%_Remaining := Timers%idx%_Duration * 1000
    Timers%idx%_Active := false
    Gui, TimerWin:Destroy
    RefreshTimerInfo()
Return

; --- Обновление строки списка таймеров в окне выбора клавиш ---
RefreshTimerInfo() {
    txt := BuildTimerListShort()
    GuiControl,, TimerInfoText, %txt%
}

BuildTimerListShort() {
    Global Timers0
    if (Timers0 = 0)
        return "Timers: none"
    out := ""
    Loop %Timers0% {
        nm := Timers%A_Index%_Name
        dur := Timers%A_Index%_Duration
        out .= A_Index ". " nm " (" dur "s)  "
    }
    return "Timers: " out
}

; --- Старт/пауза всех таймеров (NumpadDiv) ---
ToggleAllTimers:
    if (Timers0 = 0) {
        ShowToolTipMsg("No timers configured")
        return
    }
    TimerEnabled := !TimerEnabled
    if (TimerEnabled) {
        Loop %Timers0% {
            Timers%A_Index%_Active := true
            Timers%A_Index%_Start := A_TickCount
        }
        SetTimer, TimerTick, 200
        SoundBeep, 800, 150
    } else {
        SoundBeep, 400, 150
    }
    UpdateStatus()
Return

; --- Отдельные таймеры (Numpad7/8/9) ---
ToggleTimer1:
    ToggleOneTimer(1)
Return
ToggleTimer2:
    ToggleOneTimer(2)
Return
ToggleTimer3:
    ToggleOneTimer(3)
Return

ToggleOneTimer(idx) {
    Global Timers0, TimerEnabled
    if (idx > Timers0) {
        ShowToolTipMsg("Timer " idx " does not exist")
        return
    }
    wasActive := Timers%idx%_Active
    Timers%idx%_Active := !wasActive
    if (Timers%idx%_Active) {
        Timers%idx%_Start := A_TickCount
        TimerEnabled := true
        SetTimer, TimerTick, 200
        SoundBeep, 700, 120
    } else {
        CheckAnyTimerActive()
        SoundBeep, 350, 120
    }
    UpdateStatus()
}

CheckAnyTimerActive() {
    Global Timers0, TimerEnabled
    TimerEnabled := false
    Loop %Timers0% {
        if (Timers%A_Index%_Active) {
            TimerEnabled := true
            break
        }
    }
    if (!TimerEnabled)
        SetTimer, TimerTick, Off
}

; --- Основной цикл таймеров (тикает каждые 200мс) ---
TimerTick:
    Global Timers0, TimerEnabled
    if (!TimerEnabled)
        return
    Loop %Timers0% {
        if (!Timers%A_Index%_Active)
            continue
        elapsed := A_TickCount - Timers%A_Index%_Start
        rem := (Timers%A_Index%_Duration * 1000) - elapsed
        Timers%A_Index%_Remaining := rem
        if (rem <= 0) {
            Timers%A_Index%_Active := false
            Timers%A_Index%_Remaining := 0
            ShowTimerAlert(A_Index)
            return
        }
    }
    CheckAnyTimerActive()
    UpdateStatus()
Return

; --- Оповещение об окончании ---
ShowTimerAlert(idx) {
    Global Timers0, TimerEnabled
    nm := Timers%idx%_Name
    dur := Timers%idx%_Duration
    ; Звук: 3 сигнала
    SoundBeep, 1000, 300
    Sleep, 150
    SoundBeep, 1200, 300
    Sleep, 150
    SoundBeep, 1500, 400
    MsgBox, 36, Timer Expired!, Timer "%nm%" (%dur%s) has expired!`n`nRestart this timer?
    IfMsgBox, Yes
    {
        Timers%idx%_Active := true
        Timers%idx%_Start := A_TickCount
        Timers%idx%_Remaining := Timers%idx%_Duration * 1000
        TimerEnabled := true
        SetTimer, TimerTick, 200
    }
    else
    {
        CheckAnyTimerActive()
    }
    UpdateStatus()
}

; --- Вспомогательная функция: ToolTip на 1.5 сек ---
ShowToolTipMsg(msg) {
    ToolTip, %msg%
    SetTimer, ClearToolTip, -1500
}

ClearToolTip:
    ToolTip
Return

; --- Форматирование времени MM:SS ---
TimerFormatMs(ms) {
    totalSec := Floor(ms / 1000)
    m := Floor(totalSec / 60)
    s := Mod(totalSec, 60)
    return SubStr("0" m, -1) ":" SubStr("0" s, -1)
}

; --- Строка таймеров для статус-панели ---
BuildTimerStatusLines() {
    Global Timers0
    if (Timers0 = 0)
        return ""
    out := ""
    Loop %Timers0% {
        nm := Timers%A_Index%_Name
        dur := Timers%A_Index%_Duration * 1000
        rem := Timers%A_Index%_Remaining
        act := Timers%A_Index%_Active
        st := act ? ">" : "|"
        remStr := TimerFormatMs(rem)
        durStr := TimerFormatMs(dur)
        ; Прогресс-бар из 8 символов
        if (dur > 0)
            prog := Floor((rem / dur) * 8)
        else
            prog := 0
        bar := ""
        Loop 8 {
            bar .= (A_Index <= prog) ? "#" : "-"
        }
        out .= st " " nm ": " remStr "/" durStr " " bar
        if (A_Index < Timers0)
            out .= "`n"
    }
    return out
}

; ======================================================================
; === ДИНАМИЧЕСКИЙ МОНИТОРИНГ ПРОЦЕССОВ ===
; ======================================================================

; --- Запуск мониторинга (вызывается после настройки процессов) ---
StartProcessMonitor() {
    SetTimer, ProcessMonitorTick, 1000
}

; --- Тик мониторинга: удаляем мёртвые, добавляем новые окна по имени ---
ProcessMonitorTick:
    if (IsChoosingKeys || TotalProcesses = 0)
        return
    changed := RefreshProcessList()
    if (changed)
        UpdateStatus()
Return

; --- Пересборка списка процессов: возвращает 1 если состав изменился ---
RefreshProcessList() {
    Global TargetPIDArray, TargetProcessArray, TargetHwndArray, TotalProcesses
    changed := 0

    ; Шаг 1: удаляем мёртвые PID
    newPids := [], newNames := [], newHwnds := []
    Loop % TotalProcesses {
        pid := TargetPIDArray[A_Index]
        nm := TargetProcessArray[A_Index]
        h := TargetHwndArray[A_Index]
        if (ProcessExist(pid)) {
            ; Жив — проверяем что окно ещё валидно, иначе ищем новое окно того же процесса
            if (!h || !DllCall("user32\IsWindow", "Ptr", h)) {
                newH := FindWindowForPid(pid)
                if (newH) {
                    h := newH
                    changed := 1
                }
            }
            newPids.Push(pid), newNames.Push(nm), newHwnds.Push(h)
        } else {
            changed := 1  ; процесс умер
        }
    }
    aliveNames := {}
    Loop % newPids.Length()
        aliveNames[newNames[A_Index]] := 1

    ; Шаг 2: ищем новые окна процессов по тем же именам
    for exeName, _ in aliveNames {
        DetectHiddenWindows, On
        WinGet, hwndList, List, ahk_exe %exeName%
        DetectHiddenWindows, Off
        Loop %hwndList% {
            h := hwndList%A_Index% + 0
            r := DllCall("user32\GetAncestor", "Ptr", h, "UInt", 2, "Ptr")
            if (!r)
                r := h
            ; Уже отслеживаем этот корневой HWND?
            already := 0
            Loop % newHwnds.Length() {
                if (newHwnds[A_Index] = r) {
                    already := 1
                    break
                }
            }
            if (already)
                continue
            vis := DllCall("user32\IsWindowVisible", "Ptr", r)
            ico := DllCall("user32\IsIconic", "Ptr", r)
            if (!vis && !ico)
                continue
            WinGet, wpid, PID, ahk_id %r%
            ; Уже отслеживаем этот PID?
            pidDup := 0
            Loop % newPids.Length() {
                if (newPids[A_Index] = wpid) {
                    pidDup := 1
                    break
                }
            }
            if (pidDup)
                continue
            ; Новый процесс — добавляем
            newPids.Push(wpid), newNames.Push(exeName), newHwnds.Push(r)
            changed := 1
        }
    }

    ; Шаг 3: применяем изменения
    if (changed) {
        TargetPIDArray := newPids
        TargetProcessArray := newNames
        TargetHwndArray := newHwnds
        TotalProcesses := newPids.Length()
        ; Если все процессы умерли — останавливаем отправку
        if (TotalProcesses = 0 && Toggle) {
            Toggle := false
            ReleaseAllHeldInfinite()
            SetTimer, ToggleDeferredSendGroups, Off
            UpdateIndicator()
        }
    }
    return changed
}

; --- Проверка жив ли процесс по PID ---
ProcessExist(pid) {
    Process, Exist, %pid%
    return ErrorLevel
}

; --- Поиск нового окна для живого PID ---
FindWindowForPid(pid) {
    DetectHiddenWindows, On
    WinGet, hl, List, ahk_pid %pid%
    DetectHiddenWindows, Off
    Loop %hl% {
        h := hl%A_Index% + 0
        r := DllCall("user32\GetAncestor", "Ptr", h, "UInt", 2, "Ptr")
        if (!r)
            r := h
        return r
    }
    return 0
}