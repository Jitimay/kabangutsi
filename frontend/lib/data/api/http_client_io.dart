import 'package:http/http.dart' as http;

/// Android / tests: dart:io client streams responses natively.
http.Client createStreamingClient() => http.Client();
