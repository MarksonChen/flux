using System.Windows;
using WinForms = System.Windows.Forms;

namespace Flux.Utilities;

public static class WindowPositioning
{
    public static WinForms.Screen GetScreenForWindow(Window window)
    {
        var handle = new System.Windows.Interop.WindowInteropHelper(window).Handle;
        if (handle != nint.Zero)
            return WinForms.Screen.FromHandle(handle);
        return WinForms.Screen.PrimaryScreen ?? WinForms.Screen.AllScreens[0];
    }

    public static WinForms.Screen? FindScreenByDeviceName(string? deviceName)
    {
        if (string.IsNullOrEmpty(deviceName)) return null;
        foreach (var screen in WinForms.Screen.AllScreens)
        {
            if (screen.DeviceName == deviceName)
                return screen;
        }
        return null;
    }

    public static (double left, double top) ClampToWorkingArea(
        double left, double top, double width, double height, WinForms.Screen screen)
    {
        var dpi = GetDpiScale(screen);
        var workLeft = screen.WorkingArea.Left / dpi;
        var workTop = screen.WorkingArea.Top / dpi;
        var workWidth = screen.WorkingArea.Width / dpi;
        var workHeight = screen.WorkingArea.Height / dpi;

        if (width > workWidth)
            left = workLeft;
        else
            left = Math.Max(workLeft, Math.Min(left, workLeft + workWidth - width));

        if (height > workHeight)
            top = workTop;
        else
            top = Math.Max(workTop, Math.Min(top, workTop + workHeight - height));

        return (left, top);
    }

    public static (double left, double top) CenterOnScreen(double width, double height, WinForms.Screen screen)
    {
        var dpi = GetDpiScale(screen);
        var workLeft = screen.WorkingArea.Left / dpi;
        var workTop = screen.WorkingArea.Top / dpi;
        var workWidth = screen.WorkingArea.Width / dpi;
        var workHeight = screen.WorkingArea.Height / dpi;

        var left = workLeft + (workWidth - width) / 2.0;
        var top = workTop + (workHeight - height) / 2.0;
        return (left, top);
    }

    public static (double left, double top) PositionDialogRelativeToOverlay(
        Window overlay, double dialogWidth, double dialogHeight)
    {
        var screen = GetScreenForWindow(overlay);
        var dpi = GetDpiScale(screen);

        double overlayLeft = overlay.Left;
        double overlayTop = overlay.Top;
        double overlayWidth = overlay.ActualWidth;

        // Horizontally center dialog over overlay
        double desiredX = overlayLeft + (overlayWidth - dialogWidth) / 2.0;
        // 10 DIPs above overlay
        double desiredY = overlayTop - dialogHeight - 10;

        var workTop = screen.WorkingArea.Top / dpi;

        // If off-screen above, place below
        if (desiredY < workTop)
            desiredY = overlayTop + overlay.ActualHeight + 10;

        // Clamp to working area
        return ClampToWorkingArea(desiredX, desiredY, dialogWidth, dialogHeight, screen);
    }

    private static double GetDpiScale(WinForms.Screen screen)
    {
        // Approximate DPI scale — WPF uses 96 DPI as baseline
        // For better accuracy we'd use GetDpiForMonitor, but this works for clamping
        try
        {
            using var g = System.Drawing.Graphics.FromHwnd(nint.Zero);
            return g.DpiX / 96.0;
        }
        catch
        {
            return 1.0;
        }
    }
}
