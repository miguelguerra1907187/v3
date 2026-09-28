<#
  Edge-Pestana1.ps1
  -----------------
  Trae Microsoft Edge al frente y lo pone en la pestana 1 (Ctrl+1).
  Si Edge no esta abierto, lo abre. Sin preguntas ni pantallas: se
  corre, hace eso y se cierra solo.
#>

Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class EdgeFoco {
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);

    public static bool EsElFrente(IntPtr hWnd) { return GetForegroundWindow() == hWnd; }

    public static void ForceForeground(IntPtr hWnd) {
        // Alt fantasma para que Windows deje cambiar la ventana del frente.
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        keybd_event(0x12, 0, 0x2, UIntPtr.Zero);
        IntPtr fg = GetForegroundWindow();
        uint dummy;
        uint fgThread = GetWindowThreadProcessId(fg, out dummy);
        uint curThread = GetCurrentThreadId();
        bool attached = false;
        if (fgThread != curThread) { attached = AttachThreadInput(curThread, fgThread, true); }
        ShowWindow(hWnd, IsIconic(hWnd) ? 9 : 5);
        BringWindowToTop(hWnd);
        SetForegroundWindow(hWnd);
        if (attached) { AttachThreadInput(curThread, fgThread, false); }
    }
}
"@

function Get-VentanaEdge {
    Get-Process -Name msedge -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
        Select-Object -First 1
}

$edge = Get-VentanaEdge

if (-not $edge) {
    # Edge no esta abierto: se abre y se espera a que aparezca su ventana
    # (hasta ~10 s). Al abrir, Edge ya queda en su primera pestana.
    Start-Process 'msedge'
    for ($i = 0; $i -lt 40 -and -not $edge; $i++) {
        Start-Sleep -Milliseconds 250
        $edge = Get-VentanaEdge
    }
    if (-not $edge) { exit }
    Start-Sleep -Milliseconds 500
}

[EdgeFoco]::ForceForeground($edge.MainWindowHandle)
Start-Sleep -Milliseconds 300
if (-not [EdgeFoco]::EsElFrente($edge.MainWindowHandle)) {
    # Segundo intento si Windows no lo dejo pasar al frente la primera vez.
    [EdgeFoco]::ForceForeground($edge.MainWindowHandle)
    Start-Sleep -Milliseconds 300
}

# Solo manda Ctrl+1 si Edge si quedo al frente, para no mandarselo a otra ventana.
if ([EdgeFoco]::EsElFrente($edge.MainWindowHandle)) {
    [System.Windows.Forms.SendKeys]::SendWait('^1')
}
