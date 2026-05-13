import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:labirynt_premium/src/models/question.dart';

// State class for Settings
class SettingsState {
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool repeatQuestions;
  final bool isDarkMode; // Added Dark Mode
  final String languageCode; // e.g. 'pl', 'en'
  final Map<Category, bool> categoryFilters;

  const SettingsState({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.repeatQuestions = false,
    this.isDarkMode = true, // Default to Dark
    this.languageCode = 'pl', // Default to Polish
    this.categoryFilters = const {
      // Labirynt
      Category.self: true,
      Category.relations: true,
      Category.emotions: true,
      Category.sex: true,
      Category.development: true,
      // Pokoje
      Category.mask: true,
      Category.weight: true,
      Category.roots: true,
      Category.bond: true,
      Category.hope: true,
      // Zblizenia
      Category.foundation: true,
      Category.intimacy: true,
      Category.shadow: true,
      Category.future: true,
      Category.appreciation: true,
      // Lodolamacz
      Category.imagination: true,
      Category.quirks: true,
      Category.stories: true,
      Category.opinions: true,
      Category.social: true,
      // Synergia
      Category.style: true,
      Category.team: true,
      Category.culture: true,
      Category.challenges: true,
      Category.vision: true,
    },
  });

  SettingsState copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? repeatQuestions,
    bool? isDarkMode,
    String? languageCode,
    Map<Category, bool>? categoryFilters,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      repeatQuestions: repeatQuestions ?? this.repeatQuestions,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      languageCode: languageCode ?? this.languageCode,
      categoryFilters: categoryFilters ?? this.categoryFilters,
    );
  }
}

// Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final sound = prefs.getBool('soundEnabled') ?? true;
    final haptics = prefs.getBool('hapticsEnabled') ?? true;
    final repeat = prefs.getBool('repeatQuestions') ?? false;
    final language = prefs.getString('languageCode') ?? 'pl';
    final darkMode = prefs.getBool('isDarkMode') ?? true;

    // Load categories
    final Map<Category, bool> filters = {};
    for (var cat in Category.values) {
      filters[cat] = prefs.getBool('cat_${cat.name}') ?? true;
    }

    state = SettingsState(
      soundEnabled: sound,
      hapticsEnabled: haptics,
      repeatQuestions: repeat,
      isDarkMode: darkMode,
      languageCode: language,
      categoryFilters: filters,
    );
  }

  Future<void> toggleSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', value);
    state = state.copyWith(soundEnabled: value);
  }

  Future<void> toggleHaptics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hapticsEnabled', value);
    state = state.copyWith(hapticsEnabled: value);
  }

  Future<void> toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', code);
    state = state.copyWith(languageCode: code);
  }

  Future<void> toggleRepeat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('repeatQuestions', value);
    state = state.copyWith(repeatQuestions: value);
  }

  Future<void> toggleCategory(Category cat, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cat_${cat.name}', value);

    final newFilters = Map<Category, bool>.from(state.categoryFilters);
    newFilters[cat] = value;
    state = state.copyWith(categoryFilters: newFilters);
  }
}

// Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
