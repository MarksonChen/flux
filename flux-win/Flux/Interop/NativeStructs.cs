using System.Runtime.InteropServices;

namespace Flux.Interop;

[StructLayout(LayoutKind.Sequential)]
internal struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;

    public int Width => Right - Left;
    public int Height => Bottom - Top;
}
