using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using Flux.Interop;
using Flux.Models;
using WinForms = System.Windows.Forms;

namespace Flux.Services;

public sealed class FullscreenMonitor : IDisposable
{
    private readonly Views.TimerWindow _overlay;
    private readonly Func<AppSettings> _getSettings;
    private nint _foregroundHook;
    private nint _locationHook;
    private WinEventDelegate? _foregroundDelegate;
    private WinEventDelegate? _locationDelegate;
    private readonly uint _ownPid;
    private bool _disposed;

    public FullscreenMonitor(Views.TimerWindow overlay, Func<AppSettings> getSettings)
    {
        _overlay = overlay;
        _getSettings = getSettings;
        _ownPid = (uint)Environment.ProcessId;
    }

    public void Start()
    {
        _foregroundDelegate = OnWinEvent;
        _locationDelegate = OnWinEvent;

        _foregroundHook = NativeMethods.SetWinEventHook(
            NativeConstants.EVENT_SYSTEM_FOREGROUND,
            NativeConstants.EVENT_SYSTEM_FOREGROUND,
            nint.Zero, _foregroundDelegate, 0, 0,
            NativeConstants.WINEVENT_OUTOFCONTEXT);

        _locationHook = NativeMethods.SetWinEventHook(
            NativeConstants.EVENT_OBJECT_LOCATIONCHANGE,
            NativeConstants.EVENT_OBJECT_LOCATIONCHANGE,
            nint.Zero, _locationDelegate, 0, 0,
            NativeConstants.WINEVENT_OUTOFCONTEXT);
    }

    public void Reevaluate()
    {
        if (_disposed) return;

        var settings = _getSettings();

        // If ShowInFullScreen is on, always show
        if (settings.ShowInFullScreen)
        {
            ShowOverlay();
            return;
        }

        var fgHwnd = NativeMethods.GetForegroundWindow();

        // No foreground window
        if (fgHwnd == nint.Zero)
        {
            ShowOverlay();
            return;
        }

        // Check if foreground is our own process
        NativeMethods.GetWindowThreadProcessId(fgHwnd, out uint fgPid);
        if (fgPid == _ownPid)
        {
            ShowOverlay();
            return;
        }

        // Check if minimized or not visible
        if (NativeMethods.IsIconic(fgHwnd) || !NativeMethods.IsWindowVisible(fgHwnd))
        {
            ShowOverlay();
            return;
        }

        // Check if cloaked
        if (NativeMethods.DwmGetWindowAttribute(fgHwnd, NativeConstants.DWMWA_CLOAKED,
                out uint cloaked, sizeof(uint)) == 0 && cloaked != 0)
        {
            ShowOverlay();
            return;
        }

        // Get foreground visible bounds
        RECT fgRect;
        if (NativeMethods.DwmGetWindowAttribute(fgHwnd, NativeConstants.DWMWA_EXTENDED_FRAME_BOUNDS,
                out fgRect, (uint)Marshal.SizeOf<RECT>()) != 0)
        {
            NativeMethods.GetWindowRect(fgHwnd, out fgRect);
        }

        // Determine screens
        var overlayScreen = Utilities.WindowPositioning.GetScreenForWindow(_overlay);
        var fgScreen = WinForms.Screen.FromRectangle(
            new System.Drawing.Rectangle(fgRect.Left, fgRect.Top, fgRect.Width, fgRect.Height));

        if (overlayScreen.DeviceName != fgScreen.DeviceName)
        {
            ShowOverlay();
            return;
        }

        // Compare foreground rect to screen full bounds (not working area)
        var screenBounds = overlayScreen.Bounds;
        const int tolerance = 2;

        bool coversScreen =
            fgRect.Left <= screenBounds.Left + tolerance &&
            fgRect.Top <= screenBounds.Top + tolerance &&
            fgRect.Right >= screenBounds.Right - tolerance &&
            fgRect.Bottom >= screenBounds.Bottom - tolerance;

        if (coversScreen)
            HideOverlay();
        else
            ShowOverlay();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        if (_foregroundHook != nint.Zero)
            NativeMethods.UnhookWinEvent(_foregroundHook);
        if (_locationHook != nint.Zero)
            NativeMethods.UnhookWinEvent(_locationHook);
    }

    private void OnWinEvent(nint hWinEventHook, uint eventType, nint hwnd,
        int idObject, int idChild, uint idEventThread, uint dwmsEventTime)
    {
        _overlay.Dispatcher.BeginInvoke(Reevaluate, DispatcherPriority.Background);
    }

    private void HideOverlay()
    {
        if (!_overlay.IsAutoHiddenForFullscreen && _overlay.IsVisible)
        {
            _overlay.Hide();
            _overlay.IsAutoHiddenForFullscreen = true;
        }
    }

    private void ShowOverlay()
    {
        if (_overlay.IsAutoHiddenForFullscreen)
        {
            _overlay.Show();
            _overlay.ReassertTopmost();
            _overlay.IsAutoHiddenForFullscreen = false;
        }
    }
}
