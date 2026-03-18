using System.Windows;
using System.Windows.Input;
using Flux.Infrastructure;
using Flux.Models;
using Flux.Services;
using Flux.Views;
namespace Flux;

public partial class App : Application
{
    private SingleInstanceGuard? _guard;
    private PersistenceService _persistence = null!;
    private PersistedState _state = null!;
    private TimerController _timerController = null!;
    private EventLogger _eventLogger = null!;
    private ShortcutService _shortcutService = null!;
    private GlobalHotkeyService _globalHotkeyService = null!;
    private FullscreenMonitor _fullscreenMonitor = null!;
    private StartupRegistrationService _startupService = null!;
    private IVirtualDesktopService _virtualDesktopService = null!;
    private Debouncer _appearanceDebouncer = null!;

    private TimerWindow _timerWindow = null!;
    private SetTimeWindow? _setTimeWindow;
    private HistoryWindow? _historyWindow;
    private SettingsWindow? _settingsWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 1. Single instance
        _guard = new SingleInstanceGuard();
        if (!_guard.IsFirstInstance)
        {
            Shutdown();
            return;
        }

        // 2. Load state
        _persistence = new PersistenceService();
        _state = _persistence.Load();

        // 3. Initialize services
        _eventLogger = new EventLogger();
        _eventLogger.Initialize(_state.TimerEvents);

        _timerController = new TimerController(_state.TimerState, _eventLogger, OnTimerStateChanged);
        _shortcutService = new ShortcutService(_state.LocalShortcuts, HandleAction);
        _globalHotkeyService = new GlobalHotkeyService(_state.GlobalHotkeys);
        _startupService = new StartupRegistrationService();
        _virtualDesktopService = new VirtualDesktopService();
        _appearanceDebouncer = new Debouncer(TimeSpan.FromMilliseconds(250));

        // 4. Create overlay
        _timerWindow = new TimerWindow(_timerController, _persistence, () => _state, HandleAction);

        // 5. Apply appearance
        _timerWindow.ApplyAppearance(_state.AppSettings);

        // 6. Show overlay
        _timerWindow.Show();

        // 7. Restore position (after show so ActualWidth/Height are available)
        _timerWindow.RestorePosition(_state.WindowPlacement);

        // 8. Register global hotkeys
        _globalHotkeyService.Initialize(_timerWindow.Hwnd);

        // 9. Fullscreen monitor
        _fullscreenMonitor = new FullscreenMonitor(_timerWindow, () => _state.AppSettings);
        _fullscreenMonitor.Start();

        // 10. Virtual desktop
        _virtualDesktopService.InitializeForWindow(_timerWindow.Hwnd);

        // 11. Resume timer from persistence
        _timerController.ResumeFromPersistence();
        _timerController.Start();

        // 12. Wire up keyboard handling for all Flux windows
        EventManager.RegisterClassHandler(typeof(Window), Keyboard.PreviewKeyDownEvent,
            new KeyEventHandler(OnGlobalKeyDown));
    }

    private void OnGlobalKeyDown(object sender, KeyEventArgs e)
    {
        if (sender is Window w && w is (TimerWindow or GlassWindowBase))
        {
            _shortcutService.HandleKeyDown(e);
        }
    }

    private void HandleAction(string action)
    {
        switch (action)
        {
            case "TogglePauseResume":
                _timerController.Toggle();
                break;
            case "CopyRoundedMinutes":
                _timerController.CopyRoundedMinutes();
                break;
            case "CopyAndReset":
                _timerController.CopyAndReset();
                break;
            case "Reset":
                _timerController.Reset();
                break;
            case "OpenSetTime":
                OpenSetTime();
                break;
            case "OpenHistory":
                OpenHistory();
                break;
            case "OpenSettings":
                OpenSettings();
                break;
            case "Quit":
                DoQuit();
                break;
            default:
                if (action.StartsWith("GlobalHotkey:"))
                {
                    var idStr = action.Substring("GlobalHotkey:".Length);
                    if (nint.TryParse(idStr, out var id))
                    {
                        var hotAction = _globalHotkeyService.HandleHotkey(id);
                        if (hotAction is not null)
                            HandleAction(hotAction);
                    }
                }
                break;
        }
    }

    private void OpenSetTime()
    {
        if (_setTimeWindow is { IsLoaded: true })
        {
            _setTimeWindow.Activate();
            return;
        }

        _setTimeWindow = new SetTimeWindow { Owner = _timerWindow };
        var (left, top) = Utilities.WindowPositioning.PositionDialogRelativeToOverlay(
            _timerWindow, 300, 180);
        _setTimeWindow.Left = left;
        _setTimeWindow.Top = top;
        _setTimeWindow.Closed += (_, _) =>
        {
            if (_setTimeWindow.ResultSeconds is { } seconds)
            {
                _timerController.SetTime(seconds);
            }
            _setTimeWindow = null;
        };
        _setTimeWindow.Show();
    }

    private void OpenHistory()
    {
        if (_historyWindow is { IsLoaded: true })
        {
            _historyWindow.Activate();
            return;
        }

        _historyWindow = new HistoryWindow(_eventLogger.Events) { Owner = _timerWindow };
        var (left, top) = Utilities.WindowPositioning.PositionDialogRelativeToOverlay(
            _timerWindow, 450, 700);
        _historyWindow.Left = left;
        _historyWindow.Top = top;
        _historyWindow.Closed += (_, _) => _historyWindow = null;
        _historyWindow.Show();
    }

    private void OpenSettings()
    {
        if (_settingsWindow is { IsLoaded: true })
        {
            _settingsWindow.Activate();
            return;
        }

        _settingsWindow = new SettingsWindow(
            _state,
            OnAppearanceChanged,
            OnShortcutsChanged,
            OnGeneralChanged,
            _startupService,
            _fullscreenMonitor,
            _globalHotkeyService)
        { Owner = _timerWindow };
        var (left, top) = Utilities.WindowPositioning.PositionDialogRelativeToOverlay(
            _timerWindow, 520, 320);
        _settingsWindow.Left = left;
        _settingsWindow.Top = top;
        _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        _settingsWindow.Show();
    }

    private void OnAppearanceChanged()
    {
        _timerWindow.ApplyAppearance(_state.AppSettings);
        _appearanceDebouncer.Debounce(() => _persistence.Save(_state));
    }

    private void OnShortcutsChanged()
    {
        _shortcutService.UpdateBindings(_state.LocalShortcuts);
        _globalHotkeyService.UpdateBindings(_state.GlobalHotkeys);
        _persistence.Save(_state);
    }

    private void OnGeneralChanged()
    {
        _persistence.Save(_state);
    }

    private void OnTimerStateChanged()
    {
        _state.TimerEvents = _eventLogger.ToSerializableList();
        _persistence.Save(_state);
    }

    private void DoQuit()
    {
        // 1. Unregister global hotkeys
        _globalHotkeyService.UnregisterAll();

        // 2. Unhook fullscreen monitor
        _fullscreenMonitor.Dispose();

        // 3. Flush debounced saves
        _persistence.Flush();
        _appearanceDebouncer.Flush();

        // 4. Save final state
        _state.TimerEvents = _eventLogger.ToSerializableList();
        _state.WindowPlacement.LeftDip = _timerWindow.Left;
        _state.WindowPlacement.TopDip = _timerWindow.Top;
        var screen = Utilities.WindowPositioning.GetScreenForWindow(_timerWindow);
        _state.WindowPlacement.MonitorDeviceName = screen.DeviceName;
        _persistence.Save(_state);

        // 5. Close all windows
        _setTimeWindow?.Close();
        _historyWindow?.Close();
        _settingsWindow?.Close();
        _timerWindow.Close();

        // 6. Release mutex
        _guard?.Dispose();

        // 7. Shutdown
        Shutdown();
    }
}
