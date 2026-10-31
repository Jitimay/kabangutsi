import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

/// Web: the fetch API streams the response body (XHR would buffer the whole SSE stream).
http.Client createStreamingClient() => FetchClient(mode: RequestMode.cors);
