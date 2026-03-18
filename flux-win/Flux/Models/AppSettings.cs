namespace Flux.Models;

public sealed class AppSettings
{
    public string FontFamily { get; set; } = "Arial Black";
    public double FontSizePoints { get; set; } = 21;
    public string TextColorHexRgb { get; set; } = "#5DFFFF";
    public int TextOpacityPercent { get; set; } = 18;
    public bool LaunchAtLogin { get; set; }
    public bool ShowInFullScreen { get; set; }

    public static AppSettings CreateDefaults() => new();
}
