namespace Flux.Services;

public interface IVirtualDesktopService
{
    void InitializeForWindow(nint hwnd);
}

public sealed class VirtualDesktopService : IVirtualDesktopService
{
    public void InitializeForWindow(nint hwnd)
    {
        // No-op in supported v1.
    }
}
