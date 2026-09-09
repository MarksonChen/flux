namespace Flux.Models;

public sealed class GlobalHotkeyBinding
{
    public bool Enabled { get; set; }
    public KeyChord Chord { get; set; } = new();
}

public sealed class GlobalHotkeyBindings
{
    public GlobalHotkeyBinding TogglePauseResume { get; set; } = new();
    public GlobalHotkeyBinding CopyAndReset { get; set; } = new();

    public static GlobalHotkeyBindings CreateDefaults() => new()
    {
        TogglePauseResume = new GlobalHotkeyBinding
        {
            Enabled = true,
            Chord = new KeyChord { Modifiers = ShortcutModifiers.Ctrl | ShortcutModifiers.Alt, Key = "T" }
        },
        CopyAndReset = new GlobalHotkeyBinding
        {
            Enabled = true,
            Chord = new KeyChord
            {
                Modifiers = ShortcutModifiers.Ctrl | ShortcutModifiers.Alt | ShortcutModifiers.Shift,
                Key = "T"
            }
        }
    };

    public IEnumerable<GlobalHotkeyBinding> AllBindings()
    {
        yield return TogglePauseResume;
        yield return CopyAndReset;
    }
}
