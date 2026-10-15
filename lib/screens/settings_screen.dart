import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/luxury_theme.dart';

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
    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  LuxuryRoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style:
                        luxuryFont(26, weight: FontWeight.w300, spacing: 0.5),
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
                  const LuxurySectionHeader(title: 'Gameplay Defaults'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: luxuryPanel(radius: 18),
                    child: Column(
                      children: [
                        _buildDurationTile(),
                        Divider(
                          height: 1,
                          color: kGold.withValues(alpha: 0.12),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSelectedFill,
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.touch_app_rounded,
                                color: kGold, size: 20),
                          ),
                          title: Text(
                            'Always Show Action Buttons',
                            style: luxuryFont(15,
                                weight: FontWeight.w400, color: kText),
                          ),
                          subtitle: Text(
                            'Show on-screen Pass & Correct buttons alongside tilt controls',
                            style: luxuryFont(12, color: kTextDim),
                          ),
                          value: _settings.showManualButtons,
                          activeThumbColor: kGold,
                          activeTrackColor: kGold.withValues(alpha: 0.35),
                          onChanged: (val) =>
                              _save(_settings.copyWith(showManualButtons: val)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const LuxurySectionHeader(title: 'Sound & Haptics'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: luxuryPanel(radius: 18),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSelectedFill,
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.volume_up_rounded,
                                color: kGold, size: 20),
                          ),
                          title: Text(
                            'Sound Effects',
                            style: luxuryFont(15,
                                weight: FontWeight.w400, color: kText),
                          ),
                          subtitle: Text(
                            'Audio cues for correct, pass, and timer countdown',
                            style: luxuryFont(12, color: kTextDim),
                          ),
                          value: _settings.soundEnabled,
                          activeThumbColor: kGold,
                          activeTrackColor: kGold.withValues(alpha: 0.35),
                          onChanged: (val) =>
                              _save(_settings.copyWith(soundEnabled: val)),
                        ),
                        Divider(
                          height: 1,
                          color: kGold.withValues(alpha: 0.12),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSelectedFill,
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.vibration_rounded,
                                color: kGold, size: 20),
                          ),
                          title: Text(
                            'Haptic Vibration',
                            style: luxuryFont(15,
                                weight: FontWeight.w400, color: kText),
                          ),
                          subtitle: Text(
                            'Tactile vibration on correct nodding & pass tilt',
                            style: luxuryFont(12, color: kTextDim),
                          ),
                          value: _settings.vibrationEnabled,
                          activeThumbColor: kGold,
                          activeTrackColor: kGold.withValues(alpha: 0.35),
                          onChanged: (val) =>
                              _save(_settings.copyWith(vibrationEnabled: val)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const LuxurySectionHeader(title: 'Data & Reset'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: luxuryPanel(radius: 18),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSelectedFill,
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.history_rounded,
                                color: kGold, size: 20),
                          ),
                          title: Text(
                            'Clear Round History',
                            style: luxuryFont(15,
                                weight: FontWeight.w400, color: kText),
                          ),
                          subtitle: Text(
                            '${_storage.roundHistory.length} saved round records',
                            style: luxuryFont(12, color: kTextDim),
                          ),
                          trailing: GestureDetector(
                            onTap: _storage.roundHistory.isEmpty
                                ? null
                                : () => _confirmClearHistory(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _storage.roundHistory.isEmpty
                                    ? Colors.transparent
                                    : kPassAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _storage.roundHistory.isEmpty
                                      ? Colors.white12
                                      : kPassAmber.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'CLEAR',
                                style: luxuryFont(
                                  11,
                                  weight: FontWeight.w500,
                                  spacing: 1.0,
                                  color: _storage.roundHistory.isEmpty
                                      ? kTextDim
                                      : kPassAmber,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: kGold.withValues(alpha: 0.12),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPassAmber.withValues(alpha: 0.15),
                              border: Border.all(
                                color: kPassAmber.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.delete_forever_rounded,
                                color: kPassAmber, size: 20),
                          ),
                          title: Text(
                            'Reset All Data & Stats',
                            style: luxuryFont(15,
                                weight: FontWeight.w400, color: kPassAmber),
                          ),
                          subtitle: Text(
                            'Deletes custom decks, favorites, and reset settings to default',
                            style: luxuryFont(12, color: kTextDim),
                          ),
                          trailing: GestureDetector(
                            onTap: () => _confirmResetAllData(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: kPassAmber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kPassAmber,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'RESET',
                                style: luxuryFont(
                                  11,
                                  weight: FontWeight.w500,
                                  spacing: 1.0,
                                  color: kPassAmber,
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
                          'Heads Guess Party Game',
                          style: luxuryFont(14,
                              weight: FontWeight.w400,
                              color: kGold.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 2.0 • Luxury Edition',
                          style: luxuryFont(11, color: kTextDim),
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
    );
  }

  Widget _buildDurationTile() {
    const durations = [30, 60, 90];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSelectedFill,
              border: Border.all(
                color: kGold.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: const Icon(Icons.timer_outlined, color: kGold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Duration',
                  style: luxuryFont(15, weight: FontWeight.w400, color: kText),
                ),
                Text(
                  'Initial timer for round starts',
                  style: luxuryFont(12, color: kTextDim),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: luxuryPanel(radius: 12),
            child: Row(
              children: durations.map((d) {
                final selected = d == _settings.defaultTimerDuration;
                return GestureDetector(
                  onTap: () {
                    _save(_settings.copyWith(defaultTimerDuration: d));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? kSelectedFill : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected
                            ? kGold.withValues(alpha: 0.8)
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${d}s',
                      style: luxuryFont(
                        12,
                        weight: FontWeight.w500,
                        color: selected ? kGold : kTextDim,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kPassAmber.withValues(alpha: 0.5), width: 1),
        ),
        title: Text(
          'Clear History?',
          style: luxuryFont(18, weight: FontWeight.w500, color: kPassAmber),
        ),
        content: Text(
          'All your previous round records will be removed.',
          style: luxuryFont(14, color: kTextDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: luxuryFont(13, color: kTextDim, spacing: 1)),
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
                color: kPassAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPassAmber, width: 1),
              ),
              child: Text(
                'CLEAR',
                style: luxuryFont(13,
                    weight: FontWeight.w500, color: kPassAmber, spacing: 1),
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
        backgroundColor: kPanelTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kPassAmber.withValues(alpha: 0.6), width: 1),
        ),
        title: Text(
          'Reset All Data & Stats?',
          style: luxuryFont(18, weight: FontWeight.w500, color: kPassAmber),
        ),
        content: Text(
          'This will permanently delete all custom decks, favorites, and round history, and restore default settings.',
          style: luxuryFont(14, color: kTextDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: luxuryFont(13, color: kTextDim, spacing: 1)),
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
                      style: luxuryFont(14, color: kText)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: kGold.withValues(alpha: 0.4), width: 0.8),
                  ),
                  backgroundColor: kPanelTop,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPassAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPassAmber, width: 1),
              ),
              child: Text(
                'RESET EVERYTHING',
                style: luxuryFont(13,
                    weight: FontWeight.w500, color: kPassAmber, spacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
