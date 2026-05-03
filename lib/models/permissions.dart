import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Predefined permission roles
enum FilePermission {
  admin,      // Full access to all files
  editor,     // Read/write access, documents only
  viewer,     // Read-only access
  manager,    // Access to reports and data
  custom,     // Custom permission set
}

extension FilePermissionExtension on FilePermission {
  String get label {
    return {
      FilePermission.admin: 'Admin',
      FilePermission.editor: 'Editor',
      FilePermission.viewer: 'Viewer',
      FilePermission.manager: 'Manager',
      FilePermission.custom: 'Custom',
    }[this] ?? 'Unknown';
  }

  String get description {
    return {
      FilePermission.admin: 'Full access to all files and settings',
      FilePermission.editor: 'Can view and edit documents',
      FilePermission.viewer: 'Read-only access to files',
      FilePermission.manager: 'Access to reports and statistics',
      FilePermission.custom: 'Custom permission set',
    }[this] ?? 'Unknown';
  }
}

/// Represents a receiver with specific permissions and roles
class ReceiverPermissions {
  /// Unique identifier for this receiver
  final String id;

  /// Human-readable name (e.g., "John's Device", "Team Manager")
  final String name;

  /// Assigned roles that determine file access
  final Set<FilePermission> roles;

  /// Explicit file ID → access boolean mapping (overrides role-based access)
  final Map<String, bool> fileAccess;

  /// When this permission token was generated
  final DateTime generatedAt;

  /// When this permission token expires (optional)
  final DateTime? expiresAt;

  /// Email or identifier of the receiver (optional)
  final String? email;

  /// Metadata/notes about this receiver
  final String? notes;

  ReceiverPermissions({
    required this.id,
    required this.name,
    required this.roles,
    this.fileAccess = const {},
    required this.generatedAt,
    this.expiresAt,
    this.email,
    this.notes,
  });

  /// Check if token is expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Check if token is still valid (not expired)
  bool get isValid => !isExpired;

  /// Get remaining time until expiration
  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Check if this permission has a specific role
  bool hasRole(FilePermission role) => roles.contains(role);

  /// Check if receiver is admin
  bool get isAdmin => roles.contains(FilePermission.admin);

  /// Generate URL-safe token with HMAC signature
  /// 
  /// Parameters:
  /// - [secret]: HMAC secret key (use strong, random key in production)
  /// 
  /// Returns: Base64-encoded token with signature
  String generateToken({String secret = 'default-secret'}) {
    final data = {
      'id': id,
      'name': name,
      'roles': roles.map((r) => r.toString().split('.').last).toList(),
      'fileAccess': fileAccess,
      'generatedAt': generatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'email': email,
      'notes': notes,
    };

    final json = jsonEncode(data);
    final base64 = base64Encode(utf8.encode(json));

    // HMAC-SHA256 signature
    final hmac = Hmac(sha256, utf8.encode(secret));
    final signature = hmac.convert(utf8.encode(base64)).toString();

    // Return: base64.signature (allows splitting on '.')
    return '$base64.$signature';
  }

  /// Decode and verify token from URL
  /// 
  /// Parameters:
  /// - [token]: URL token string (base64.signature format)
  /// - [secret]: HMAC secret key (must match generation secret)
  /// 
  /// Returns: ReceiverPermissions if valid, null if invalid/expired
  static ReceiverPermissions? fromToken(
    String token, {
    String secret = 'default-secret',
  }) {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return null;

      final base64 = parts[0];
      final providedSignature = parts[1];

      // Verify HMAC signature
      final hmac = Hmac(sha256, utf8.encode(secret));
      final expectedSignature = hmac.convert(utf8.encode(base64)).toString();

      if (providedSignature != expectedSignature) {
        return null; // Signature mismatch - token tampered
      }

      // Decode payload
      final json = jsonDecode(utf8.decode(base64Decode(base64)));

      final permissions = ReceiverPermissions(
        id: json['id'] as String,
        name: json['name'] as String,
        roles: Set<FilePermission>.from(
          (json['roles'] as List<dynamic>).map(
            (r) => FilePermission.values.byName(r as String),
          ),
        ),
        fileAccess: Map<String, bool>.from(
          json['fileAccess'] as Map<String, dynamic>? ?? {},
        ),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        email: json['email'] as String?,
        notes: json['notes'] as String?,
      );

      // Check expiration
      if (!permissions.isValid) return null;

      return permissions;
    } catch (e) {
      return null;
    }
  }

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roles': roles.map((r) => r.label).toList(),
    'email': email,
    'isValid': isValid,
    'isExpired': isExpired,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  @override
  String toString() =>
      'ReceiverPermissions($id, $name, roles: ${roles.map((r) => r.label).join(", ")}, valid: $isValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiverPermissions &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          generatedAt == other.generatedAt;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ generatedAt.hashCode;
}

/// Extends SharedFile with permission information
class SharedFileWithPermissions {
  /// Unique file identifier
  final String id;

  /// Original filename
  final String name;

  /// File system path
  final String path;

  /// File size in bytes
  final int size;

  /// MIME type (e.g., "application/pdf")
  final String mimeType;

  /// When file was shared
  final DateTime sharedAt;

  /// Roles required to access (empty = everyone with role can access)
  final Set<FilePermission> requiredPermissions;

  /// Specific receiver IDs allowed (empty = anyone with role can access)
  final Set<String> explicitReceiverIds;

  /// If true, anyone can access without token
  final bool isPublic;

  /// Category tag for organizing files
  final String? category;

  SharedFileWithPermissions({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.sharedAt,
    this.requiredPermissions = const {FilePermission.viewer},
    this.explicitReceiverIds = const {},
    this.isPublic = false,
    this.category,
  });

  /// Formatted file size (e.g., "1.5 MB")
  String get formattedSize {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (size == 0) return '0 B';
    final i = (log(size.toDouble()) / log(1024.0)).floor();
    return '${(size / (1 << (i * 10))).toStringAsFixed(2)} ${sizes[i]}';
  }

  /// Get file extension from path
  String get extension {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  /// Check if a receiver has access to this file
  /// 
  /// Returns true if:
  /// 1. File is public, OR
  /// 2. Receiver is explicitly allowed, OR
  /// 3. Receiver has required role(s)
  bool canAccess(ReceiverPermissions receiver) {
    // Check token validity
    if (!receiver.isValid) return false;

    // Public files are accessible by everyone
    if (isPublic) return true;

    // Admin has access to everything
    if (receiver.isAdmin) return true;

    // Check explicit receiver ID
    if (explicitReceiverIds.contains(receiver.id)) return true;

    // Check explicit file access mapping
    if (receiver.fileAccess.containsKey(id)) {
      return receiver.fileAccess[id] ?? false;
    }

    // Check role-based access
    if (requiredPermissions.isEmpty) return true;
    return receiver.roles.any((role) => requiredPermissions.contains(role));
  }

  /// Get access description for this file
  String getAccessDescription(ReceiverPermissions receiver) {
    if (!canAccess(receiver)) {
      return 'No access';
    }
    if (isPublic) {
      return 'Public (anyone)';
    }
    if (receiver.isAdmin) {
      return 'Admin access';
    }
    if (explicitReceiverIds.contains(receiver.id)) {
      return 'Explicitly granted';
    }
    final accessRoles = receiver.roles
        .where((role) => requiredPermissions.contains(role))
        .map((r) => r.label)
        .join(', ');
    return 'Access via: $accessRoles';
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'formattedSize': formattedSize,
    'mimeType': mimeType,
    'sharedAt': sharedAt.toIso8601String(),
    'category': category,
    'isPublic': isPublic,
  };

  /// Convert to JSON with detailed permissions (for admin view)
  Map<String, dynamic> toJsonWithPermissions() => {
    ...toJson(),
    'requiredPermissions': requiredPermissions.map((r) => r.label).toList(),
    'explicitReceiverCount': explicitReceiverIds.length,
    'isRestricted': !isPublic,
  };

  /// Copy with modified permissions
  SharedFileWithPermissions copyWith({
    Set<FilePermission>? requiredPermissions,
    Set<String>? explicitReceiverIds,
    bool? isPublic,
    String? category,
  }) =>
      SharedFileWithPermissions(
        id: id,
        name: name,
        path: path,
        size: size,
        mimeType: mimeType,
        sharedAt: sharedAt,
        requiredPermissions: requiredPermissions ?? this.requiredPermissions,
        explicitReceiverIds: explicitReceiverIds ?? this.explicitReceiverIds,
        isPublic: isPublic ?? this.isPublic,
        category: category ?? this.category,
      );

  @override
  String toString() =>
      'SharedFileWithPermissions($name, size: $formattedSize, permissions: ${requiredPermissions.map((r) => r.label).join(", ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedFileWithPermissions &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Collection of pre-defined permission sets for common scenarios
class PermissionPresets {
  /// Everyone can access (read-only)
  static final public = {FilePermission.viewer};

  /// Team members can access and edit
  static final team = {FilePermission.editor, FilePermission.viewer};

  /// Managers can access and view reports
  static final management = {FilePermission.manager, FilePermission.viewer};

  /// Only specific admins
  static final restricted = {FilePermission.admin};

  /// Common preset combinations
  static final commonPresets = {
    'Public': public,
    'Team': team,
    'Management': management,
    'Restricted': restricted,
  };

  /// Get preset by name
  static Set<FilePermission>? getPreset(String name) =>
      commonPresets[name];

  /// List all available presets
  static List<String> get presetNames => commonPresets.keys.toList();
}
