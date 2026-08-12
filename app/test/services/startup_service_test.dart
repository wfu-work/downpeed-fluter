import 'package:downpeed_flutter/services/startup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialization reads the operating system state', () async {
    final host = _FakeStartupHost(supported: true, enabled: true);
    final service = StartupService(host: host);

    await service.initialize();

    expect(service.supported.value, isTrue);
    expect(service.enabled.value, isTrue);
    expect(service.failure.value, isNull);
    expect(host.readCount, 1);
  });

  test('enable and disable are verified by reading the system back', () async {
    final host = _FakeStartupHost(supported: true, enabled: false);
    final service = StartupService(host: host);
    await service.initialize();

    expect(await service.setEnabled(true), isTrue);
    expect(service.enabled.value, isTrue);
    expect(await service.setEnabled(false), isTrue);
    expect(service.enabled.value, isFalse);
    expect(host.writes, <bool>[true, false]);
    expect(host.readCount, 3);
  });

  test('write failure restores the actual operating system state', () async {
    final host = _FakeStartupHost(
      supported: true,
      enabled: false,
      updateError: StateError('denied'),
    );
    final service = StartupService(host: host);
    await service.initialize();

    expect(await service.setEnabled(true), isFalse);

    expect(service.enabled.value, isFalse);
    expect(service.failure.value, StartupFailure.update);
    expect(host.readCount, 2);
  });

  test('verification mismatch exposes the actual system state', () async {
    final host = _FakeStartupHost(
      supported: true,
      enabled: false,
      ignoreWrites: true,
    );
    final service = StartupService(host: host);
    await service.initialize();

    expect(await service.setEnabled(true), isFalse);

    expect(service.enabled.value, isFalse);
    expect(service.failure.value, StartupFailure.verification);
  });

  test('unsupported platforms never write a login item', () async {
    final host = _FakeStartupHost(supported: false, enabled: true);
    final service = StartupService(host: host);
    await service.initialize();

    expect(await service.setEnabled(true), isFalse);
    expect(service.supported.value, isFalse);
    expect(service.enabled.value, isFalse);
    expect(host.writes, isEmpty);
    expect(host.readCount, 0);
  });
}

class _FakeStartupHost implements StartupHost {
  _FakeStartupHost({
    required this.supported,
    required this._enabled,
    this.updateError,
    this.ignoreWrites = false,
  });

  final bool supported;
  final Object? updateError;
  final bool ignoreWrites;
  bool _enabled;
  int readCount = 0;
  final writes = <bool>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> isEnabled() async {
    readCount++;
    return _enabled;
  }

  @override
  Future<bool> setEnabled(bool value) async {
    writes.add(value);
    if (updateError case final error?) throw error;
    if (!ignoreWrites) _enabled = value;
    return true;
  }
}
