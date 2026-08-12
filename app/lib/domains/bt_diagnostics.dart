class BTConnectionDiagnostics {
  const BTConnectionDiagnostics({
    required this.configured,
    required this.known,
    required this.connected,
    required this.pending,
    required this.halfOpen,
    required this.seeders,
  });

  factory BTConnectionDiagnostics.fromJson(Map<String, dynamic> json) =>
      BTConnectionDiagnostics(
        configured: _nonNegativeInt(json, 'configured'),
        known: _nonNegativeInt(json, 'known'),
        connected: _nonNegativeInt(json, 'connected'),
        pending: _nonNegativeInt(json, 'pending'),
        halfOpen: _nonNegativeInt(json, 'halfOpen'),
        seeders: _nonNegativeInt(json, 'seeders'),
      );

  final int configured;
  final int known;
  final int connected;
  final int pending;
  final int halfOpen;
  final int seeders;
}

class BTTrafficDiagnostics {
  const BTTrafficDiagnostics({
    required this.receivedBytes,
    required this.usefulBytes,
    required this.uploadedBytes,
    required this.wastedChunks,
    required this.verifiedPieces,
    required this.failedPieces,
  });

  factory BTTrafficDiagnostics.fromJson(Map<String, dynamic> json) =>
      BTTrafficDiagnostics(
        receivedBytes: _nonNegativeInt(json, 'receivedBytes'),
        usefulBytes: _nonNegativeInt(json, 'usefulBytes'),
        uploadedBytes: _nonNegativeInt(json, 'uploadedBytes'),
        wastedChunks: _nonNegativeInt(json, 'wastedChunks'),
        verifiedPieces: _nonNegativeInt(json, 'verifiedPieces'),
        failedPieces: _nonNegativeInt(json, 'failedPieces'),
      );

  final int receivedBytes;
  final int usefulBytes;
  final int uploadedBytes;
  final int wastedChunks;
  final int verifiedPieces;
  final int failedPieces;
}

class BTPeerDiagnostics {
  const BTPeerDiagnostics({
    required this.address,
    required this.client,
    required this.network,
    required this.receivedBytes,
    required this.downloadRateBps,
    required this.verifiedPieces,
    required this.failedPieces,
  });

  factory BTPeerDiagnostics.fromJson(Map<String, dynamic> json) =>
      BTPeerDiagnostics(
        address: _requiredString(json, 'address'),
        client: _requiredString(json, 'client'),
        network: _requiredString(json, 'network'),
        receivedBytes: _nonNegativeInt(json, 'receivedBytes'),
        downloadRateBps: _nonNegativeInt(json, 'downloadRateBps'),
        verifiedPieces: _nonNegativeInt(json, 'verifiedPieces'),
        failedPieces: _nonNegativeInt(json, 'failedPieces'),
      );

  final String address;
  final String client;
  final String network;
  final int receivedBytes;
  final int downloadRateBps;
  final int verifiedPieces;
  final int failedPieces;
}

class BTPolicyDiagnostics {
  const BTPolicyDiagnostics({
    required this.maxPeerConnections,
    required this.explicitPeersOnly,
    required this.trackersEnabled,
    required this.dhtEnabled,
    required this.pexEnabled,
    required this.webSeedsEnabled,
    required this.inboundEnabled,
    required this.ipv6Enabled,
    required this.uploadEnabled,
    required this.seedingEnabled,
  });

  factory BTPolicyDiagnostics.fromJson(Map<String, dynamic> json) =>
      BTPolicyDiagnostics(
        maxPeerConnections: _peerConnectionLimit(json),
        explicitPeersOnly: _requiredBool(json, 'explicitPeersOnly'),
        trackersEnabled: _requiredBool(json, 'trackersEnabled'),
        dhtEnabled: _requiredBool(json, 'dhtEnabled'),
        pexEnabled: _requiredBool(json, 'pexEnabled'),
        webSeedsEnabled: _requiredBool(json, 'webSeedsEnabled'),
        inboundEnabled: _requiredBool(json, 'inboundEnabled'),
        ipv6Enabled: _requiredBool(json, 'ipv6Enabled'),
        uploadEnabled: _requiredBool(json, 'uploadEnabled'),
        seedingEnabled: _requiredBool(json, 'seedingEnabled'),
      );

  final int maxPeerConnections;
  final bool explicitPeersOnly;
  final bool trackersEnabled;
  final bool dhtEnabled;
  final bool pexEnabled;
  final bool webSeedsEnabled;
  final bool inboundEnabled;
  final bool ipv6Enabled;
  final bool uploadEnabled;
  final bool seedingEnabled;

  bool get restrictedCapabilitiesDisabled =>
      !trackersEnabled &&
      !dhtEnabled &&
      !pexEnabled &&
      !webSeedsEnabled &&
      !inboundEnabled &&
      !ipv6Enabled &&
      !uploadEnabled &&
      !seedingEnabled;
}

class BTDiagnostics {
  const BTDiagnostics({
    required this.taskId,
    required this.state,
    required this.live,
    required this.connections,
    required this.traffic,
    required this.peers,
    required this.policy,
    required this.updatedAt,
  });

  factory BTDiagnostics.fromJson(Map<String, dynamic> json) {
    final connections = json['connections'];
    final traffic = json['traffic'];
    final peers = json['peers'];
    final policy = json['policy'];
    final updatedAt = DateTime.tryParse(_requiredString(json, 'updatedAt'));
    if (connections is! Map ||
        traffic is! Map ||
        peers is! List ||
        policy is! Map ||
        updatedAt == null) {
      throw const FormatException('Invalid BT diagnostics.');
    }
    return BTDiagnostics(
      taskId: _requiredString(json, 'taskId'),
      state: _requiredString(json, 'state'),
      live: _requiredBool(json, 'live'),
      connections: BTConnectionDiagnostics.fromJson(
        Map<String, dynamic>.from(connections),
      ),
      traffic: BTTrafficDiagnostics.fromJson(
        Map<String, dynamic>.from(traffic),
      ),
      peers: peers
          .map(
            (value) => BTPeerDiagnostics.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      policy: BTPolicyDiagnostics.fromJson(Map<String, dynamic>.from(policy)),
      updatedAt: updatedAt,
    );
  }

  final String taskId;
  final String state;
  final bool live;
  final BTConnectionDiagnostics connections;
  final BTTrafficDiagnostics traffic;
  final List<BTPeerDiagnostics> peers;
  final BTPolicyDiagnostics policy;
  final DateTime updatedAt;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing BT diagnostics field: $key');
  }
  return value;
}

int _nonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Invalid BT diagnostics field: $key');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid BT diagnostics field: $key');
  }
  return value;
}

int _peerConnectionLimit(Map<String, dynamic> json) {
  final value = json['maxPeerConnections'];
  if (value is! int || value < 1 || value > 80) {
    throw const FormatException(
      'Invalid BT diagnostics field: maxPeerConnections',
    );
  }
  return value;
}
