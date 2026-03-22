import 'package:dio/dio.dart';

Response<Map<String, dynamic>> fakeResponse(
  Map<String, dynamic>? data, {
  int statusCode = 200,
}) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/fake'),
  );
}
