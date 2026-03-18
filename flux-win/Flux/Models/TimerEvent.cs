namespace Flux.Models;

public enum TimerEventType
{
    Started,
    Paused,
    Restarted,
    Set
}

public sealed class TimerEvent
{
    public DateTimeOffset TimestampUtc { get; set; }
    public TimerEventType EventType { get; set; }
    public string ChangeText { get; set; } = "";
}
