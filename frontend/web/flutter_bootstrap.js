{{flutter_js}}
{{flutter_build_config}}

// Offline rule: never fetch fallback fonts from fonts.gstatic.com.
// All UI text uses the bundled LiberationSans; missing glyphs resolve locally (404, no internet).
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "assets/fallback-fonts/",
  },
});
