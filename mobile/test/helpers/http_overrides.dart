import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A valid 1x1 transparent PNG used as a stub response for tile requests.
final _transparentPng = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, // RGBA, 8-bit
  0x89, 0x00, 0x00, 0x00, 0x0b, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x78, 0x9c, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7a, 0x5e, 0xab, 0x3f, // end IDAT
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, // IEND chunk
  0xae, 0x42, 0x60, 0x82,
];

/// Install in tests via `HttpOverrides.global = TestHttpOverrides();`
/// to prevent real HTTP requests (e.g. map tile fetches).
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'https', host: host, port: port, path: path));

  @override
  void close({bool force = false}) {}

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) {}
  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) {}
  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) {}
  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  set keyLog(Function(String line)? callback) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;

  _FakeHttpClientRequest(this.uri);

  final _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  Encoding encoding = utf8;
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  bool followRedirects = true;
  @override
  bool persistentConnection = true;
  @override
  int maxRedirects = 5;
  @override
  String method = 'GET';

  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];

  @override
  Future<HttpClientResponse> get done => close();

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future flush() async {}
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = '']) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  List<Cookie> get cookies => [];
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  List<RedirectInfo> get redirects => [];

  @override
  X509Certificate? get certificate => null;

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket');
  }

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    throw UnsupportedError('redirect');
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable([_transparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpHeaders implements HttpHeaders {
  final _values = <String, List<String>>{};

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  String? value(String name) => _values[name.toLowerCase()]?.first;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  void clear() => _values.clear();

  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  void noFolding(String name) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
