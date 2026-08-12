import 'package:downpeed_flutter/domains/bt_diagnostics.dart';
import 'package:downpeed_flutter/services/bt_diagnostics_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
  test('loads only expanded diagnostics and stops after collapse', () async {
    final client = _DiagnosticsEngineClient();
    final service = BTDiagnosticsService(
      client: client,
      refreshInterval: const Duration(milliseconds: 10),
    );
    addTearDown(service.onClose);

    expect(client.calls, 0);
    await service.setExpanded('bt-1', true);
    expect(client.calls, 1);
    expect(service.forTask('bt-1')?.connections.connected, 1);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(client.calls, greaterThan(1));
    await service.setExpanded('bt-1', false);
    final callsAfterCollapse = client.calls;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(client.calls, callsAfterCollapse);
  });
}

class _DiagnosticsEngineClient extends StubEngineClient {
  int calls = 0;

  @override
  Future<BTDiagnostics> fetchBTDiagnostics(String taskId) async {
    calls++;
    return _diagnostics(taskId);
  }
}

BTDiagnostics _diagnostics(String taskId) => BTDiagnostics(
  taskId: taskId,
  state: 'downloading',
  live: true,
  connections: const BTConnectionDiagnostics(
    configured: 1,
    known: 1,
    connected: 1,
    pending: 0,
    halfOpen: 0,
    seeders: 1,
  ),
  traffic: const BTTrafficDiagnostics(
    receivedBytes: 1024,
    usefulBytes: 1024,
    uploadedBytes: 0,
    wastedChunks: 0,
    verifiedPieces: 1,
    failedPieces: 0,
  ),
  peers: const <BTPeerDiagnostics>[],
  policy: const BTPolicyDiagnostics(
    maxPeerConnections: 80,
    explicitPeersOnly: true,
    trackersEnabled: false,
    dhtEnabled: false,
    pexEnabled: false,
    webSeedsEnabled: false,
    inboundEnabled: false,
    ipv6Enabled: false,
    uploadEnabled: false,
    seedingEnabled: false,
  ),
  updatedAt: DateTime.utc(2026, 8, 12, 3),
);
