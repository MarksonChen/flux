namespace Flux.Models;

public sealed class PersistedState
{
    public TimerState TimerState { get; set; } = new();
    public AppSettings AppSettings { get; set; } = AppSettings.CreateDefaults();
    public LocalShortcutBindings LocalShortcuts { get; set; } = LocalShortcutBindings.CreateDefaults();
    public MouseBindings MouseBindings { get; set; } = MouseBindings.CreateDefaults();
    public GlobalHotkeyBindings GlobalHotkeys { get; set; } = GlobalHotkeyBindings.CreateDefaults();
    public List<TimerEvent> TimerEvents { get; set; } = new();
    public WindowPlacementState WindowPlacement { get; set; } = new();
}
