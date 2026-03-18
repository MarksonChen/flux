using System.Globalization;
using System.Windows.Data;
using Flux.Utilities;

namespace Flux.Views.Converters;

public sealed class PointsToWpfFontSizeConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is double points)
            return FontUnitConverter.WpfUnitsFromPoints(points);
        return 42.667; // 32pt default
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is double wpf)
            return FontUnitConverter.PointsFromWpfUnits(wpf);
        return 32.0;
    }
}
