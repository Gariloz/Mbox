; ===== WOW AUTO CYCLE =====

#NoEnv
#SingleInstance Force
SetBatchLines -1
#UseHook
SendMode Event
CoordMode, Mouse, Screen
SetMouseDelay, 0

global BIND_KEY := "f"
global SPAWN_DELAY := 6000
global STEP_DELAY := 1500
global MOUSE_DELAY := 500
global CYCLE_INTERVAL := 630000
global SOUND_ENABLED := false

global STATION_X := 959
global STATION_Y := 580
global DIALOG_X := 172
global DIALOG_Y := 439
global CREATE_ALL_X := 240
global CREATE_ALL_Y := 820
global MAILBOX_X := 1045
global MAILBOX_Y := 590
global SEND_X := 411
global SEND_Y := 540

global IsRunning := false
global CycleCount := 0
global CurrentStep := 0
global StepStartTime := 0

Gui, Destroy
Gui, +AlwaysOnTop +ToolWindow -Caption +LastFound
Gui, Color, 1E1E1E
Gui, Font, s10 cWhite, Consolas
Gui, Add, Text, vStep1 w250 Center, Step 1: Bind
Gui, Add, Text, vStep2 w250 Center, Step 2: Wait
Gui, Add, Text, vStep3 w250 Center, Step 3: Station
Gui, Add, Text, vStep4 w250 Center, Step 4: Tailoring
Gui, Add, Text, vStep5 w250 Center, Step 5: Create All
Gui, Add, Text, vStep6 w250 Center, Step 6: Mail
Gui, Add, Text, vStep7 w250 Center, Step 7: Send
Gui, Add, Text, vStep8 w250 Center, Step 8: Wait
Gui, Add, Text, vStatus w250 Center cGray, Press F1 to start
Gui, Show, x0 y0 NoActivate AutoSize, WoW Auto Cycle

return
F1::
    if (IsRunning)
        return
    WinActivate, World of Warcraft
    IsRunning := true
    CycleCount++
    CurrentStep := 1
    StepStartTime := A_TickCount
    UpdateStatus()
    if (SOUND_ENABLED)
        SoundPlay, sound.wav
    SetTimer, MainLoop, 100
return

F2::
    IsRunning := false
    CurrentStep := 0
    SetTimer, MainLoop, Off
    UpdateStatus()
    SoundBeep, 400, 500
return

UpdateStatus() {
    global IsRunning, CurrentStep, CycleCount, StepStartTime, CYCLE_INTERVAL
    
    if (IsRunning) {
        GuiControl, +cGreen, Status
        GuiControl,, Status, Cycle #%CycleCount%
        
        Loop, 7 {
            if (A_Index = CurrentStep) {
                GuiControl, +cYellow, Step%A_Index%
                if (A_Index = 1)
                    GuiControl,, Step%A_Index%, >>Step 1: Bind<<
                else if (A_Index = 2)
                    GuiControl,, Step%A_Index%, >>Step 2: Wait<<
                else if (A_Index = 3)
                    GuiControl,, Step%A_Index%, >>Step 3: Station<<
                else if (A_Index = 4)
                    GuiControl,, Step%A_Index%, >>Step 4: Tailoring<<
                else if (A_Index = 5)
                    GuiControl,, Step%A_Index%, >>Step 5: Create All<<
                else if (A_Index = 6)
                    GuiControl,, Step%A_Index%, >>Step 6: Mail<<
                else if (A_Index = 7)
                    GuiControl,, Step%A_Index%, >>Step 7: Send<<
            } else {
                GuiControl, +cWhite, Step%A_Index%
                if (A_Index = 1)
                    GuiControl,, Step%A_Index%, Step 1: Bind
                else if (A_Index = 2)
                    GuiControl,, Step%A_Index%, Step 2: Wait
                else if (A_Index = 3)
                    GuiControl,, Step%A_Index%, Step 3: Station
                else if (A_Index = 4)
                    GuiControl,, Step%A_Index%, Step 4: Tailoring
                else if (A_Index = 5)
                    GuiControl,, Step%A_Index%, Step 5: Create All
                else if (A_Index = 6)
                    GuiControl,, Step%A_Index%, Step 6: Mail
                else if (A_Index = 7)
                    GuiControl,, Step%A_Index%, Step 7: Send
            }
        }
        
        if (CurrentStep = 8) {
            GuiControl, +cYellow, Step8
        } else {
            GuiControl, +cWhite, Step8
            GuiControl,, Step8, Step 8: Wait
        }
    } else {
        GuiControl, +cRed, Status
        GuiControl,, Status, Press F1 to start
        
        Loop, 7 {
            GuiControl, +cWhite, Step%A_Index%
            if (A_Index = 1)
                GuiControl,, Step%A_Index%, Step 1: Bind
            else if (A_Index = 2)
                GuiControl,, Step%A_Index%, Step 2: Wait
            else if (A_Index = 3)
                GuiControl,, Step%A_Index%, Step 3: Station
            else if (A_Index = 4)
                GuiControl,, Step%A_Index%, Step 4: Tailoring
            else if (A_Index = 5)
                GuiControl,, Step%A_Index%, Step 5: Create All
            else if (A_Index = 6)
                GuiControl,, Step%A_Index%, Step 6: Mail
            else if (A_Index = 7)
                GuiControl,, Step%A_Index%, Step 7: Send
        }
        GuiControl, +cWhite, Step8
        GuiControl,, Step8, Step 8: Wait
    }
}

MainLoop:
    if (!IsRunning)
        return
    Elapsed := A_TickCount - StepStartTime
    
    if (CurrentStep = 1) {
        if (Elapsed >= STEP_DELAY) {
            SendInput, {Blind}{f down}
            SendInput, {Blind}{f up}
            CurrentStep := 2
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 2) {
        if (Elapsed >= SPAWN_DELAY) {
            Sleep, MOUSE_DELAY
            Click, %STATION_X%, %STATION_Y%
            CurrentStep := 3
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 3) {
        if (Elapsed >= STEP_DELAY) {
            Sleep, MOUSE_DELAY
            Click, %DIALOG_X%, %DIALOG_Y%
            CurrentStep := 4
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 4) {
        if (Elapsed >= STEP_DELAY) {
            Sleep, MOUSE_DELAY
            Click, %CREATE_ALL_X%, %CREATE_ALL_Y%
            CurrentStep := 5
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 5) {
        if (Elapsed >= STEP_DELAY) {
            Sleep, MOUSE_DELAY
            Click, %MAILBOX_X%, %MAILBOX_Y%
            CurrentStep := 6
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 6) {
        if (Elapsed >= STEP_DELAY) {
            Sleep, MOUSE_DELAY
            SendInput, {Blind}{Shift down}
            Click, %SEND_X%, %SEND_Y%
            SendInput, {Blind}{Shift up}
            CurrentStep := 7
            StepStartTime := A_TickCount
            UpdateStatus()
        }
    }
    else if (CurrentStep = 7) {
        if (Elapsed >= STEP_DELAY) {
            CurrentStep := 8
            StepStartTime := A_TickCount
            if (SOUND_ENABLED)
                SoundPlay, sound 2.wav
            UpdateStatus()
            SetTimer, UpdateTimer, 1000
        }
    }
    else if (CurrentStep = 8) {
        if (Elapsed >= CYCLE_INTERVAL) {
            CycleCount++
            CurrentStep := 1
            StepStartTime := A_TickCount
            SetTimer, UpdateTimer, Off
            UpdateStatus()
            if (SOUND_ENABLED)
                SoundPlay, sound.wav
            WinActivate, World of Warcraft
        }
    }
return

UpdateTimer:
    Elapsed := A_TickCount - StepStartTime
    Remaining := CYCLE_INTERVAL - Elapsed
    if (Remaining < 0)
        Remaining := 0
    secs := Floor(Remaining / 1000)
    mins := Floor(secs / 60)
    s := Mod(secs, 60)
    if (s < 10)
        sStr := "0" . s
    else
        sStr := s
    timeStr := "Step 8: " . mins . ":" . sStr
    GuiControl,, Step8, %timeStr%
return

GuiClose:
    ExitApp

F3::ExitApp