using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using Flux.Models;

namespace Flux.Views.Converters;

public sealed class EventTypeToBrushConverter : IValueConverter
{
    private static readonly SolidColorBrush StartedBrush = new((Color)ColorConverter.ConvertFromString("#34C759"));
    private static readonly SolidColorBrush PausedBrush = new((Color)ColorConverter.ConvertFromString("#FF9F0A"));
    private static readonly SolidColorBrush RestartedBrush = new((Color)ColorConverter.ConvertFromString("#FF453A"));
    private static readonly SolidColorBrush SetBrush = new((Color)ColorConverter.ConvertFromString("#0A84FF"));
    private static readonly SolidColorBrush DefaultBrush = new(Colors.White);

    static EventTypeToBrushConverter()
    {
        StartedBrush.Freeze();
        PausedBrush.Freeze();
        RestartedBrush.Freeze();
        SetBrush.Freeze();
        DefaultBrush.Freeze();
    }

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is TimerEventType eventType)
        {
            return eventType switch
            {
                TimerEventType.Started => StartedBrush,
                TimerEventType.Paused => PausedBrush,
                TimerEventType.Restarted => RestartedBrush,
                TimerEventType.Set => SetBrush,
                _ => DefaultBrush
            };
        }
        return DefaultBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
