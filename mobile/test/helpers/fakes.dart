import 'package:dio/dio.dart';

Response<dynamic> fakeResponse(dynamic data, {int statusCode = 200}) {
  return Response(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/fake'),
  );
}
