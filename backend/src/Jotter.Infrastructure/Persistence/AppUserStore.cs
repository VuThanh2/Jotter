using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// Tắt AutoSaveChanges để thay đổi qua UserManager chỉ được ghi nhận, rồi commit cùng phần còn lại của use case
// trong đúng một lần IUnitOfWork.SaveChangesAsync (vd. đăng ký: user + phiên + mã kích hoạt trong một transaction).
public sealed class AppUserStore : UserOnlyStore<User, AppDbContext, Guid>
{
    public AppUserStore(AppDbContext context, IdentityErrorDescriber? describer = null)
        : base(context, describer)
    {
        AutoSaveChanges = false;
    }
}
