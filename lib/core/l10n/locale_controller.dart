import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The locales this template ships translations for.
///
/// Arabic is here on purpose: it is the cheapest way to keep the layout honest.
/// A UI that has never rendered right-to-left is full of hard-coded `left:`
/// padding nobody noticed.
enum KiteLocale {
  vi('Vietnamese', 'Tiếng Việt'),
  en('English', 'English');

  const KiteLocale(this.englishName, this.nativeName);

  final String englishName;
  final String nativeName;

  Locale get locale => Locale(name);
}

class LocaleController extends Notifier<KiteLocale> {
  @override
  KiteLocale build() => KiteLocale.vi;

  void set(KiteLocale value) => state = value;
}

final localeProvider = NotifierProvider<LocaleController, KiteLocale>(
  LocaleController.new,
);
