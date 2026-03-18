using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;

namespace Flux.Views;

/// <summary>Returns Visible when the bound int (Text.Length) is 0, Collapsed otherwise.</summary>
public class ZeroToVisibleConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => value is int len && len == 0 ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

public partial class SetTimeWindow : GlassWindowBase
{
    public double? ResultSeconds { get; private set; }

    public SetTimeWindow()
    {
        InitializeComponent();
        Loaded += (_, _) => MinutesBox.Focus();
    }

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        EnableDragMove(sender, e);
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            OnSet(this, new RoutedEventArgs());
            e.Handled = true;
            return;
        }
        base.OnKeyDown(e);
    }

    private void OnTextBoxGotFocus(object sender, RoutedEventArgs e)
    {
        if (sender is TextBox tb)
            tb.SelectAll();
    }

    private void OnPreviewTextInput(object sender, TextCompositionEventArgs e)
    {
        e.Handled = !int.TryParse(e.Text, out _);
    }

    private void OnCancel(object sender, RoutedEventArgs e)
    {
        ResultSeconds = null;
        Close();
    }

    private void OnSet(object sender, RoutedEventArgs e)
    {
        if (!TryParseField(HoursBox.Text, out int hours) ||
            !TryParseField(MinutesBox.Text, out int minutes) ||
            !TryParseField(SecondsBox.Text, out int seconds))
        {
            MessageBox.Show("Please enter valid numeric values.",
                "Invalid Input", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        // Normalize: carry overflow from seconds → minutes → hours
        int totalSeconds = hours * 3600 + minutes * 60 + seconds;
        ResultSeconds = totalSeconds;
        Close();
    }

    private static bool TryParseField(string text, out int value)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            value = 0;
            return true;
        }
        return int.TryParse(text, out value) && value >= 0;
    }
}
