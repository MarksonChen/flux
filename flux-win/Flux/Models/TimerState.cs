namespace Flux.Models;

public sealed class TimerState
{
    public double AccumulatedSeconds { get; set; }
    public double PreviousTimestampUtcSeconds { get; set; }
    public bool IsRunning { get; set; }
}
