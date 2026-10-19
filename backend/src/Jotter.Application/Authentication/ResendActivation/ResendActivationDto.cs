namespace Jotter.Application;

// Client khoá nút "Gửi lại mã" trong khoảng này.
public sealed record ResendActivationOutputDto(int CooldownSeconds);
