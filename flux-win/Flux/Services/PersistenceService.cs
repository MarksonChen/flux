using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Flux.Infrastructure;
using Flux.Models;

namespace Flux.Services;

public sealed class PersistenceService
{
    private static readonly string StateDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Flux");
    private static readonly string StatePath = Path.Combine(StateDir, "state.json");
    private static readonly string TempPath = StatePath + ".tmp";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    private readonly Debouncer _debouncer = new(TimeSpan.FromMilliseconds(250));

    public PersistedState Load()
    {
        try
        {
            if (!File.Exists(StatePath))
                return new PersistedState();

            var json = File.ReadAllText(StatePath);
            var state = JsonSerializer.Deserialize<PersistedState>(json, JsonOptions);
            return state ?? new PersistedState();
        }
        catch
        {
            TryRenameCorrupt();
            return new PersistedState();
        }
    }

    public void Save(PersistedState state)
    {
        try
        {
            Directory.CreateDirectory(StateDir);
            var json = JsonSerializer.Serialize(state, JsonOptions);
            File.WriteAllText(TempPath, json);

            if (File.Exists(StatePath))
                File.Delete(StatePath);
            File.Move(TempPath, StatePath);
        }
        catch
        {
            // Non-fatal — do not crash
        }
    }

    public void SaveDebounced(PersistedState state)
    {
        _debouncer.Debounce(() => Save(state));
    }

    public void Flush()
    {
        _debouncer.Flush();
    }

    private static void TryRenameCorrupt()
    {
        try
        {
            if (!File.Exists(StatePath)) return;
            var timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
            var corruptPath = Path.Combine(StateDir, $"state.corrupt.{timestamp}.json");
            File.Move(StatePath, corruptPath);
        }
        catch
        {
            // Best effort
        }
    }
}
