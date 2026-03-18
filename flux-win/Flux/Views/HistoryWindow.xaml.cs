using System.Collections.ObjectModel;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using Flux.Models;

namespace Flux.Views;

public partial class HistoryWindow : GlassWindowBase
{
    public HistoryWindow(ObservableCollection<TimerEvent> events)
    {
        InitializeComponent();
        ResizeMode = ResizeMode.CanResize;

        HistoryGrid.ItemsSource = events;

        // Replace the auto-generated columns with proper bindings
        HistoryGrid.Columns.Clear();

        var timeCol = new DataGridTextColumn
        {
            Header = "Time",
            Width = new DataGridLength(120),
            Binding = new Binding("TimestampUtc") { Converter = new TimestampToLocalConverter() },
        };
        timeCol.ElementStyle = CreateTextStyle("#99FFFFFF");
        HistoryGrid.Columns.Add(timeCol);

        var changeCol = new DataGridTextColumn
        {
            Header = "Change",
            Width = new DataGridLength(1, DataGridLengthUnitType.Star),
            Binding = new Binding("ChangeText"),
        };
        changeCol.ElementStyle = CreateTextStyle("White");
        HistoryGrid.Columns.Add(changeCol);

        var eventCol = new DataGridTextColumn
        {
            Header = "Event",
            Width = new DataGridLength(80),
            Binding = new Binding("EventType"),
        };
        eventCol.ElementStyle = CreateEventTypeStyle();
        HistoryGrid.Columns.Add(eventCol);
    }

    private void OnClose(object sender, RoutedEventArgs e) => Close();

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        EnableDragMove(sender, e);
    }

    private static Style CreateTextStyle(string colorStr)
    {
        var style = new Style(typeof(TextBlock));
        var color = (Color)ColorConverter.ConvertFromString(colorStr);
        style.Setters.Add(new Setter(TextBlock.ForegroundProperty, new SolidColorBrush(color)));
        style.Setters.Add(new Setter(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center));
        return style;
    }

    private static Style CreateEventTypeStyle()
    {
        var style = new Style(typeof(TextBlock));
        style.Setters.Add(new Setter(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center));

        // Use triggers for color-coding
        var startedTrigger = new DataTrigger { Binding = new Binding("EventType"), Value = TimerEventType.Started };
        startedTrigger.Setters.Add(new Setter(TextBlock.ForegroundProperty,
            new SolidColorBrush((Color)ColorConverter.ConvertFromString("#34C759"))));

        var pausedTrigger = new DataTrigger { Binding = new Binding("EventType"), Value = TimerEventType.Paused };
        pausedTrigger.Setters.Add(new Setter(TextBlock.ForegroundProperty,
            new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FF9F0A"))));

        var restartedTrigger = new DataTrigger { Binding = new Binding("EventType"), Value = TimerEventType.Restarted };
        restartedTrigger.Setters.Add(new Setter(TextBlock.ForegroundProperty,
            new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FF453A"))));

        var setTrigger = new DataTrigger { Binding = new Binding("EventType"), Value = TimerEventType.Set };
        setTrigger.Setters.Add(new Setter(TextBlock.ForegroundProperty,
            new SolidColorBrush((Color)ColorConverter.ConvertFromString("#0A84FF"))));

        style.Triggers.Add(startedTrigger);
        style.Triggers.Add(pausedTrigger);
        style.Triggers.Add(restartedTrigger);
        style.Triggers.Add(setTrigger);

        return style;
    }
}

internal sealed class TimestampToLocalConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is DateTimeOffset dto)
            return dto.ToLocalTime().ToString("MM/dd HH:mm:ss", CultureInfo.InvariantCulture);
        return "";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
