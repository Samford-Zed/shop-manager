// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'shopstack';

  @override
  String get welcomeTitle => 'Welcome to Shop Management';

  @override
  String get welcomeSubtitle =>
      'Manage products, record sales, and view reports—all in one place.';

  @override
  String get haveAccount => 'I have an account';

  @override
  String get createAccount => 'Create a new account';

  @override
  String get languageButton => 'Language / ቋንቋ / Afaan';

  @override
  String get chooseLanguageTitle => 'Choose language';

  @override
  String get featureProducts => 'Products';

  @override
  String get featureSales => 'Sales';

  @override
  String get featureReports => 'Reports';
}
