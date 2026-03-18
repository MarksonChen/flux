using System.Globalization;
using System.Windows;
using System.Windows.Threading;
using Flux.Infrastructure;
using Flux.Models;
using Flux.Utilities;

namespace Flux.Services;

public sealed class TimerController : ObservableObject
{
    private readonly TimerState _state;
    private readonly EventLogger _eventLogger;
    private readonly Action _onStateChanged;
    private readonly DispatcherTimer _refreshTimer;
    private string _displayTime = "00:00";

    public string DisplayTime
    {
        get => _displayTime;
        private set => SetProperty(ref _displayTime, value);
    }

    public bool IsRunning => _state.IsRunning;

    public TimerController(TimerState state, EventLogger eventLogger, Action onStateChanged)
    {
        _state = state;
        _eventLogger = eventLogger;
        _onStateChanged = onStateChanged;

        _refreshTimer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(100)
        };
        _refreshTimer.Tick += OnRefreshTick;

        UpdateDisplay();
    }

    public void Start()
    {
        _refreshTimer.Start();
    }

    public void ResumeFromPersistence()
    {
        if (_state.IsRunning)
        {
            var now = NowUtcSeconds();
            _state.AccumulatedSeconds += now - _state.PreviousTimestampUtcSeconds;
            _state.PreviousTimestampUtcSeconds = now;
            // Do NOT log Started on recovery
        }
        UpdateDisplay();
    }

    public void Toggle()
    {
        if (_state.IsRunning)
            Pause();
        else
            Resume();
    }

    public void Resume()
    {
        if (_state.IsRunning) return;
        var now = NowUtcSeconds();
        _state.PreviousTimestampUtcSeconds = now;
        _state.IsRunning = true;
        _eventLogger.LogStarted(GetElapsed());
        _onStateChanged();
        UpdateDisplay();
    }

    public void Pause()
    {
        if (!_state.IsRunning) return;
        var now = NowUtcSeconds();
        _state.AccumulatedSeconds += now - _state.PreviousTimestampUtcSeconds;
        _state.PreviousTimestampUtcSeconds = now;
        _state.IsRunning = false;
        _eventLogger.LogPaused(GetElapsed());
        _onStateChanged();
        UpdateDisplay();
    }

    public void Reset()
    {
        var oldElapsed = GetElapsed();
        var now = NowUtcSeconds();
        _state.AccumulatedSeconds = 0;
        _state.PreviousTimestampUtcSeconds = now;
        // IsRunning preserved
        _eventLogger.LogRestarted(oldElapsed);
        _onStateChanged();
        UpdateDisplay();
    }

    public void SetTime(double newValueSeconds)
    {
        var oldElapsed = GetElapsed();
        var now = NowUtcSeconds();
        _state.AccumulatedSeconds = newValueSeconds;
        _state.PreviousTimestampUtcSeconds = now;
        // IsRunning preserved
        _eventLogger.LogSet(oldElapsed, newValueSeconds);
        _onStateChanged();
        UpdateDisplay();
    }

    public double GetElapsed()
    {
        if (_state.IsRunning)
            return _state.AccumulatedSeconds + (NowUtcSeconds() - _state.PreviousTimestampUtcSeconds);
        return _state.AccumulatedSeconds;
    }

    public string CopyRoundedMinutes()
    {
        var text = TimeFormatter.CopyText(GetElapsed());
        Clipboard.SetText(text);
        return text;
    }

    public void CopyAndReset()
    {
        CopyRoundedMinutes();
        Reset();
    }

    private void OnRefreshTick(object? sender, EventArgs e)
    {
        UpdateDisplay();
    }

    private void UpdateDisplay()
    {
        DisplayTime = TimeFormatter.FormatDisplay(GetElapsed());
    }

    private static double NowUtcSeconds()
    {
        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
    }
}
