namespace Flux.Models;

public enum MouseAction
{
    None,
    TogglePauseResume,
    Reset
}

public sealed class MouseBindings
{
    public MouseAction LeftClick { get; set; }
    public MouseAction RightClick { get; set; }
    public MouseAction LeftDoubleClick { get; set; }
    public MouseAction RightDoubleClick { get; set; }

    public static MouseBindings CreateDefaults() => new()
    {
        LeftClick = MouseAction.None,
        RightClick = MouseAction.Reset,
        LeftDoubleClick = MouseAction.None,
        RightDoubleClick = MouseAction.None
    };
}
