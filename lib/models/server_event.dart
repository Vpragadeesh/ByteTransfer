/// Types of server events
enum ServerEventType {
  request,
  error,
  connectionOpened,
  connectionClosed,
}

/// Represents a server event (for logging and monitoring)
class ServerEvent {
  /// Type of event
  final ServerEventType type;

  /// File ID being accessed (null for non-file events)
  final String? fileId;

  /// IP address of the client (null for internal events)
  final String? clientIp;

  /// Timestamp of the event
  final DateTime timestamp;

  /// Optional message describing the event
  final String? message;

  ServerEvent({
    required this.type,
    this.fileId,
    this.clientIp,
    required this.timestamp,
    this.message,
  });

  /// Get formatted timestamp for display
  String get formattedTimestamp {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  String toString() =>
      'ServerEvent(${type.name} from $clientIp at $formattedTimestamp)';
}
