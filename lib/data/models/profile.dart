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
  String get name =>
      displayName?.trim().isNotEmpty ?? false ? displayName!.trim() : username;

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

/// The fields a profile owner can change: the write side of [Profile].
///
/// A draft, not a [Profile], because a profile cannot be *created* from the app — the signup
/// trigger owns that — and because the two are not the same shape. This deliberately carries no
/// avatar: there is no field for one and no bucket for one, and `avatar_url` on a write would
/// null the column for anyone who already has an avatar. That is why [toUpdateJson] exists here
/// rather than on [Profile], which used to have a write payload that did exactly that.
@immutable
class ProfileDraft {
  const ProfileDraft({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
  });

  /// Whose row. The update policy (`profiles_update_own`) requires this to be the caller.
  final String id;

  /// Required and unique in the table. Taken names are refused by the database, and the
  /// repository turns that refusal into a message a person can act on.
  final String username;

  final String? displayName;
  final String? bio;

  Map<String, dynamic> toUpdateJson() => {
        'username': username,
        'display_name': displayName,
        'bio': bio,
      };
}
