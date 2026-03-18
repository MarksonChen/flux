using System.Globalization;

namespace Flux.Utilities;

public static class TimeFormatter
{
    public static string FormatDisplay(double elapsedSeconds)
    {
        long wholeSeconds = (long)Math.Floor(Math.Max(0, elapsedSeconds));
        long hours = wholeSeconds / 3600;
        long minutes = (wholeSeconds % 3600) / 60;
        long seconds = wholeSeconds % 60;

        if (hours == 0)
            return $"{minutes:00}:{seconds:00}";
        else
            return $"{hours}:{minutes:00}:{seconds:00}";
    }

    public static long RoundedMinutes(double elapsedSeconds)
    {
        return (long)Math.Round(
            Math.Max(0, elapsedSeconds) / 60.0,
            MidpointRounding.AwayFromZero);
    }

    public static string CopyText(double elapsedSeconds)
    {
        return RoundedMinutes(elapsedSeconds).ToString(CultureInfo.InvariantCulture);
    }
}
