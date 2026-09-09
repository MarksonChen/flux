using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Flux.Models;

namespace Flux.Views.Controls;

public partial class ShortcutRecorderControl : UserControl
{
    private bool _isRecording;
    private bool _requireModifier;

    public event EventHandler<KeyChord>? ShortcutChanged;

    public KeyChord CurrentChord { get; private set; } = new();
    public bool RequireModifier
    {
        get => _requireModifier;
        set => _requireModifier = value;
    }

    public bool RejectF12 { get; set; }

    public ShortcutRecorderControl()
    {
        InitializeComponent();
        Tag = "ShortcutRecorder";
    }

    public void SetChord(KeyChord chord)
    {
        CurrentChord = chord;
        DisplayText.Text = chord.ToString();
    }

    private void OnRecordClick(object sender, RoutedEventArgs e)
    {
        if (_isRecording)
        {
            StopRecording();
            return;
        }

        _isRecording = true;
        RecordButton.Content = "Stop";
        DisplayText.Text = "Press shortcut\u2026";
        PreviewKeyDown += OnRecordKeyDown;
        Focus();
    }

    private void OnRecordKeyDown(object sender, KeyEventArgs e)
    {
        var key = e.Key == Key.System ? e.SystemKey : e.Key;

        // Ignore pure modifier presses
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
            or Key.LeftShift or Key.RightShift)
            return;

        // Esc cancels
        if (key == Key.Escape)
        {
            StopRecording();
            DisplayText.Text = CurrentChord.ToString();
            e.Handled = true;
            return;
        }

        // Reject Win key
        if (key is Key.LWin or Key.RWin)
        {
            e.Handled = true;
            return;
        }

        // Reject F12 for global
        if (RejectF12 && key == Key.F12)
        {
            e.Handled = true;
            return;
        }

        var mods = ShortcutModifiers.None;
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0) mods |= ShortcutModifiers.Ctrl;
        if ((Keyboard.Modifiers & ModifierKeys.Alt) != 0) mods |= ShortcutModifiers.Alt;
        if ((Keyboard.Modifiers & ModifierKeys.Shift) != 0) mods |= ShortcutModifiers.Shift;

        if (_requireModifier && mods == ShortcutModifiers.None)
        {
            e.Handled = true;
            return;
        }

        var chord = new KeyChord { Modifiers = mods, Key = key.ToString() };

        StopRecording();
        CurrentChord = chord;
        DisplayText.Text = chord.ToString();
        ShortcutChanged?.Invoke(this, chord);
        e.Handled = true;
    }

    private void StopRecording()
    {
        _isRecording = false;
        RecordButton.Content = "Record";
        PreviewKeyDown -= OnRecordKeyDown;
    }
}
