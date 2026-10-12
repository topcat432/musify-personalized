// Own namespace; real Settings/player/shell, local synthetic audio only.
import 'acceptance_mini_shell_native.dart';

Future<void> main() => runOwnedShellRehearsal(
  namespace: 'acceptance_preferences_gestures_v1',
  initialPreferences: const {
    'accentColor': 0xff91cef4,
    'audioQuality': 'high',
    'sponsorBlockSupport': false,
    'externalRecommendations': false,
    'shuffleEnabled': false,
    'repeatMode': 0,
  },
);
