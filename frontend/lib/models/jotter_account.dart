class JotterAccount {
  const JotterAccount({
    required this.id,
    required this.email,
    required this.displayName,
    this.isActivated = true,
    this.avatarUrl,
  });

  factory JotterAccount.fromJson(Map<String, dynamic> json) => JotterAccount(
    id: json['userId'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    isActivated: json['isActivated'] as bool? ?? false,
    avatarUrl: json['avatarUrl'] as String?,
  );

  final String id;
  final String email;
  final String displayName;
  final bool isActivated;
  final String? avatarUrl;

  JotterAccount copyWith({
    String? displayName,
    bool? isActivated,
    String? avatarUrl,
    bool clearAvatar = false,
  }) => JotterAccount(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    isActivated: isActivated ?? this.isActivated,
    avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
  );
}
