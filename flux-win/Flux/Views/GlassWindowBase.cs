using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using Flux.Interop;

namespace Flux.Views;

public class GlassWindowBase : Window
{
    protected nint Hwnd;

    public GlassWindowBase()
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        ShowActivated = true;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);

        Hwnd = new WindowInteropHelper(this).Handle;

        // Set WS_EX_TOOLWINDOW
        var exStyle = (uint)(long)NativeMethods.GetWindowLongPtr(Hwnd, NativeConstants.GWL_EXSTYLE);
        exStyle |= NativeConstants.WS_EX_TOOLWINDOW;
        exStyle &= ~NativeConstants.WS_EX_APPWINDOW;
        NativeMethods.SetWindowLongPtr(Hwnd, NativeConstants.GWL_EXSTYLE, (nint)exStyle);

        ApplyBackdrop();
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.Key == Key.Escape)
        {
            Close();
            e.Handled = true;
        }
        else if (e.Key == Key.W && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
        {
            Close();
            e.Handled = true;
        }
    }

    protected void EnableDragMove(object sender, MouseButtonEventArgs e)
    {
        // Only drag on non-interactive background areas
        if (e.OriginalSource is System.Windows.Controls.Button ||
            e.OriginalSource is System.Windows.Controls.TextBox ||
            e.OriginalSource is System.Windows.Controls.ComboBox ||
            e.OriginalSource is System.Windows.Controls.Slider ||
            e.OriginalSource is System.Windows.Controls.CheckBox ||
            e.OriginalSource is System.Windows.Controls.DataGrid)
            return;

        // Check parent chain for interactive controls
        if (e.OriginalSource is DependencyObject dep)
        {
            var parent = dep;
            while (parent != null)
            {
                if (parent is System.Windows.Controls.Button ||
                    parent is System.Windows.Controls.TextBox ||
                    parent is System.Windows.Controls.ComboBox ||
                    parent is System.Windows.Controls.Slider ||
                    parent is System.Windows.Controls.CheckBox ||
                    parent is System.Windows.Controls.DataGrid ||
                    parent is System.Windows.Controls.Primitives.Thumb)
                    return;
                parent = VisualTreeHelper.GetParent(parent);
            }
        }

        DragMove();
    }

    private void ApplyBackdrop()
    {
        var build = Environment.OSVersion.Version.Build;

        if (build >= 22621)
        {
            // Windows 11 22H2+ — system transient backdrop + rounded corners
            int backdropType = NativeConstants.DWMSBT_TRANSIENTWINDOW;
            NativeMethods.DwmSetWindowAttribute(Hwnd, NativeConstants.DWMWA_SYSTEMBACKDROP_TYPE,
                in backdropType, sizeof(int));

            int cornerPref = NativeConstants.DWMWCP_ROUND;
            NativeMethods.DwmSetWindowAttribute(Hwnd, NativeConstants.DWMWA_WINDOW_CORNER_PREFERENCE,
                in cornerPref, sizeof(int));

            // Almost transparent client background for backdrop to show through
            Background = new SolidColorBrush(Color.FromArgb(0x01, 0x00, 0x00, 0x00));
        }
        else if (build >= 22000)
        {
            // Windows 11 pre-22621 — rounded corners only
            int cornerPref = NativeConstants.DWMWCP_ROUND;
            NativeMethods.DwmSetWindowAttribute(Hwnd, NativeConstants.DWMWA_WINDOW_CORNER_PREFERENCE,
                in cornerPref, sizeof(int));

            ApplyFallbackSurface();
        }
        else
        {
            // Windows 10 fallback
            ApplyFallbackSurface();
        }
    }

    private void ApplyFallbackSurface()
    {
        Background = new SolidColorBrush(Color.FromArgb(0xCC, 0x1C, 0x1C, 0x1C));
    }
}
