import 'scan_event.dart';

abstract class Scanner {
  Stream<ScanEvent> get events;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
