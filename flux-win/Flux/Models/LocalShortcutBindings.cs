namespace Flux.Models;

[Flags]
public enum ShortcutModifiers
{
    None = 0,
    Ctrl = 1,
    Alt = 2,
    Shift = 4
}

public sealed class KeyChord
{
    public ShortcutModifiers Modifiers { get; set; }
    public string Key { get; set; } = "";

    public override string ToString()
    {
        var parts = new List<string>();
        if (Modifiers.HasFlag(ShortcutModifiers.Ctrl)) parts.Add("Ctrl");
        if (Modifiers.HasFlag(ShortcutModifiers.Alt)) parts.Add("Alt");
        if (Modifiers.HasFlag(ShortcutModifiers.Shift)) parts.Add("Shift");

        var keyDisplay = Key switch
        {
            "OemComma" => ",",
            "OemPeriod" => ".",
            "OemPlus" => "+",
            "OemMinus" => "-",
            _ => Key
        };
        parts.Add(keyDisplay);
        return string.Join("+", parts);
    }

    public bool Matches(KeyChord other) =>
        Modifiers == other.Modifiers &&
        string.Equals(Key, other.Key, StringComparison.OrdinalIgnoreCase);
}

public sealed class LocalShortcutBindings
{
    public KeyChord TogglePauseResume { get; set; } = new();
    public KeyChord CopyRoundedMinutes { get; set; } = new();
    public KeyChord OpenSetTime { get; set; } = new();
    public KeyChord OpenHistory { get; set; } = new();
    public KeyChord OpenSettings { get; set; } = new();
    public KeyChord Quit { get; set; } = new();

    public static LocalShortcutBindings CreateDefaults() => new()
    {
        TogglePauseResume = new KeyChord { Modifiers = ShortcutModifiers.None, Key = "Space" },
        CopyRoundedMinutes = new KeyChord { Modifiers = ShortcutModifiers.Ctrl, Key = "C" },
        OpenSetTime = new KeyChord { Modifiers = ShortcutModifiers.Ctrl, Key = "S" },
        OpenHistory = new KeyChord { Modifiers = ShortcutModifiers.Ctrl, Key = "Y" },
        OpenSettings = new KeyChord { Modifiers = ShortcutModifiers.Ctrl, Key = "OemComma" },
        Quit = new KeyChord { Modifiers = ShortcutModifiers.Ctrl, Key = "Q" }
    };

    public IEnumerable<KeyChord> AllChords()
    {
        yield return TogglePauseResume;
        yield return CopyRoundedMinutes;
        yield return OpenSetTime;
        yield return OpenHistory;
        yield return OpenSettings;
        yield return Quit;
    }
}
