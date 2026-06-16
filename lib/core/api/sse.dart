import 'dart:convert';

/// A single decoded Server-Sent Event.
class SseEvent {
  const SseEvent(this.event, this.data);

  /// The event name (`event:` field); defaults to `message`.
  final String event;

  /// The concatenated `data:` payload (newline-joined for multi-line data).
  final String data;
}

/// Parses a raw SSE byte stream (e.g. from [ApiClient.openEventStream]) into
/// discrete [SseEvent]s. Comment lines (`: heartbeat`) and `id:`/`retry:`
/// fields are ignored. Each event is emitted on its terminating blank line.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var eventName = 'message';
  final data = StringBuffer();

  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty || eventName != 'message') {
        var text = data.toString();
        if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
        yield SseEvent(eventName, text);
      }
      eventName = 'message';
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // comment / heartbeat
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        eventName = value;
      case 'data':
        data
          ..write(value)
          ..write('\n');
      default:
        break; // id / retry — not used
    }
  }
}
