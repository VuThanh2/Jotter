namespace Jotter.Domain;

// ChangeSeqInterceptor gán giá trị từ sequence change_seq lúc lưu; Domain chỉ đọc để trả về cho client.
public interface ISyncTracked
{
    long ChangeSeq { get; }
}
