import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Settings screen for configuring sound, vibration, round duration,
/// manual button visibility, and resetting data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _storage.settings;
  }

  void _save(AppSettings updated) {
    setState(() => _settings = updated);
    _storage.updateSettings(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: appBgBottom,
        body: Container(
          decoration: appBackgroundDecoration,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        size: 40,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Settings',
                        style: appFont(26,
                            weight: FontWeight.w700, spacing: -0.6),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Settings List
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      const AppSectionHeader(title: 'Gameplay Defaults'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Column(
                          children: [
                            _buildDurationTile(),
                            const Divider(
                              height: 1,
                              color: appLine,
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appField,
                                  border:
                                      Border.all(color: appLine, width: 0.8),
                                ),
                                child: const Icon(Icons.touch_app_rounded,
                                    color: appText, size: 19),
                              ),
                              title: Text(
                                'Always Show Action Buttons',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appText),
                              ),
                              subtitle: Text(
                                'Show on-screen Pass & Correct buttons alongside tilt controls',
                                style: appFont(12, color: appTextDim),
                              ),
                              value: _settings.showManualButtons,
                              activeThumbColor: appBgBottom,
                              activeTrackColor: appText,
                              inactiveTrackColor: appField,
                              onChanged: (val) => _save(
                                  _settings.copyWith(showManualButtons: val)),
                            ),
                            const Divider(
                              height: 1,
                              color: appLine,
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appField,
                                  border:
                                      Border.all(color: appLine, width: 0.8),
                                ),
                                child: const Icon(Icons.swap_vert_rounded,
                                    color: appText, size: 19),
                              ),
                              title: Text(
                                'Invert Tilt Controls',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appText),
                              ),
                              subtitle: Text(
                                _settings.invertTilt
                                    ? 'Inverted: Tilt UP = Correct, Tilt DOWN = Pass'
                                    : 'Default: Tilt DOWN = Correct, Tilt UP = Pass',
                                style: appFont(12, color: appTextDim),
                              ),
                              value: _settings.invertTilt,
                              activeThumbColor: appBgBottom,
                              activeTrackColor: appText,
                              inactiveTrackColor: appField,
                              onChanged: (val) => _save(
                                  _settings.copyWith(invertTilt: val)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const AppSectionHeader(title: 'Sound & Haptics'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appField,
                                  border:
                                      Border.all(color: appLine, width: 0.8),
                                ),
                                child: const Icon(Icons.volume_up_rounded,
                                    color: appText, size: 19),
                              ),
                              title: Text(
                                'Sound Effects',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appText),
                              ),
                              subtitle: Text(
                                'Audio cues for correct, pass, and timer countdown',
                                style: appFont(12, color: appTextDim),
                              ),
                              value: _settings.soundEnabled,
                              activeThumbColor: appBgBottom,
                              activeTrackColor: appText,
                              inactiveTrackColor: appField,
                              onChanged: (val) =>
                                  _save(_settings.copyWith(soundEnabled: val)),
                            ),
                            const Divider(
                              height: 1,
                              color: appLine,
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appField,
                                  border:
                                      Border.all(color: appLine, width: 0.8),
                                ),
                                child: const Icon(Icons.vibration_rounded,
                                    color: appText, size: 19),
                              ),
                              title: Text(
                                'Haptic Vibration',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appText),
                              ),
                              subtitle: Text(
                                'Tactile vibration on correct nodding & pass tilt',
                                style: appFont(12, color: appTextDim),
                              ),
                              value: _settings.vibrationEnabled,
                              activeThumbColor: appBgBottom,
                              activeTrackColor: appText,
                              inactiveTrackColor: appField,
                              onChanged: (val) => _save(
                                  _settings.copyWith(vibrationEnabled: val)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const AppSectionHeader(title: 'Data & Reset'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appField,
                                  border:
                                      Border.all(color: appLine, width: 0.8),
                                ),
                                child: const Icon(Icons.history_rounded,
                                    color: appText, size: 19),
                              ),
                              title: Text(
                                'Clear Round History',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appText),
                              ),
                              subtitle: Text(
                                '${_storage.roundHistory.length} saved round records',
                                style: appFont(12, color: appTextDim),
                              ),
                              trailing: GestureDetector(
                                onTap: _storage.roundHistory.isEmpty
                                    ? null
                                    : () => _confirmClearHistory(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _storage.roundHistory.isEmpty
                                        ? Colors.transparent
                                        : appTile,
                                    borderRadius:
                                        BorderRadius.circular(appRadius),
                                    border: Border.all(
                                      color: _storage.roundHistory.isEmpty
                                          ? appLine
                                          : appTextDim,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'CLEAR',
                                    style: appFont(
                                      11,
                                      weight: FontWeight.w600,
                                      spacing: 0.5,
                                      color: _storage.roundHistory.isEmpty
                                          ? appTextDim
                                          : appText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              color: appLine,
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  color: appPass.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: appPass.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Icon(Icons.delete_forever_rounded,
                                    color: appPass, size: 19),
                              ),
                              title: Text(
                                'Reset All Data & Stats',
                                style: appFont(15,
                                    weight: FontWeight.w600, color: appPass),
                              ),
                              subtitle: Text(
                                'Deletes custom decks, favorites, and reset settings to default',
                                style: appFont(12, color: appTextDim),
                              ),
                              trailing: GestureDetector(
                                onTap: () => _confirmResetAllData(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: appPass.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(appRadius),
                                    border: Border.all(
                                      color: appPass,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'RESET',
                                    style: appFont(
                                      11,
                                      weight: FontWeight.w600,
                                      spacing: 0.5,
                                      color: appPass,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Heads Guess',
                              style: appFont(14,
                                  weight: FontWeight.w600, color: appTextDim),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Minimalist Edition',
                              style: appFont(12, color: appTextDim),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationTile() {
    const durations = [30, 60, 90];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(appRadius),
              color: appField,
              border: Border.all(color: appLine, width: 0.8),
            ),
            child: const Icon(Icons.timer_outlined, color: appText, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Duration',
                  style: appFont(15, weight: FontWeight.w600, color: appText),
                ),
                Text(
                  'Initial timer for round starts',
                  style: appFont(12, color: appTextDim),
                ),
              ],
            ),
          ),
          Row(
            children: durations.map((d) {
              final selected = d == _settings.defaultTimerDuration;
              return GestureDetector(
                onTap: () {
                  _save(_settings.copyWith(defaultTimerDuration: d));
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? appText : appField,
                    borderRadius: BorderRadius.circular(appRadius),
                    border: selected
                        ? null
                        : Border.all(color: appLine, width: 0.8),
                  ),
                  child: Text(
                    '${d}s',
                    style: appFont(
                      13,
                      weight: FontWeight.w600,
                      color: selected ? appBgBottom : appTextDim,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        title: Text(
          'Clear History?',
          style: appFont(18, weight: FontWeight.w600, color: appText),
        ),
        content: Text(
          'All your previous round records will be removed.',
          style: appFont(14, color: appTextDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: appFont(13, color: appTextDim, spacing: 0.5)),
          ),
          GestureDetector(
            onTap: () {
              _storage.clearHistory();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: appPass.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(appRadius),
                border: Border.all(color: appPass, width: 0.8),
              ),
              child: Text(
                'CLEAR',
                style: appFont(13,
                    weight: FontWeight.w600, color: appPass, spacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResetAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        title: Text(
          'Reset All Data & Stats?',
          style: appFont(18, weight: FontWeight.w600, color: appPass),
        ),
        content: Text(
          'This will permanently delete all custom decks, favorites, and round history, and restore default settings.',
          style: appFont(14, color: appTextDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: appFont(13, color: appTextDim, spacing: 0.5)),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              await _storage.resetAllCustomData();
              setState(() {
                _settings = _storage.settings;
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All data has been reset to defaults.',
                      style: appFont(14, color: appText)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appRadius),
                    side: const BorderSide(color: appLine, width: 0.8),
                  ),
                  backgroundColor: appBgMid,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: appPass.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(appRadius),
                border: Border.all(color: appPass, width: 0.8),
              ),
              child: Text(
                'RESET EVERYTHING',
                style: appFont(13,
                    weight: FontWeight.w600, color: appPass, spacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
