# Puente de mando para el launcher de The Last Story
# - Lee el mando de Xbox (XInput) aunque otra ventana tenga el foco
# - Emite: COMBO (L3+R3, o Esc con el juego en primer plano), BTN A / B / UP / DOWN / LEFT / RIGHT (con repeticion)
# - Acepta por stdin: FOCUS <hwnd>, FOCUSPID <pid>, CLOSEPID <pid>, GAMEPID <pid>
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -TypeDefinition @"
using System;
using System.Threading;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
public static class TLSBridge {
  public static ConcurrentQueue<string> Cmds = new ConcurrentQueue<string>();
  public static void StartReader() {
    var t = new Thread(() => { string l; while ((l = Console.In.ReadLine()) != null) Cmds.Enqueue(l); Cmds.Enqueue("QUIT"); });
    t.IsBackground = true; t.Start();
  }
  [StructLayout(LayoutKind.Sequential)] public struct GP { public ushort b; public byte lt; public byte rt; public short lx; public short ly; public short rx; public short ry; }
  [StructLayout(LayoutKind.Sequential)] public struct ST { public uint pkt; public GP gp; }
  [DllImport("xinput1_4.dll")] public static extern int XInputGetState(int i, out ST s);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern IntPtr SetWindowLongPtr(IntPtr h, int i, IntPtr v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  // Ventana sin bordes: la ventana visible mas grande del proceso (la del juego) sin marco y centrada
  public static bool Borderless(uint pid, int w, int h) {
    IntPtr best = IntPtr.Zero; long area = 0;
    EnumWindows((hw, l) => {
      uint p; GetWindowThreadProcessId(hw, out p);
      if (p == pid && IsWindowVisible(hw)) { RECT r; GetWindowRect(hw, out r); long a = (long)(r.R - r.L) * (r.B - r.T); if (a > area) { area = a; best = hw; } }
      return true; }, IntPtr.Zero);
    if (best == IntPtr.Zero) return false;
    long st = (long)GetWindowLongPtr(best, -16);
    st &= ~(0x00C00000L | 0x00040000L | 0x00080000L | 0x00020000L | 0x00010000L);   // sin titulo, borde, menu, minimizar, maximizar
    SetWindowLongPtr(best, -16, (IntPtr)st);
    long ex = (long)GetWindowLongPtr(best, -20);
    ex &= ~(0x00000001L | 0x00000200L | 0x00020000L | 0x00000100L);                  // sin bordes extendidos
    SetWindowLongPtr(best, -20, (IntPtr)ex);
    int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
    if (w > sw || h > sh) { w = sw; h = sh; }
    SetWindowPos(best, IntPtr.Zero, (sw - w) / 2, (sh - h) / 2, w, h, 0x0020 | 0x0040 | 0x0004);   // FRAMECHANGED | SHOWWINDOW | NOZORDER
    return true;
  }
  public static uint ForegroundPid() { uint p = 0; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
  public static void Focus(IntPtr h) {
    if (h == IntPtr.Zero) return;
    keybd_event(0x12, 0, 0, UIntPtr.Zero);       // Alt: permite tomar el primer plano
    ShowWindow(h, 5); BringWindowToTop(h); SetForegroundWindow(h);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
}
"@

# --- Volumen en vivo: volumen de Dolphin en el mezclador de Windows (Core Audio). Bloque aparte:
#     si no compila, el resto del puente sigue funcionando y el launcher usa el volumen de Dolphin.
$audioOk = $false
try {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace TLSAudio {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo { }
  [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
  }
  [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
  }
  [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionManager2 {
    [PreserveSig] int GetAudioSessionControl(IntPtr guid, int flags, out IntPtr ctl);
    [PreserveSig] int GetSimpleAudioVolume(IntPtr guid, int flags, out IntPtr vol);
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
  }
  [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionEnumerator {
    [PreserveSig] int GetCount(out int count);
    [PreserveSig] int GetSession(int index, out IAudioSessionControl2 session);
  }
  [Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionControl2 {
    [PreserveSig] int GetState(out int state);
    [PreserveSig] int GetDisplayName(out IntPtr name);
    [PreserveSig] int SetDisplayName(IntPtr name, IntPtr ctx);
    [PreserveSig] int GetIconPath(out IntPtr path);
    [PreserveSig] int SetIconPath(IntPtr path, IntPtr ctx);
    [PreserveSig] int GetGroupingParam(out Guid g);
    [PreserveSig] int SetGroupingParam(IntPtr g, IntPtr ctx);
    [PreserveSig] int RegisterAudioSessionNotification(IntPtr n);
    [PreserveSig] int UnregisterAudioSessionNotification(IntPtr n);
    [PreserveSig] int GetSessionIdentifier(out IntPtr id);
    [PreserveSig] int GetSessionInstanceIdentifier(out IntPtr id);
    [PreserveSig] int GetProcessId(out uint pid);
  }
  [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISimpleAudioVolume {
    [PreserveSig] int SetMasterVolume(float level, ref Guid ctx);
    [PreserveSig] int GetMasterVolume(out float level);
  }
  public static class Mixer {
    // Devuelve cuantas sesiones de audio del proceso se ajustaron (0 = aun no suena nada)
    public static int SetVolume(uint pid, float level) {
      int done = 0;
      try {
        IMMDeviceEnumerator en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCo());
        IMMDevice dev;
        if (en.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return 0;
        Guid iid = typeof(IAudioSessionManager2).GUID;
        object o;
        if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0 || o == null) return 0;
        IAudioSessionManager2 mgr = (IAudioSessionManager2)o;
        IAudioSessionEnumerator list;
        if (mgr.GetSessionEnumerator(out list) != 0 || list == null) return 0;
        int n; list.GetCount(out n);
        for (int i = 0; i < n; i++) {
          IAudioSessionControl2 ctl;
          if (list.GetSession(i, out ctl) != 0 || ctl == null) continue;
          uint p; ctl.GetProcessId(out p);
          if (p != pid) continue;
          ISimpleAudioVolume v = ctl as ISimpleAudioVolume;
          if (v == null) continue;
          Guid g = Guid.Empty;
          if (v.SetMasterVolume(level, ref g) == 0) done++;
        }
      } catch { }
      return done;
    }
  }
}
"@
  $audioOk = $true
} catch { $audioOk = $false }

[void][TLSBridge]::SetProcessDPIAware()   # coordenadas reales de pantalla (escalado de Windows)
[TLSBridge]::StartReader()
$prev = 0
$comboLatch = $false
$gamePid = 0
$rep = @{ 1 = 0; 2 = 0; 4 = 0; 8 = 0 }
$f1Latch = $false
[Console]::Out.WriteLine('READY'); if ($audioOk) { [Console]::Out.WriteLine('AUDIO OK') } else { [Console]::Out.WriteLine('AUDIO NO') }; [Console]::Out.Flush()
$volPid = 0; $volTarget = -1; $volTick = 0; $volDone = $false

while ($true) {
  # --- comandos del launcher (sin bloquear)
  $line = $null
  while ([TLSBridge]::Cmds.TryDequeue([ref]$line)) {
    $p = $line.Split(' ')
    switch ($p[0]) {
      'FOCUS'    { [TLSBridge]::Focus([IntPtr][long]$p[1]) }
      'FOCUSPID' { $pr = Get-Process -Id ([int]$p[1]); if ($pr) { [TLSBridge]::Focus($pr.MainWindowHandle) } }
      'CLOSEPID' { $pr = Get-Process -Id ([int]$p[1]); if ($pr) { [void]$pr.CloseMainWindow() } }
      'GAMEPID'  { $gamePid = [uint32]$p[1] }
      'VOLUME'   { $volPid = [uint32]$p[1]; $volTarget = [int]$p[2]; $volTick = 0; $volDone = $false }
      'BORDERLESS' { [void][TLSBridge]::Borderless([uint32]$p[1], [int]$p[2], [int]$p[3]) }
      'QUIT'     { exit 0 }
    }
  }
  # --- volumen en vivo
  if ($audioOk -and $volTarget -ge 0 -and $volPid -ne 0) {
    $volTick--
    if ($volTick -le 0) {
      $n = [TLSAudio.Mixer]::SetVolume($volPid, [float]($volTarget / 100.0))
      if ($n -gt 0 -and -not $volDone) { [Console]::Out.WriteLine('VOLSET ' + $volTarget); $volDone = $true }
      $volTick = 33
    }
  }
  # --- mando
  $b = 0
  for ($i = 0; $i -lt 4; $i++) {
    $s = New-Object TLSBridge+ST
    if ([TLSBridge]::XInputGetState($i, [ref]$s) -eq 0) {
      $b = $b -bor $s.gp.b
      if ($s.gp.lx -lt -20000) { $b = $b -bor 0x0004 }
      if ($s.gp.lx -gt 20000)  { $b = $b -bor 0x0008 }
      if ($s.gp.ly -gt 20000)  { $b = $b -bor 0x0001 }
      if ($s.gp.ly -lt -20000) { $b = $b -bor 0x0002 }
    }
  }
  $both = (($b -band 0x00C0) -eq 0x00C0)
  if ($both -and -not $comboLatch) { [Console]::Out.WriteLine('COMBO'); $comboLatch = $true }
  if (-not $both) { $comboLatch = $false }
  # teclado: Esc con el juego delante = abrir 'volver al launcher'
  $f1 = (([TLSBridge]::GetAsyncKeyState(0x1B) -band 0x8000) -ne 0)
  if ($f1 -and -not $f1Latch -and $gamePid -ne 0 -and [TLSBridge]::ForegroundPid() -eq $gamePid) { [Console]::Out.WriteLine('COMBO KB') }
  $f1Latch = $f1
  $new = $b -band (-bnot $prev)
  if ($new -band 0x1000) { [Console]::Out.WriteLine('BTN A') }
  if ($new -band 0x2000) { [Console]::Out.WriteLine('BTN B') }
  # direcciones: al pulsar y, si se mantienen, repetición (para mover la barra de volumen)
  $dirs = @(@(0x0001, 'UP'), @(0x0002, 'DOWN'), @(0x0004, 'LEFT'), @(0x0008, 'RIGHT'))
  foreach ($d in $dirs) {
    $m = $d[0]
    if ($new -band $m) { [Console]::Out.WriteLine('BTN ' + $d[1]); $rep[$m] = 14 }
    elseif ($b -band $m) { $rep[$m]--; if ($rep[$m] -le 0) { [Console]::Out.WriteLine('BTN ' + $d[1]); $rep[$m] = 4 } }
  }
  [Console]::Out.Flush()
  $prev = $b
  Start-Sleep -Milliseconds 30
}
