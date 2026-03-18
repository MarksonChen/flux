using System.Windows.Input;
using Flux.Interop;
using Flux.Models;

namespace Flux.Services;

public sealed class GlobalHotkeyService
{
    private const int ToggleId = 1;
    private const int CopyResetId = 2;

    private nint _hwnd;
    private GlobalHotkeyBindings _bindings;
    private GlobalHotkeyBinding? _lastGoodToggle;
    private GlobalHotkeyBinding? _lastGoodCopyReset;

    public string? LastError { get; private set; }

    public GlobalHotkeyService(GlobalHotkeyBindings bindings)
    {
        _bindings = bindings;
    }

    public void Initialize(nint hwnd)
    {
        _hwnd = hwnd;
        RegisterAll();
    }

    public void UpdateBindings(GlobalHotkeyBindings bindings)
    {
        UnregisterAll();
        _bindings = bindings;
        RegisterAll();
    }

    public void RegisterAll()
    {
        LastError = null;

        if (_bindings.TogglePauseResume.Enabled)
        {
            if (TryRegister(ToggleId, _bindings.TogglePauseResume.Chord))
                _lastGoodToggle = _bindings.TogglePauseResume;
            else
            {
                LastError = $"Failed to register global hotkey: {_bindings.TogglePauseResume.Chord}";
                // Try reverting to last good
                if (_lastGoodToggle is not null && !_lastGoodToggle.Chord.Matches(_bindings.TogglePauseResume.Chord))
                    TryRegister(ToggleId, _lastGoodToggle.Chord);
            }
        }

        if (_bindings.CopyAndReset.Enabled)
        {
            if (TryRegister(CopyResetId, _bindings.CopyAndReset.Chord))
                _lastGoodCopyReset = _bindings.CopyAndReset;
            else
            {
                LastError = (LastError is null ? "" : LastError + "\n") +
                            $"Failed to register global hotkey: {_bindings.CopyAndReset.Chord}";
                if (_lastGoodCopyReset is not null && !_lastGoodCopyReset.Chord.Matches(_bindings.CopyAndReset.Chord))
                    TryRegister(CopyResetId, _lastGoodCopyReset.Chord);
            }
        }
    }

    public void UnregisterAll()
    {
        NativeMethods.UnregisterHotKey(_hwnd, ToggleId);
        NativeMethods.UnregisterHotKey(_hwnd, CopyResetId);
    }

    public string? HandleHotkey(nint id)
    {
        if (id == ToggleId) return "TogglePauseResume";
        if (id == CopyResetId) return "CopyAndReset";
        return null;
    }

    private bool TryRegister(int id, KeyChord chord)
    {
        NativeMethods.UnregisterHotKey(_hwnd, id);

        uint mods = NativeConstants.MOD_NOREPEAT;
        if (chord.Modifiers.HasFlag(ShortcutModifiers.Ctrl)) mods |= NativeConstants.MOD_CONTROL;
        if (chord.Modifiers.HasFlag(ShortcutModifiers.Alt)) mods |= NativeConstants.MOD_ALT;
        if (chord.Modifiers.HasFlag(ShortcutModifiers.Shift)) mods |= NativeConstants.MOD_SHIFT;

        if (!Enum.TryParse<Key>(chord.Key, out var key))
            return false;

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        return NativeMethods.RegisterHotKey(_hwnd, id, mods, vk);
    }
}
