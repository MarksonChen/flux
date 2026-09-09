using System.Windows.Threading;

namespace Flux.Infrastructure;

public sealed class Debouncer
{
    private readonly DispatcherTimer _timer;
    private Action? _pendingAction;

    public Debouncer(TimeSpan delay)
    {
        _timer = new DispatcherTimer { Interval = delay };
        _timer.Tick += OnTick;
    }

    public void Debounce(Action action)
    {
        _pendingAction = action;
        _timer.Stop();
        _timer.Start();
    }

    public void Flush()
    {
        if (_pendingAction is { } action)
        {
            _timer.Stop();
            _pendingAction = null;
            action();
        }
    }

    private void OnTick(object? sender, EventArgs e)
    {
        _timer.Stop();
        var action = _pendingAction;
        _pendingAction = null;
        action?.Invoke();
    }
}
