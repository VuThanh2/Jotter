using Jotter.Domain;

namespace Jotter.Application;

public static class ProfileErrors
{
    public static readonly Error AvatarNotFound =
        Error.NotFound("AvatarNotFound", "Người dùng chưa có ảnh đại diện.");
}
