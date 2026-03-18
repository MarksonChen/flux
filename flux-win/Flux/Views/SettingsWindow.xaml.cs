using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Flux.Models;
using Flux.Services;
using Flux.Views.Controls;
using WinForms = System.Windows.Forms;
using Drawing = System.Drawing;

namespace Flux.Views;

public partial class SettingsWindow : GlassWindowBase
{
    private readonly Models.PersistedState _state;
    private readonly Action _onAppearanceChanged;
    private readonly Action _onShortcutsChanged;
    private readonly Action _onGeneralChanged;
    private readonly StartupRegistrationService _startupService;
    private readonly FullscreenMonitor _fullscreenMonitor;
    private readonly GlobalHotkeyService _globalHotkeyService;
    private bool _suppressEvents = true;
    private TextBlock? _hotkeyErrorText;

    // Shortcut recorders
    private readonly Dictionary<string, ShortcutRecorderControl> _localRecorders = new();
    private readonly Dictionary<string, ShortcutRecorderControl> _globalRecorders = new();
    private readonly Dictionary<string, ComboBox> _mouseCombos = new();
    private readonly Dictionary<string, CheckBox> _globalEnableChecks = new();

    public SettingsWindow(
        Models.PersistedState state,
        Action onAppearanceChanged,
        Action onShortcutsChanged,
        Action onGeneralChanged,
        StartupRegistrationService startupService,
        FullscreenMonitor fullscreenMonitor,
        GlobalHotkeyService globalHotkeyService)
    {
        _state = state;
        _onAppearanceChanged = onAppearanceChanged;
        _onShortcutsChanged = onShortcutsChanged;
        _onGeneralChanged = onGeneralChanged;
        _startupService = startupService;
        _fullscreenMonitor = fullscreenMonitor;
        _globalHotkeyService = globalHotkeyService;

        InitializeComponent();

        PopulateFonts();
        PopulateShortcutsTab();
        LoadCurrentValues();
    }

    private void PopulateFonts()
    {
        var fonts = Fonts.SystemFontFamilies
            .Select(f => f.Source)
            .OrderBy(name => name)
            .ToList();
        FontCombo.ItemsSource = fonts;
    }

    private void LoadCurrentValues()
    {
        _suppressEvents = true;

        var s = _state.AppSettings;
        FontCombo.SelectedItem = s.FontFamily;
        if (FontCombo.SelectedItem is null && FontCombo.Items.Count > 0)
            FontCombo.SelectedItem = "Arial Black";

        SizeSlider.Value = s.FontSizePoints;
        SizeLabel.Text = ((int)s.FontSizePoints).ToString();

        UpdateColorButton(s.TextColorHexRgb);

        OpacitySlider.Value = s.TextOpacityPercent;
        OpacityLabel.Text = s.TextOpacityPercent.ToString();

        LaunchAtLoginCheck.IsChecked = s.LaunchAtLogin;
        ShowInFullScreenCheck.IsChecked = s.ShowInFullScreen;

        _suppressEvents = false;
    }

    private void PopulateShortcutsTab()
    {
        var panel = ShortcutsPanel;
        panel.Children.Clear();

        // Local keyboard shortcuts header
        AddSectionHeader(panel, "Keyboard Shortcuts");

        var localBindings = _state.LocalShortcuts;
        AddLocalShortcutRow(panel, "Toggle Pause/Resume", "TogglePauseResume", localBindings.TogglePauseResume, false);
        AddLocalShortcutRow(panel, "Copy Time", "CopyRoundedMinutes", localBindings.CopyRoundedMinutes, true);
        AddLocalShortcutRow(panel, "Set Time", "OpenSetTime", localBindings.OpenSetTime, true);
        AddLocalShortcutRow(panel, "History", "OpenHistory", localBindings.OpenHistory, true);
        AddLocalShortcutRow(panel, "Settings", "OpenSettings", localBindings.OpenSettings, true);
        AddLocalShortcutRow(panel, "Quit", "Quit", localBindings.Quit, true);

        // Mouse bindings header
        AddSectionHeader(panel, "Mouse Bindings");

        AddMouseRow(panel, "Left Click", "LeftClick", _state.MouseBindings.LeftClick);
        AddMouseRow(panel, "Right Click", "RightClick", _state.MouseBindings.RightClick);
        AddMouseRow(panel, "Left Double Click", "LeftDoubleClick", _state.MouseBindings.LeftDoubleClick);
        AddMouseRow(panel, "Right Double Click", "RightDoubleClick", _state.MouseBindings.RightDoubleClick);

        // Global hotkeys header
        AddSectionHeader(panel, "Global Hotkeys");

        AddGlobalHotkeyRow(panel, "Toggle Pause/Resume", "TogglePauseResume",
            _state.GlobalHotkeys.TogglePauseResume);
        AddGlobalHotkeyRow(panel, "Copy + Reset", "CopyAndReset",
            _state.GlobalHotkeys.CopyAndReset);

        // Hotkey error display
        _hotkeyErrorText = new TextBlock
        {
            Foreground = new SolidColorBrush(Color.FromArgb(0xFF, 0xFF, 0x45, 0x3A)),
            FontSize = 11,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 8, 0, 0),
            Visibility = Visibility.Collapsed
        };
        panel.Children.Add(_hotkeyErrorText);
        UpdateHotkeyErrorDisplay();

        // Reset button
        var resetBtn = new Button
        {
            Content = "Reset to Defaults",
            HorizontalAlignment = System.Windows.HorizontalAlignment.Left,
            Background = new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)),
            Foreground = Brushes.White,
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x4D, 0xFF, 0xFF, 0xFF)),
            Padding = new Thickness(8, 4, 8, 4),
            Margin = new Thickness(0, 12, 0, 0)
        };
        resetBtn.Click += OnResetShortcuts;
        panel.Children.Add(resetBtn);
    }

    private void AddSectionHeader(StackPanel panel, string text)
    {
        panel.Children.Add(new TextBlock
        {
            Text = text,
            Foreground = Brushes.White,
            FontWeight = FontWeights.SemiBold,
            FontSize = 13,
            Margin = new Thickness(0, 8, 0, 4)
        });
    }

    private void AddLocalShortcutRow(StackPanel panel, string label, string actionName, KeyChord chord, bool requireCtrl)
    {
        var grid = new Grid { Margin = new Thickness(0, 2, 0, 2) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Foreground = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0xFF)),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(lbl, 0);
        grid.Children.Add(lbl);

        var recorder = new ShortcutRecorderControl { RequireModifier = requireCtrl };
        recorder.SetChord(chord);
        recorder.ShortcutChanged += (_, newChord) =>
        {
            if (CheckLocalDuplicate(actionName, newChord))
            {
                MessageBox.Show($"'{newChord}' is already used by another action.", "Duplicate Shortcut",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                recorder.SetChord(chord);
                return;
            }
            SetLocalBinding(actionName, newChord);
            _onShortcutsChanged();
        };
        Grid.SetColumn(recorder, 1);
        grid.Children.Add(recorder);

        _localRecorders[actionName] = recorder;
        panel.Children.Add(grid);
    }

    private void AddMouseRow(StackPanel panel, string label, string slotName, Models.MouseAction current)
    {
        var grid = new Grid { Margin = new Thickness(0, 2, 0, 2) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Foreground = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0xFF)),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(lbl, 0);
        grid.Children.Add(lbl);

        var combo = new ComboBox
        {
            Background = new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x4D, 0xFF, 0xFF, 0xFF)),
        };
        combo.Items.Add("None");
        combo.Items.Add("Toggle Pause/Resume");
        combo.Items.Add("Reset");
        combo.SelectedIndex = (int)current;
        combo.SelectionChanged += (_, _) =>
        {
            if (_suppressEvents) return;
            SetMouseBinding(slotName, (Models.MouseAction)combo.SelectedIndex);
            _onShortcutsChanged();
        };
        Grid.SetColumn(combo, 1);
        grid.Children.Add(combo);

        _mouseCombos[slotName] = combo;
        panel.Children.Add(grid);
    }

    private void AddGlobalHotkeyRow(StackPanel panel, string label, string actionName, GlobalHotkeyBinding binding)
    {
        var grid = new Grid { Margin = new Thickness(0, 2, 0, 2) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(130) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var check = new CheckBox
        {
            IsChecked = binding.Enabled,
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(check, 0);
        grid.Children.Add(check);
        _globalEnableChecks[actionName] = check;

        var lbl = new TextBlock
        {
            Text = label,
            Foreground = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0xFF)),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(lbl, 1);
        grid.Children.Add(lbl);

        var recorder = new ShortcutRecorderControl { RequireModifier = true, RejectF12 = true };
        recorder.SetChord(binding.Chord);
        recorder.ShortcutChanged += (_, newChord) =>
        {
            if (CheckGlobalDuplicate(actionName, newChord))
            {
                MessageBox.Show($"'{newChord}' conflicts with another binding.", "Duplicate Shortcut",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                recorder.SetChord(binding.Chord);
                return;
            }
            SetGlobalBinding(actionName, newChord);
            _onShortcutsChanged();
            UpdateHotkeyErrorDisplay();
        };
        Grid.SetColumn(recorder, 2);
        grid.Children.Add(recorder);

        check.Checked += (_, _) => { SetGlobalEnabled(actionName, true); _onShortcutsChanged(); UpdateHotkeyErrorDisplay(); };
        check.Unchecked += (_, _) => { SetGlobalEnabled(actionName, false); _onShortcutsChanged(); UpdateHotkeyErrorDisplay(); };

        _globalRecorders[actionName] = recorder;
        panel.Children.Add(grid);
    }

    private bool CheckLocalDuplicate(string excludeAction, KeyChord chord)
    {
        foreach (var (name, recorder) in _localRecorders)
        {
            if (name == excludeAction) continue;
            if (recorder.CurrentChord.Matches(chord)) return true;
        }
        foreach (var (name, recorder) in _globalRecorders)
        {
            if (_globalEnableChecks.TryGetValue(name, out var check) && check.IsChecked == true)
                if (recorder.CurrentChord.Matches(chord)) return true;
        }
        return false;
    }

    private bool CheckGlobalDuplicate(string excludeAction, KeyChord chord)
    {
        foreach (var (name, recorder) in _globalRecorders)
        {
            if (name == excludeAction) continue;
            if (_globalEnableChecks.TryGetValue(name, out var check) && check.IsChecked == true)
                if (recorder.CurrentChord.Matches(chord)) return true;
        }
        foreach (var (_, recorder) in _localRecorders)
        {
            if (recorder.CurrentChord.Matches(chord)) return true;
        }
        return false;
    }

    private void SetLocalBinding(string actionName, KeyChord chord)
    {
        var b = _state.LocalShortcuts;
        switch (actionName)
        {
            case "TogglePauseResume": b.TogglePauseResume = chord; break;
            case "CopyRoundedMinutes": b.CopyRoundedMinutes = chord; break;
            case "OpenSetTime": b.OpenSetTime = chord; break;
            case "OpenHistory": b.OpenHistory = chord; break;
            case "OpenSettings": b.OpenSettings = chord; break;
            case "Quit": b.Quit = chord; break;
        }
    }

    private void SetMouseBinding(string slotName, Models.MouseAction action)
    {
        var m = _state.MouseBindings;
        switch (slotName)
        {
            case "LeftClick": m.LeftClick = action; break;
            case "RightClick": m.RightClick = action; break;
            case "LeftDoubleClick": m.LeftDoubleClick = action; break;
            case "RightDoubleClick": m.RightDoubleClick = action; break;
        }
    }

    private void SetGlobalBinding(string actionName, KeyChord chord)
    {
        switch (actionName)
        {
            case "TogglePauseResume": _state.GlobalHotkeys.TogglePauseResume.Chord = chord; break;
            case "CopyAndReset": _state.GlobalHotkeys.CopyAndReset.Chord = chord; break;
        }
    }

    private void SetGlobalEnabled(string actionName, bool enabled)
    {
        switch (actionName)
        {
            case "TogglePauseResume": _state.GlobalHotkeys.TogglePauseResume.Enabled = enabled; break;
            case "CopyAndReset": _state.GlobalHotkeys.CopyAndReset.Enabled = enabled; break;
        }
    }

    private void OnClose(object sender, RoutedEventArgs e) => Close();

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        EnableDragMove(sender, e);
    }

    private void OnTabChanged(object sender, SelectionChangedEventArgs e)
    {
        if (TabControl.SelectedItem == AppearanceTab) Height = 340;
        else if (TabControl.SelectedItem == ShortcutsTab) Height = 540;
        else if (TabControl.SelectedItem == GeneralTab) Height = 240;
    }

    private void OnFontChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents) return;
        if (FontCombo.SelectedItem is string font)
        {
            _state.AppSettings.FontFamily = font;
            _onAppearanceChanged();
        }
    }

    private void OnSizeChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_suppressEvents) return;
        _state.AppSettings.FontSizePoints = (int)SizeSlider.Value;
        if (SizeLabel is not null)
            SizeLabel.Text = ((int)SizeSlider.Value).ToString();
        _onAppearanceChanged();
    }

    private void OnColorClick(object sender, RoutedEventArgs e)
    {
        var dlg = new WinForms.ColorDialog
        {
            FullOpen = true,
            AnyColor = true,
        };
        var current = ParseHex(_state.AppSettings.TextColorHexRgb);
        dlg.Color = Drawing.Color.FromArgb(current.R, current.G, current.B);

        if (dlg.ShowDialog() == WinForms.DialogResult.OK)
        {
            var c = dlg.Color;
            _state.AppSettings.TextColorHexRgb = $"#{c.R:X2}{c.G:X2}{c.B:X2}";
            UpdateColorButton(_state.AppSettings.TextColorHexRgb);
            _onAppearanceChanged();
        }
    }

    private void OnOpacityChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_suppressEvents) return;
        _state.AppSettings.TextOpacityPercent = (int)OpacitySlider.Value;
        if (OpacityLabel is not null)
            OpacityLabel.Text = ((int)OpacitySlider.Value).ToString();
        _onAppearanceChanged();
    }

    private void OnResetAppearance(object sender, RoutedEventArgs e)
    {
        var defaults = AppSettings.CreateDefaults();
        _state.AppSettings.FontFamily = defaults.FontFamily;
        _state.AppSettings.FontSizePoints = defaults.FontSizePoints;
        _state.AppSettings.TextColorHexRgb = defaults.TextColorHexRgb;
        _state.AppSettings.TextOpacityPercent = defaults.TextOpacityPercent;
        LoadCurrentValues();
        _onAppearanceChanged();
    }

    private void OnResetShortcuts(object sender, RoutedEventArgs e)
    {
        _state.LocalShortcuts = LocalShortcutBindings.CreateDefaults();
        _state.MouseBindings = MouseBindings.CreateDefaults();
        _state.GlobalHotkeys = GlobalHotkeyBindings.CreateDefaults();
        PopulateShortcutsTab();
        _onShortcutsChanged();
    }

    private void OnLaunchAtLoginChanged(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        var desired = LaunchAtLoginCheck.IsChecked == true;
        bool ok = desired ? _startupService.Register() : _startupService.Unregister();
        if (!ok)
        {
            _suppressEvents = true;
            LaunchAtLoginCheck.IsChecked = !desired;
            _suppressEvents = false;
            MessageBox.Show("Failed to update launch at login.", "Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }
        _state.AppSettings.LaunchAtLogin = desired;
        _onGeneralChanged();
    }

    private void OnShowInFullScreenChanged(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        _state.AppSettings.ShowInFullScreen = ShowInFullScreenCheck.IsChecked == true;
        _fullscreenMonitor.Reevaluate();
        _onGeneralChanged();
    }

    private void UpdateHotkeyErrorDisplay()
    {
        if (_hotkeyErrorText is null) return;
        var error = _globalHotkeyService.LastError;
        if (string.IsNullOrEmpty(error))
        {
            _hotkeyErrorText.Visibility = Visibility.Collapsed;
        }
        else
        {
            _hotkeyErrorText.Text = error;
            _hotkeyErrorText.Visibility = Visibility.Visible;
        }
    }

    private void UpdateColorButton(string hex)
    {
        var c = ParseHex(hex);
        ColorButton.Background = new SolidColorBrush(Color.FromRgb(c.R, c.G, c.B));
    }

    private static Color ParseHex(string hex)
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
        return Color.FromRgb(0x5D, 0xFF, 0xFF);
    }
}
