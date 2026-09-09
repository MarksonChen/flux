using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using Flux.Interop;
using Flux.Models;
using Flux.Services;
using Flux.Utilities;
using WinForms = System.Windows.Forms;

namespace Flux.Views;

public partial class TimerWindow : Window
{
    private readonly TimerController _timerController;
    private readonly PersistenceService _persistenceService;
    private readonly Func<Models.PersistedState> _getState;
    private readonly Action<string> _handleAction;

    private nint _hwnd;
    private double _previousWidth;
    private bool _isDragging;
    private Point _dragStartPoint;
    private bool _pendingLeftClick;
    private bool _pendingRightClick;
    private System.Windows.Threading.DispatcherTimer? _leftClickTimer;
    private System.Windows.Threading.DispatcherTimer? _rightClickTimer;

    public bool IsAutoHiddenForFullscreen { get; set; }

    public TimerWindow(
        TimerController timerController,
        PersistenceService persistenceService,
        Func<PersistedState> getState,
        Action<string> handleAction)
    {
        _timerController = timerController;
        _persistenceService = persistenceService;
        _getState = getState;
        _handleAction = handleAction;

        InitializeComponent();
        DataContext = timerController;
    }

    public nint Hwnd => _hwnd;

    public void ApplyAppearance(AppSettings settings)
    {
        var color = ParseHexRgb(settings.TextColorHexRgb);
        byte alpha = (byte)Math.Round(settings.TextOpacityPercent * 255.0 / 100.0);
        var argb = Color.FromArgb(alpha, color.R, color.G, color.B);
        TimerText.Foreground = new SolidColorBrush(argb);
        TimerText.FontFamily = new System.Windows.Media.FontFamily(settings.FontFamily);
        TimerText.FontSize = FontUnitConverter.WpfUnitsFromPoints(settings.FontSizePoints);
    }

    public void RestorePosition(WindowPlacementState placement)
    {
        var screen = WindowPositioning.FindScreenByDeviceName(placement.MonitorDeviceName);
        if (screen is null)
        {
            // Center on primary
            var primary = WinForms.Screen.PrimaryScreen ?? WinForms.Screen.AllScreens[0];
            UpdateLayout();
            var (cx, cy) = WindowPositioning.CenterOnScreen(
                ActualWidth > 0 ? ActualWidth : 150, ActualHeight > 0 ? ActualHeight : 60, primary);
            Left = cx;
            Top = cy;
        }
        else
        {
            Left = placement.LeftDip;
            Top = placement.TopDip;
            UpdateLayout();
            var (cl, ct) = WindowPositioning.ClampToWorkingArea(Left, Top, ActualWidth, ActualHeight, screen);
            Left = cl;
            Top = ct;
        }
    }

    public void ReassertTopmost()
    {
        if (_hwnd == nint.Zero) return;
        NativeMethods.SetWindowPos(_hwnd, NativeConstants.HWND_TOPMOST,
            0, 0, 0, 0,
            NativeConstants.SWP_NOMOVE | NativeConstants.SWP_NOSIZE |
            NativeConstants.SWP_NOACTIVATE | NativeConstants.SWP_NOOWNERZORDER);
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);

        _hwnd = new WindowInteropHelper(this).Handle;
        var source = HwndSource.FromHwnd(_hwnd);
        source?.AddHook(WndProc);

        // Set WS_EX_TOOLWINDOW, remove WS_EX_APPWINDOW
        var exStyle = (uint)(long)NativeMethods.GetWindowLongPtr(_hwnd, NativeConstants.GWL_EXSTYLE);
        exStyle |= NativeConstants.WS_EX_TOOLWINDOW;
        exStyle &= ~NativeConstants.WS_EX_APPWINDOW;
        NativeMethods.SetWindowLongPtr(_hwnd, NativeConstants.GWL_EXSTYLE, (nint)exStyle);

        // Assert topmost
        ReassertTopmost();

        _previousWidth = ActualWidth;
    }

    protected override void OnRenderSizeChanged(SizeChangedInfo sizeInfo)
    {
        base.OnRenderSizeChanged(sizeInfo);

        if (!_isDragging && sizeInfo.WidthChanged)
        {
            double delta = sizeInfo.NewSize.Width - _previousWidth;
            Left -= delta / 2.0;

            // Clamp
            var screen = WindowPositioning.GetScreenForWindow(this);
            var (cl, ct) = WindowPositioning.ClampToWorkingArea(Left, Top, ActualWidth, ActualHeight, screen);
            Left = cl;
            Top = ct;
        }
        _previousWidth = ActualWidth;
    }

    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonDown(e);
        _dragStartPoint = e.GetPosition(this);
        _isDragging = false;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (e.LeftButton != MouseButtonState.Pressed) return;
        if (_isDragging) return;

        var pos = e.GetPosition(this);
        if (Math.Abs(pos.X - _dragStartPoint.X) > SystemParameters.MinimumHorizontalDragDistance ||
            Math.Abs(pos.Y - _dragStartPoint.Y) > SystemParameters.MinimumVerticalDragDistance)
        {
            _isDragging = true;
            CancelPendingClicks();
            DragMove();
            _isDragging = false;
            OnDragEnd();
        }
    }

    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonUp(e);
        if (_isDragging) return;

        if (e.ClickCount == 2)
        {
            CancelLeftClickTimer();
            _pendingLeftClick = false;
            ExecuteMouseAction(_getState().MouseBindings.LeftDoubleClick);
            return;
        }

        _pendingLeftClick = true;
        _leftClickTimer?.Stop();
        _leftClickTimer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(WinForms.SystemInformation.DoubleClickTime)
        };
        _leftClickTimer.Tick += (_, _) =>
        {
            _leftClickTimer.Stop();
            if (_pendingLeftClick)
            {
                _pendingLeftClick = false;
                ExecuteMouseAction(_getState().MouseBindings.LeftClick);
            }
        };
        _leftClickTimer.Start();
    }

    protected override void OnMouseRightButtonUp(MouseButtonEventArgs e)
    {
        base.OnMouseRightButtonUp(e);

        if (e.ClickCount == 2)
        {
            CancelRightClickTimer();
            _pendingRightClick = false;
            ExecuteMouseAction(_getState().MouseBindings.RightDoubleClick);
            return;
        }

        _pendingRightClick = true;
        _rightClickTimer?.Stop();
        _rightClickTimer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(WinForms.SystemInformation.DoubleClickTime)
        };
        _rightClickTimer.Tick += (_, _) =>
        {
            _rightClickTimer.Stop();
            if (_pendingRightClick)
            {
                _pendingRightClick = false;
                ExecuteMouseAction(_getState().MouseBindings.RightClick);
            }
        };
        _rightClickTimer.Start();
    }

    private void ExecuteMouseAction(Models.MouseAction action)
    {
        switch (action)
        {
            case Models.MouseAction.TogglePauseResume:
                _handleAction("TogglePauseResume");
                break;
            case Models.MouseAction.Reset:
                _handleAction("Reset");
                break;
        }
    }

    private void OnDragEnd()
    {
        var screen = WindowPositioning.GetScreenForWindow(this);
        var (cl, ct) = WindowPositioning.ClampToWorkingArea(Left, Top, ActualWidth, ActualHeight, screen);
        Left = cl;
        Top = ct;

        var state = _getState();
        state.WindowPlacement.LeftDip = Left;
        state.WindowPlacement.TopDip = Top;
        state.WindowPlacement.MonitorDeviceName = screen.DeviceName;
        _persistenceService.SaveDebounced(state);
    }

    private void CancelPendingClicks()
    {
        _pendingLeftClick = false;
        _pendingRightClick = false;
        CancelLeftClickTimer();
        CancelRightClickTimer();
    }

    private void CancelLeftClickTimer()
    {
        _leftClickTimer?.Stop();
        _leftClickTimer = null;
    }

    private void CancelRightClickTimer()
    {
        _rightClickTimer?.Stop();
        _rightClickTimer = null;
    }

    private nint WndProc(nint hwnd, int msg, nint wParam, nint lParam, ref bool handled)
    {
        switch (msg)
        {
            case NativeConstants.WM_HOTKEY:
                _handleAction($"GlobalHotkey:{wParam}");
                handled = true;
                break;

            case NativeConstants.WM_DISPLAYCHANGE:
                Dispatcher.BeginInvoke(() =>
                {
                    var screen = WindowPositioning.GetScreenForWindow(this);
                    var (cl, ct) = WindowPositioning.ClampToWorkingArea(Left, Top, ActualWidth, ActualHeight, screen);
                    Left = cl;
                    Top = ct;
                    var state = _getState();
                    state.WindowPlacement.LeftDip = Left;
                    state.WindowPlacement.TopDip = Top;
                    state.WindowPlacement.MonitorDeviceName = screen.DeviceName;
                    _persistenceService.Save(state);
                });
                break;

            case NativeConstants.WM_DPICHANGED:
                Dispatcher.BeginInvoke(() =>
                {
                    UpdateLayout();
                    var screen = WindowPositioning.GetScreenForWindow(this);
                    var (cl, ct) = WindowPositioning.ClampToWorkingArea(Left, Top, ActualWidth, ActualHeight, screen);
                    Left = cl;
                    Top = ct;
                    var state = _getState();
                    state.WindowPlacement.LeftDip = Left;
                    state.WindowPlacement.TopDip = Top;
                    _persistenceService.SaveDebounced(state);
                });
                break;
        }
        return nint.Zero;
    }

    private static Color ParseHexRgb(string hex)
    {
        try
        {
            if (hex.StartsWith('#') && hex.Length == 7)
            {
                byte r = Convert.ToByte(hex.Substring(1, 2), 16);
                byte g = Convert.ToByte(hex.Substring(3, 2), 16);
                byte b = Convert.ToByte(hex.Substring(5, 2), 16);
                return Color.FromRgb(r, g, b);
            }
        }
        catch { }
        return Color.FromRgb(0x5D, 0xFF, 0xFF); // fallback
    }
}
