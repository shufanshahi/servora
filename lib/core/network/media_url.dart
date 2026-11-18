/// Host names that only mean "this machine".
const _loopbackHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

/// Makes a media URL from the API (a service picture) reachable from this device.
///
/// The server builds picture URLs from its own `PUBLIC_BASE_URL`, which in local
/// development is usually `http://localhost:3000`. On a phone or the Android emulator
/// `localhost` is the device itself, so those pictures would never load. This swaps a
/// loopback origin for the origin of [apiBaseUrl] (the address the app already uses to
/// reach the API) and resolves a bare path such as `/images/a.jpg` against it. Any
/// other absolute URL (a CDN, a hosted backend) is returned unchanged.
String resolveMediaUrl(String url, String apiBaseUrl) {
  final trimmed = url.trim();
  final base = Uri.tryParse(apiBaseUrl);
  final uri = Uri.tryParse(trimmed);
  if (base == null || !base.hasScheme || uri == null) return trimmed;

  if (!uri.hasScheme) {
    return trimmed.startsWith('/')
        ? base.replace(path: trimmed, query: null).toString()
        : trimmed;
  }
  if (!_loopbackHosts.contains(uri.host)) return trimmed;
  // Already pointing where the API lives (for example both are localhost on desktop).
  if (base.host == uri.host) return trimmed;

  return uri
      .replace(scheme: base.scheme, host: base.host, port: base.port)
      .toString();
}
