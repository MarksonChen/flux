using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Flux.Models;

namespace Flux.Services;

public sealed class ShortcutService
{
    private LocalShortcutBindings _bindings;
    private readonly Action<string> _executeAction;

    public ShortcutService(LocalShortcutBindings bindings, Action<string> executeAction)
    {
        _bindings = bindings;
        _executeAction = executeAction;
    }

    public void UpdateBindings(LocalShortcutBindings bindings) => _bindings = bindings;

    public bool HandleKeyDown(KeyEventArgs e)
    {
        // Suppress in text boxes and recorders
        var focused = Keyboard.FocusedElement;
        bool inTextBox = focused is TextBox;
        bool inRecorder = focused is FrameworkElement fe &&
                          fe.Tag is string tag && tag == "ShortcutRecorder";

        if (inTextBox || inRecorder)
        {
            // Still allow Ctrl+Q and Ctrl+W
            var chord = BuildChord(e);
            if (chord is not null)
            {
                if (_bindings.Quit.Matches(chord))
                {
                    _executeAction("Quit");
                    e.Handled = true;
                    return true;
                }
            }
            return false;
        }

        var pressed = BuildChord(e);
        if (pressed is null) return false;

        if (_bindings.TogglePauseResume.Matches(pressed))
        {
            _executeAction("TogglePauseResume");
            e.Handled = true;
            return true;
        }
        if (_bindings.CopyRoundedMinutes.Matches(pressed))
        {
            _executeAction("CopyRoundedMinutes");
            e.Handled = true;
            return true;
        }
        if (_bindings.OpenSetTime.Matches(pressed))
        {
            _executeAction("OpenSetTime");
            e.Handled = true;
            return true;
        }
        if (_bindings.OpenHistory.Matches(pressed))
        {
            _executeAction("OpenHistory");
            e.Handled = true;
            return true;
        }
        if (_bindings.OpenSettings.Matches(pressed))
        {
            _executeAction("OpenSettings");
            e.Handled = true;
            return true;
        }
        if (_bindings.Quit.Matches(pressed))
        {
            _executeAction("Quit");
            e.Handled = true;
            return true;
        }

        return false;
    }

    private static KeyChord? BuildChord(KeyEventArgs e)
    {
        var key = e.Key == Key.System ? e.SystemKey : e.Key;

        // Ignore pure modifier presses
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
            or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin)
            return null;

        var mods = ShortcutModifiers.None;
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0) mods |= ShortcutModifiers.Ctrl;
        if ((Keyboard.Modifiers & ModifierKeys.Alt) != 0) mods |= ShortcutModifiers.Alt;
        if ((Keyboard.Modifiers & ModifierKeys.Shift) != 0) mods |= ShortcutModifiers.Shift;

        return new KeyChord { Modifiers = mods, Key = key.ToString() };
    }
}
