using System.Collections.ObjectModel;
using Flux.Models;
using Flux.Utilities;

namespace Flux.Services;

public sealed class EventLogger
{
    private const int MaxEvents = 20;

    public ObservableCollection<TimerEvent> Events { get; } = new();

    public void Initialize(List<TimerEvent> saved)
    {
        Events.Clear();
        // saved is oldest-first from JSON; we display newest-first
        for (int i = saved.Count - 1; i >= 0; i--)
            Events.Add(saved[i]);
    }

    public void LogStarted(double elapsedSeconds)
    {
        var changeText = TimeFormatter.FormatDisplay(elapsedSeconds) + " \u25B6";
        Insert(TimerEventType.Started, changeText);
    }

    public void LogPaused(double elapsedSeconds)
    {
        var changeText = TimeFormatter.FormatDisplay(elapsedSeconds) + " \u23F8";
        Insert(TimerEventType.Paused, changeText);
    }

    public void LogRestarted(double oldElapsedSeconds)
    {
        var changeText = TimeFormatter.FormatDisplay(oldElapsedSeconds) + " \u2192 00:00";
        Insert(TimerEventType.Restarted, changeText);
    }

    public void LogSet(double oldElapsedSeconds, double newElapsedSeconds)
    {
        var changeText = TimeFormatter.FormatDisplay(oldElapsedSeconds) + " \u2192 " +
                         TimeFormatter.FormatDisplay(newElapsedSeconds);
        Insert(TimerEventType.Set, changeText);
    }

    public List<TimerEvent> ToSerializableList()
    {
        // Return oldest-first for JSON
        var list = new List<TimerEvent>(Events);
        list.Reverse();
        return list;
    }

    private void Insert(TimerEventType eventType, string changeText)
    {
        Events.Insert(0, new TimerEvent
        {
            TimestampUtc = DateTimeOffset.UtcNow,
            EventType = eventType,
            ChangeText = changeText
        });

        while (Events.Count > MaxEvents)
            Events.RemoveAt(Events.Count - 1);
    }
}
