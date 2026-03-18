namespace Flux.Utilities;

public static class FontUnitConverter
{
    public static double WpfUnitsFromPoints(double pt) => pt * 96.0 / 72.0;
    public static double PointsFromWpfUnits(double wpf) => wpf * 72.0 / 96.0;
}
