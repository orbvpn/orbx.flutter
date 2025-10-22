import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../security/certificate_manager.dart';
import '../config/environment_config.dart';
import '../../data/repositories/auth_repository.dart';

/// Secure HTTP client with automatic certificate management
class SecureHttpClient {
  /// Create a configured Dio instance
  static Dio create({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? headers,
    bool enableLogging = true,
    AuthRepository? authRepository,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout ?? EnvironmentConfig.connectionTimeout,
        receiveTimeout: receiveTimeout ?? EnvironmentConfig.receiveTimeout,
        sendTimeout: sendTimeout ?? EnvironmentConfig.receiveTimeout,
        headers: headers ?? {},
        validateStatus: (status) => status != null && status < 500,
        followRedirects: true,
        maxRedirects: 3,
      ),
    );

    // Configure HTTP client adapter with automatic SSL management
    dio.httpClientAdapter = _createSecureAdapter();

    // Add logging interceptor
    if (enableLogging && EnvironmentConfig.showNetworkLogs) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          requestHeader: true,
          responseHeader: false,
          logPrint: (obj) {
            if (EnvironmentConfig.showNetworkLogs) {
              print('🌐 HTTP: $obj');
            }
          },
        ),
      );
    }

    // Add authentication interceptor (if auth repository provided)
    if (authRepository != null) {
      dio.interceptors.add(_AuthInterceptor(authRepository));
    }

    // Add retry interceptor
    dio.interceptors.add(_RetryInterceptor(dio));

    // Add error handling interceptor
    dio.interceptors.add(_ErrorInterceptor());

    return dio;
  }

  /// Create HTTP client adapter with automatic certificate validation
  static IOHttpClientAdapter _createSecureAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        // Configure timeouts
        client.connectionTimeout = EnvironmentConfig.connectionTimeout;
        client.idleTimeout = const Duration(seconds: 15);

        // Configure automatic certificate validation
        client.badCertificateCallback = (cert, host, port) {
          // Use automatic certificate manager (TOFU approach)
          return CertificateManager.validateCertificate(
            cert,
            host,
            port,
          );
        };

        return client;
      },
    );
  }

  /// Create client for OrbNet API
  static Dio createOrbNetClient({AuthRepository? authRepository}) {
    final client = create(
      baseUrl: EnvironmentConfig.orbnetApiUrl,
      enableLogging: true,
      authRepository: authRepository,
    );

    return client;
  }

  /// Create client for OrbX servers
  static Dio createOrbXClient({AuthRepository? authRepository}) {
    return create(
      enableLogging: true,
      authRepository: authRepository,
    );
  }
}

/// Retry interceptor for transient failures
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries = 3;
  final Duration retryDelay = const Duration(seconds: 2);

  _RetryInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    if (EnvironmentConfig.enableDebugLogging) {
      print('🔄 Retrying request (${retryCount + 1}/$maxRetries)...');
    }

    await Future.delayed(retryDelay * (retryCount + 1));

    err.requestOptions.extra['retryCount'] = retryCount + 1;

    try {
      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}

/// Error handling interceptor
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (EnvironmentConfig.enableDebugLogging) {
      print('❌ HTTP Error:');
      print('   Type: ${err.type}');
      print('   Message: ${err.message}');
      print('   URL: ${err.requestOptions.uri}');

      if (err.response != null) {
        print('   Status: ${err.response?.statusCode}');
        print('   Data: ${err.response?.data}');
      }
    }

    String userMessage = _getUserFriendlyMessage(err);

    final enhancedError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      message: userMessage,
    );

    return handler.next(enhancedError);
  }

  String _getUserFriendlyMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. The server is taking too long to respond.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. The server is not responding.';
      case DioExceptionType.badCertificate:
        return 'SSL certificate error. The server certificate cannot be verified.';
      case DioExceptionType.connectionError:
        return 'Connection error. Unable to reach the server.';
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == 401) {
          return 'Authentication failed. Please log in again.';
        } else if (statusCode == 403) {
          return 'Access denied. You don\'t have permission.';
        } else if (statusCode == 404) {
          return 'Server not found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Request failed with status $statusCode.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        return err.message ?? 'An unknown error occurred.';
    }
  }
}

/// Authentication interceptor
///
/// Automatically adds Bearer token to requests and handles 401 errors
class _AuthInterceptor extends Interceptor {
  final AuthRepository _authRepository;

  _AuthInterceptor(this._authRepository);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Skip auth for retry requests after refresh to prevent loops
      if (options.extra['isRetryAfterRefresh'] == true) {
        return handler.next(options);
      }

      // Get access token from repository
      final token = await _authRepository.getAccessToken();

      if (token != null && token.isNotEmpty) {
        // Add Bearer token to Authorization header
        options.headers['Authorization'] = 'Bearer $token';

        if (EnvironmentConfig.enableDebugLogging) {
          print('🔐 Added auth token to request: ${options.uri}');
        }
      } else {
        if (EnvironmentConfig.enableDebugLogging) {
          print('⚠️  No auth token available for: ${options.uri}');
        }
      }
    } catch (e) {
      if (EnvironmentConfig.enableDebugLogging) {
        print('⚠️  Failed to get auth token: $e');
      }
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Prevent infinite refresh loops
    if (err.requestOptions.extra['isRetryAfterRefresh'] == true) {
      if (EnvironmentConfig.enableDebugLogging) {
        print('⚠️  Retry after refresh failed, not attempting again');
      }
      return handler.next(err);
    }

    // Handle 401 Unauthorized errors
    if (err.response?.statusCode == 401) {
      if (EnvironmentConfig.enableDebugLogging) {
        print('🔐 Authentication error (401) - token expired or invalid');
        print('   URL: ${err.requestOptions.uri}');
      }

      try {
        // Attempt to refresh token
        final refreshed = await _authRepository.refreshToken();

        if (refreshed) {
          if (EnvironmentConfig.enableDebugLogging) {
            print('✅ Token refreshed successfully, retrying request...');
          }

          // Get new token
          final token = await _authRepository.getAccessToken();

          if (token != null && token.isNotEmpty) {
            // Clone the request options
            final options = err.requestOptions;

            // Update with new token
            options.headers['Authorization'] = 'Bearer $token';

            // Mark as retry to prevent loops
            options.extra['isRetryAfterRefresh'] = true;

            // ✅ FIXED: Use handler.resolve with the cloned request
            // This will go through the interceptor chain again
            try {
              // Re-send the request through the same Dio instance
              final response = await Dio().fetch(options);
              return handler.resolve(response);
            } catch (e) {
              if (EnvironmentConfig.enableDebugLogging) {
                print('❌ Retry after refresh failed: $e');
              }
              // Let it fall through to logout
            }
          }
        }

        if (EnvironmentConfig.enableDebugLogging) {
          print('❌ Token refresh failed - logging out');
        }

        // Token refresh failed, logout user
        await _authRepository.logout();
      } catch (e) {
        if (EnvironmentConfig.enableDebugLogging) {
          print('❌ Error during token refresh: $e');
        }

        // If refresh fails, logout user
        await _authRepository.logout();
      }
    }

    return handler.next(err);
  }
}
