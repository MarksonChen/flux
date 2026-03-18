using System.Runtime.InteropServices;

namespace Flux.Interop;

[UnmanagedFunctionPointer(CallingConvention.Winapi)]
internal delegate void WinEventDelegate(
    nint hWinEventHook,
    uint eventType,
    nint hwnd,
    int idObject,
    int idChild,
    uint idEventThread,
    uint dwmsEventTime);

internal static partial class NativeMethods
{
    [LibraryImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    internal static partial nint GetWindowLongPtr(nint hWnd, int nIndex);

    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    internal static partial nint SetWindowLongPtr(nint hWnd, int nIndex, nint dwNewLong);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool UnregisterHotKey(nint hWnd, int id);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool SetWindowPos(
        nint hWnd,
        nint hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags);

    [LibraryImport("user32.dll")]
    internal static partial nint GetForegroundWindow();

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool GetWindowRect(nint hWnd, out RECT lpRect);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool IsWindowVisible(nint hWnd);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool IsIconic(nint hWnd);

    [LibraryImport("user32.dll")]
    internal static partial uint GetWindowThreadProcessId(nint hWnd, out uint processId);

    [LibraryImport("user32.dll")]
    internal static partial uint GetDpiForWindow(nint hWnd);

    [LibraryImport("user32.dll", SetLastError = true)]
    internal static partial nint SetWinEventHook(
        uint eventMin,
        uint eventMax,
        nint hmodWinEventProc,
        WinEventDelegate lpfnWinEventProc,
        uint idProcess,
        uint idThread,
        uint dwFlags);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool UnhookWinEvent(nint hWinEventHook);

    [LibraryImport("dwmapi.dll")]
    internal static partial int DwmGetWindowAttribute(
        nint hwnd,
        uint dwAttribute,
        out RECT pvAttribute,
        uint cbAttribute);

    [LibraryImport("dwmapi.dll")]
    internal static partial int DwmGetWindowAttribute(
        nint hwnd,
        uint dwAttribute,
        out uint pvAttribute,
        uint cbAttribute);

    [LibraryImport("dwmapi.dll")]
    internal static partial int DwmSetWindowAttribute(
        nint hwnd,
        uint dwAttribute,
        in int pvAttribute,
        uint cbAttribute);
}
