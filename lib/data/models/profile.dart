import 'package:flutter/foundation.dart';

/// A FoodCircle user, as stored in `public.profiles`.
///
/// The row is created by the `handle_new_user` trigger when the account is created, so a client
/// never has to insert one.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: (json['username'] as String?) ?? 'unknown',
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
      );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  /// What to show in a list. Falls back to the unique username, which always exists.
  String get name => displayName?.trim().isNotEmpty ?? false
      ? displayName!.trim()
      : username;

  Map<String, dynamic> toUpdateJson() => {
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
      };

  Profile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) =>
      Profile(
        id: id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
      );
}
