import 'package:dio/dio.dart';
import '../cancellation/request_cancellation.dart';
import '../errors/app_exception.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';

class ApiClient {
  ApiClient(String baseUrl, {AuthRepository? auth, Dio? transport})
    : dio =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
          ) {
    if (auth != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.extra['private'] == true &&
                options.extra['retried'] != true &&
                auth.accessToken != null) {
              options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            final options = error.requestOptions;
            if (error.response?.statusCode != 401 ||
                options.extra['private'] != true ||
                options.extra['retried'] == true) {
              handler.next(error);
              return;
            }
            try {
              final token = await auth.refresh();
              if (token == null) {
                await auth.expire();
                handler.next(error);
                return;
              }
              options.extra['retried'] = true;
              options.headers['Authorization'] = 'Bearer $token';
              final response = await dio.fetch<dynamic>(options);
              handler.resolve(response);
            } on DioException catch (retry) {
              if (retry.response?.statusCode == 401) {
                try {
                  await auth.expire();
                } on AppException catch (e) {
                  handler.reject(
                    DioException(requestOptions: options, error: e),
                  );
                  return;
                }
              }
              handler.next(retry);
            } on AppException catch (e) {
              handler.reject(DioException(requestOptions: options, error: e));
            } catch (_) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: const AppException(FailureKind.unknown),
                ),
              );
            }
          },
        ),
      );
    }
  }
  final Dio dio;
  Future<dynamic> get(
    String path, {
    RequestCancellation? cancelToken,
    bool private = false,
  }) => request(path, cancelToken: cancelToken, private: private);
  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool private = true,
  }) => request(path, method: 'PATCH', body: body, private: private);
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    RequestCancellation? cancelToken,
    bool private = false,
  }) async {
    final token = CancelToken();
    final remove = cancelToken?.listen(() => token.cancel());
    try {
      final response = await dio.request<dynamic>(
        path,
        data: body,
        cancelToken: token,
        options: Options(method: method, extra: {'private': private}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          !data.containsKey('data')) {
        throw const AppException(FailureKind.invalidResponse);
      }
      return data['data'];
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error! as AppException;
      final payload = e.response?.data;
      final detail = payload is Map ? payload['error'] : null;
      final code = detail is Map
          ? detail['code']
          : (payload is Map ? payload['code'] : null);
      throw AppException(switch (e.response?.statusCode) {
        401 => FailureKind.unauthorized,
        403 => FailureKind.forbidden,
        404 => FailureKind.notFound,
        409 => switch (code) {
          'POLICY_CUTOFF' => FailureKind.policyCutoff,
          'SLOT_ALREADY_AVAILABLE' => FailureKind.slotsAvailable,
          _ => FailureKind.bookingConflict,
        },
        400 || 422 => FailureKind.validation,
        429 => FailureKind.rateLimited,
        _ => switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => FailureKind.timeout,
          DioExceptionType.connectionError => FailureKind.network,
          DioExceptionType.cancel => FailureKind.cancelled,
          _ => FailureKind.server,
        },
      });
    } finally {
      remove?.call();
    }
  }
}
