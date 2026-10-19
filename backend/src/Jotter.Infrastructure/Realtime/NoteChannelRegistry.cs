namespace Jotter.Infrastructure;

// noteId → tập socket đang mở note đó. Presence sống trong bộ nhớ tiến trình, cố ý nằm ngoài Domain và mất khi
// khởi động lại. Một khoá chung thay vì ConcurrentDictionary lồng nhau: dọn group rỗng mà không mất lượt join chen ngang.
public sealed class NoteChannelRegistry
{
    private readonly Lock _gate = new();
    private readonly Dictionary<Guid, Dictionary<Guid, RealtimeConnection>> _channels = [];

    public void Join(Guid noteId, RealtimeConnection connection)
    {
        lock (_gate)
        {
            if (!_channels.TryGetValue(noteId, out var members))
            {
                members = [];
                _channels[noteId] = members;
            }

            members[connection.Id] = connection;
        }
    }

    public bool Leave(Guid noteId, RealtimeConnection connection)
    {
        lock (_gate)
        {
            return RemoveMember(noteId, connection.Id);
        }
    }

    // Dọn socket chết khỏi mọi group, kể cả khi client đóng tab đột ngột không kịp gửi leave.
    public IReadOnlyList<Guid> LeaveAll(RealtimeConnection connection)
    {
        lock (_gate)
        {
            var joinedNoteIds = _channels
                .Where(channel => channel.Value.ContainsKey(connection.Id))
                .Select(channel => channel.Key)
                .ToList();

            foreach (var noteId in joinedNoteIds)
            {
                RemoveMember(noteId, connection.Id);
            }

            return joinedNoteIds;
        }
    }

    // Đá mọi thiết bị của một người khỏi group, dùng khi người đó bị thu hồi quyền.
    public IReadOnlyList<RealtimeConnection> RemoveUser(Guid noteId, Guid userId)
    {
        lock (_gate)
        {
            if (!_channels.TryGetValue(noteId, out var members))
            {
                return [];
            }

            var removed = members.Values.Where(c => c.UserId == userId).ToList();
            foreach (var connection in removed)
            {
                RemoveMember(noteId, connection.Id);
            }

            return removed;
        }
    }

    public IReadOnlyList<RealtimeConnection> Members(Guid noteId)
    {
        lock (_gate)
        {
            return _channels.TryGetValue(noteId, out var members) ? members.Values.ToList() : [];
        }
    }

    public async Task BroadcastPresenceAsync(Guid noteId)
    {
        var members = Members(noteId);
        var users = members
            .DistinctBy(c => c.UserId)
            .Select(c => new PresenceUser(c.UserId, c.DisplayName))
            .ToList();

        var message = new PresenceMessage(noteId, users);
        foreach (var connection in members)
        {
            await connection.TrySendAsync(message);
        }
    }

    private bool RemoveMember(Guid noteId, Guid connectionId)
    {
        if (!_channels.TryGetValue(noteId, out var members) || !members.Remove(connectionId))
        {
            return false;
        }

        if (members.Count == 0)
        {
            _channels.Remove(noteId);
        }

        return true;
    }
}
