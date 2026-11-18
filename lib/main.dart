import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/app.dart';

void main() {
  _registerFontLicenses();
  runApp(const ProviderScope(child: ServoraApp()));
}

/// The bundled fonts are under the SIL Open Font License, which asks for the licence
/// to travel with the font. This lists them on the app's licences page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [
      ('Manrope', 'assets/fonts/OFL-Manrope.txt'),
      ('Playfair Display', 'assets/fonts/OFL-PlayfairDisplay.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    }
  });
}
