import 'package:dio/dio.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_response.dart';
import 'package:servora/core/network/failure_mapper.dart';
import 'package:servora/core/network/page_meta.dart';

/// Supplies the current access token (or null when signed out).
typedef TokenProvider = Future<String?> Function();

const _metaKey = 'servora_meta';

/// The one HTTP client for the Servora API.
///
/// - adds the bearer token to requests
/// - removes the `{ success, data, meta }` envelope
/// - converts every failure into an [AppFailure] (nothing else is ever thrown)
/// - calls [onUnauthorized] when a request that carried a token is rejected with
///   401, so the session can be cleared in one place
class ApiClient {
  ApiClient({
    required String baseUrl,
    TokenProvider? tokenProvider,
    void Function()? onUnauthorized,
    // Lets tests replace the network layer with a fake.
    HttpClientAdapter? httpClientAdapter,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration sendTimeout = const Duration(seconds: 15),
    // Generous because free hosting tiers can take ~30s to wake up.
    Duration receiveTimeout = const Duration(seconds: 35),
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeout,
           sendTimeout: sendTimeout,
           receiveTimeout: receiveTimeout,
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
           // Let our interceptor handle non-2xx instead of dio's default.
           validateStatus: (status) => status != null && status < 400,
         ),
       ) {
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
    _dio.interceptors.addAll([
      _AuthInterceptor(tokenProvider),
      _EnvelopeInterceptor(),
      _ErrorInterceptor(onUnauthorized),
    ]);
  }

  final Dio _dio;

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<ApiResponse> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<ApiResponse> patch(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('PATCH', path, body: body, authenticated: authenticated);

  Future<ApiResponse> delete(String path, {bool authenticated = true}) =>
      _send('DELETE', path, authenticated: authenticated);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required bool authenticated,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'authenticated': authenticated},
        ),
      );
      return ApiResponse(
        data: response.data,
        meta: response.extra[_metaKey] as PageMeta?,
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }

  /// Releases the underlying connection pool.
  void close() => _dio.close();
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider);

  final TokenProvider? _tokenProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['authenticated'] != false) {
      final token = await _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

class _EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is Map<String, dynamic> && body['success'] == true) {
      final meta = body['meta'];
      if (meta is Map<String, dynamic>) {
        response.extra[_metaKey] = PageMeta.fromJson(meta);
      }
      response.data = body['data'];
      handler.next(response);
      return;
    }
    // A 2xx that is not in our envelope means something is wrong in between.
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: const UnknownFailure(),
      ),
    );
  }
}

class _ErrorInterceptor extends Interceptor {
  _ErrorInterceptor(this._onUnauthorized);

  final void Function()? _onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = mapDioException(err);

    // A token was sent and rejected: the session is no longer valid. Failed logins
    // carry no token, so a wrong password never triggers this.
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (failure is UnauthenticatedFailure &&
        sentToken &&
        failure.code != 'INVALID_CREDENTIALS') {
      _onUnauthorized?.call();
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: failure,
      ),
    );
  }
}
