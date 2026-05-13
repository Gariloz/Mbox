; =============================================================================
; MinimizedGame_KeyDelivery_Test.ahk
; Тест методов отправки клавиш в ОКНО БЕЗ АКТИВАЦИИ (игра должна быть СВЁРНУТА).
; Запускай от администратора, если игра под админом — иначе часть вызовов тихо не сработает.
; Ничего не разворачивает и не жмёт WinActivate. Тест 10 = как в Mbox: SendMessage WM_ACTIVATE(1), затем Post KEYDOWN/UP.
; Если НИ ОДИН тест не даёт реакции в игре — для этого клиента «чистый» фоновый ввод
; средствами AHK, скорее всего, недостижим (Unity + Raw Input).
; =============================================================================
#NoEnv
#SingleInstance Force
SetBatchLines -1
SendMode Input

global gRoot := 0, gChild := 0, gLog := ""

Gui, Font, s9, Segoe UI
Gui, Add, Text,, Процесс (exe):
Gui, Add, Edit, vEdExe w280, 7DaysToDie.exe
Gui, Add, Button, gBtnFind w120, Найти HWND
Gui, Add, Text, vStStatus w400, Статус: нажми «Найти HWND», сверни игру, затем тесты.
Gui, Add, Text,, Тестовая клавиша (VK десятичный, 32=Space, 87=W):
Gui, Add, Edit, vEdVk w80 Number, 32
Gui, Add, Text,, Свой HWND (0 = не использовать):
Gui, Add, Edit, vEdHwnd w120 Number, 0
Gui, Add, Text,, Разделитель между тестами (мс):
Gui, Add, Edit, vEdDelay w60 Number, 250

Gui, Add, GroupBox, w420 h270 Section, Одиночные тесты (окно игры СВЁРНУТО)
Gui, Add, Button, gT01 xs+10 ys+14 w400, 01 PostMessage WM_KEYDOWN/UP на ROOT
Gui, Add, Button, gT02 w400, 02 SendMessage WM_KEYDOWN/UP на ROOT
Gui, Add, Button, gT03 w400, 03 PostMessage WM_KEYDOWN/UP на крупный дочерний HWND
Gui, Add, Button, gT04 w400, 04 SendMessage WM_KEYDOWN/UP на дочерний
Gui, Add, Button, gT05 w400, 05 PostMessage WM_CHAR (ASCII) на ROOT
Gui, Add, Button, gT06 w400, 06 ControlSend {vk NN} на ROOT
Gui, Add, Button, gT07 w400, 07 ControlSend {vk NN} на CHILD
Gui, Add, Button, gT08 w400, 08 ControlSend {Blind}{vk NN} на ROOT
Gui, Add, Button, gT09 w400, 09 SendMessage WM_CHAR на ROOT
Gui, Add, Button, gT10 w400, 10 SendMessage WM_ACTIVATE(1) + Post KEYDOWN/UP ROOT (без ShowWindow)
Gui, Add, Button, gT11 w400, 11 Все тесты 01–09 подряд (лог)
Gui, Add, Button, gBtnClear w400, Очистить лог

Gui, Add, Edit, vEdLog r18 w420 ReadOnly
Gui, Show,, Minimized key delivery test
Return

GuiClose:
ExitApp

BtnClear:
    gLog := ""
    GuiControl,, EdLog,
Return

BtnFind:
    Gui, Submit, NoHide
    gRoot := 0, gChild := 0
    exe := Trim(EdExe)
    if (exe = "") {
        Status("Пустой exe")
        Return
    }
    if !RegExMatch(exe, "i)\.exe$")
        exe .= ".exe"
    Process, Exist, %exe%
    if !ErrorLevel {
        Status("Process Exist: не найдено")
        Return
    }
    pid := ErrorLevel
    DetectHiddenWindows, On
    hwnd := WinExist("ahk_pid " pid " ahk_class UnityWndClass")
    if (!hwnd)
        hwnd := WinExist("ahk_exe " exe)
    DetectHiddenWindows, Off
    if (!hwnd) {
        Status("Окно не найдено (DetectHidden)")
        Return
    }
    r := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (r)
        hwnd := r
    gRoot := hwnd
    gChild := ChildLargestByRect(gRoot)
    WinGet, pn, ProcessName, ahk_id %gRoot%
    WinGetClass, cl, ahk_id %gRoot%
    ico := DllCall("user32\IsIconic", "Ptr", gRoot)
    Status("ROOT=" gRoot "  CHILD=" gChild "  Iconic=" ico "  class=" cl "  exe=" pn)
    Log("Find: ROOT=" gRoot " CHILD=" gChild " Iconic=" ico)
Return

T01:
    T_PostRoot(0)
Return
T02:
    T_SendRoot(0)
Return
T03:
    T_PostChild(0)
Return
T04:
    T_SendChild(0)
Return
T05:
    T_PostCharRoot()
Return
T06:
    T_ControlRoot("")
Return
T07:
    T_ControlChild("{Blind}")
Return
T08:
    T_ControlRoot("{Blind}")
Return
T09:
    T_SendCharRoot()
Return
T10:
    T_ActivateMsgPost()
Return
T11:
    Gui, Submit, NoHide
    Gosub, BtnFind
    T_PostRoot(1)
    SleepDelay()
    T_SendRoot(1)
    SleepDelay()
    T_PostChild(1)
    SleepDelay()
    T_SendChild(1)
    SleepDelay()
    T_PostCharRoot()
    SleepDelay()
    T_ControlRoot("")
    SleepDelay()
    T_ControlChild("{Blind}")
    SleepDelay()
    T_ControlRoot("{Blind}")
    SleepDelay()
    T_SendCharRoot()
    Log("--- серия 01–09 завершена ---")
Return

SleepDelay() {
    global EdDelay
    Gui, Submit, NoHide
    d := EdDelay + 0
    if (d < 50)
        d := 50
    Sleep, %d%
}

Status(t) {
    GuiControl,, StStatus, %t%
}

Log(line) {
    global gLog
    FormatTime, ts,, HH:mm:ss
    gLog .= "[" ts "] " line "`r`n"
    GuiControl,, EdLog, %gLog%
}

ResolveTarget() {
    global gRoot, EdHwnd
    Gui, Submit, NoHide
    h := EdHwnd + 0
    if (h)
        return h
    return gRoot
}

GetVk() {
    global EdVk
    Gui, Submit, NoHide
    vk := EdVk + 0
    if (vk < 1 || vk > 254)
        vk := 32
    return vk
}

ChildLargestByRect(parent) {
    if (!parent)
        return 0
    best := 0, bestA := 0
    ch := DllCall("user32\GetWindow", "Ptr", parent, "UInt", 5, "Ptr")
    while (ch) {
        VarSetCapacity(rc, 16, 0)
        if (DllCall("user32\GetWindowRect", "Ptr", ch, "Ptr", &rc)) {
            w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
            h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
            a := w * h
            if (a > bestA) {
                bestA := a
                best := ch
            }
        }
        ch := DllCall("user32\GetWindow", "Ptr", ch, "UInt", 2, "Ptr")
    }
    return best
}

VkScan(vk) {
    return DllCall("user32\MapVirtualKey", "UInt", vk & 255, "UInt", 0) & 255
}

KeyLParam(vk, keyUp) {
    scan := VkScan(vk)
    lp := 1 | (scan << 16)
    if (keyUp)
        lp |= 0xC0000000
    return lp
}

VkHex(vk) {
    vk += 0
    ch := "0123456789ABCDEF"
    if (vk = 0)
        return "0"
    out := ""
    while (vk > 0) {
        d := Mod(vk, 16)
        out := SubStr(ch, d + 1, 1) . out
        vk := Floor(vk / 16)
    }
    return out
}

T_PostRoot(silent) {
    global gRoot
    tw := gRoot
    if (!tw) {
        if (!silent)
            Log("SKIP: нет ROOT")
        Return
    }
    vk := GetVk()
    lpD := KeyLParam(vk, 0), lpU := KeyLParam(vk, 1)
    r1 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x100, "Ptr", vk, "Ptr", lpD, "Int")
    r2 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x101, "Ptr", vk, "Ptr", lpU, "Int")
    Log("01 Post ROOT vk=" vk " ret=" r1 "," r2 " hwnd=" tw)
}

T_SendRoot(silent) {
    global gRoot
    tw := gRoot
    if (!tw) {
        if (!silent)
            Log("SKIP: нет ROOT")
        Return
    }
    vk := GetVk()
    lpD := KeyLParam(vk, 0), lpU := KeyLParam(vk, 1)
    r1 := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x100, "Ptr", vk, "Ptr", lpD, "Int")
    r2 := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x101, "Ptr", vk, "Ptr", lpU, "Int")
    Log("02 Send ROOT vk=" vk " ret=" r1 "," r2)
}

T_PostChild(silent) {
    global gChild, gRoot
    tw := gChild ? gChild : gRoot
    if (!tw) {
        if (!silent)
            Log("SKIP: нет CHILD/ROOT")
        Return
    }
    vk := GetVk()
    lpD := KeyLParam(vk, 0), lpU := KeyLParam(vk, 1)
    r1 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x100, "Ptr", vk, "Ptr", lpD, "Int")
    r2 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x101, "Ptr", vk, "Ptr", lpU, "Int")
    Log("03 Post CHILD vk=" vk " hwnd=" tw " ret=" r1 "," r2)
}

T_SendChild(silent) {
    global gChild, gRoot
    tw := gChild ? gChild : gRoot
    if (!tw) {
        if (!silent)
            Log("SKIP: нет CHILD/ROOT")
        Return
    }
    vk := GetVk()
    lpD := KeyLParam(vk, 0), lpU := KeyLParam(vk, 1)
    r1 := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x100, "Ptr", vk, "Ptr", lpD, "Int")
    r2 := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x101, "Ptr", vk, "Ptr", lpU, "Int")
    Log("04 Send CHILD vk=" vk " hwnd=" tw " ret=" r1 "," r2)
}

T_PostCharRoot() {
    global gRoot
    tw := gRoot
    if (!tw) {
        Log("SKIP: нет ROOT")
        Return
    }
    vk := GetVk()
    ch := vk
    if (vk >= 0x41 && vk <= 0x5A)
        ch := vk + 32
    r := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x102, "Ptr", ch, "Ptr", 1, "Int")
    Log("05 Post WM_CHAR char=" ch " ret=" r " ROOT=" tw)
}

T_SendCharRoot() {
    global gRoot
    tw := gRoot
    if (!tw) {
        Log("SKIP: нет ROOT")
        Return
    }
    vk := GetVk()
    ch := vk
    if (vk >= 0x41 && vk <= 0x5A)
        ch := vk + 32
    r := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x102, "Ptr", ch, "Ptr", 1, "Int")
    Log("09 Send WM_CHAR char=" ch " ret=" r " ROOT=" tw)
}

T_ControlRoot(blindPrefix) {
    global gRoot
    tw := ResolveTarget()
    if (!tw)
        tw := gRoot
    if (!tw) {
        Log("SKIP: нет HWND")
        Return
    }
    vk := GetVk()
    ks := (blindPrefix != "" ? blindPrefix : "") . "{vk " . VkHex(vk) . "}"
    prev := A_DetectHiddenWindows
    DetectHiddenWindows, On
    ControlSend,, %ks%, ahk_id %tw%
    DetectHiddenWindows, %prev%
    Log((blindPrefix != "" ? "08 " : "06 ") . "ControlSend ROOT ks=" ks " hwnd=" tw)
}

T_ControlChild(blindPrefix) {
    global gChild, gRoot
    tw := gChild ? gChild : gRoot
    if (!tw) {
        Log("SKIP: нет CHILD")
        Return
    }
    vk := GetVk()
    ks := (blindPrefix != "" ? blindPrefix : "") . "{vk " . VkHex(vk) . "}"
    prev := A_DetectHiddenWindows
    DetectHiddenWindows, On
    ControlSend,, %ks%, ahk_id %tw%
    DetectHiddenWindows, %prev%
    Log("07 ControlSend CHILD ks=" ks " hwnd=" tw)
}

T_ActivateMsgPost() {
    global gRoot
    tw := gRoot
    if (!tw) {
        Log("SKIP: нет ROOT")
        Return
    }
    vk := GetVk()
    lpD := KeyLParam(vk, 0), lpU := KeyLParam(vk, 1)
    r0 := DllCall("user32\SendMessageW", "Ptr", tw, "UInt", 0x0006, "Ptr", 1, "Ptr", 0, "Int")
    r1 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x100, "Ptr", vk, "Ptr", lpD, "Int")
    r2 := DllCall("user32\PostMessageW", "Ptr", tw, "UInt", 0x101, "Ptr", vk, "Ptr", lpU, "Int")
    Log("10 Send WM_ACTIVATE ret=" r0 " ; Post keys ret=" r1 "," r2)
}
