namespace Flux.Infrastructure;

public sealed class SingleInstanceGuard : IDisposable
{
    private const string MutexName = "Global\\Flux_SingleInstance_7A3B2C1D";
    private readonly Mutex _mutex;
    private bool _owned;

    public SingleInstanceGuard()
    {
        _mutex = new Mutex(true, MutexName, out _owned);
    }

    public bool IsFirstInstance => _owned;

    public void Dispose()
    {
        if (_owned)
        {
            _mutex.ReleaseMutex();
            _owned = false;
        }
        _mutex.Dispose();
    }
}
