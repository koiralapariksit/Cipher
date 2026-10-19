import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../theme/deck_colors.dart';

/// Settings screen for configuring sound, vibration, round duration,
/// manual button visibility, and resetting data — 100% Neo-Brutalist.
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
        backgroundColor: kBlue,
        body: SafeArea(
          child: Column(
            children: [
              // ── Custom Neo-Brutalist Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: kInk,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        child: Text(
                          '✕ BACK',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kCream,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Transform.rotate(
                      angle: -2 * math.pi / 180,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Settings',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 36,
                                color: kCream,
                                height: 0.95,
                              ),
                            ),
                            TextSpan(
                              text: '!',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 36,
                                color: kYellow,
                                height: 0.95,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Settings List ──
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildSectionHeader('GAMEPLAY DEFAULTS', kYellow),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: kAsymmetricRadius,
                        border: Border.all(color: kInk, width: 3.0),
                        boxShadow: kCardShadow,
                      ),
                      child: Column(
                        children: [
                          _buildDurationTile(),
                          const Divider(height: 2, thickness: 2, color: kInk),
                          _buildSwitchTile(
                            title: 'Always Show Action Buttons',
                            subtitle:
                                'Show on-screen Pass & Correct buttons alongside tilt controls',
                            icon: Icons.touch_app_rounded,
                            iconColor: kLime,
                            value: _settings.showManualButtons,
                            onChanged: (val) => _save(
                                _settings.copyWith(showManualButtons: val)),
                          ),
                          const Divider(height: 2, thickness: 2, color: kInk),
                          _buildSwitchTile(
                            title: 'Invert Tilt Controls',
                            subtitle: _settings.invertTilt
                                ? 'Active (Default): Tilt UP = Pass, Tilt DOWN = Correct'
                                : 'Standard: Tilt DOWN = Pass, Tilt UP = Correct',
                            icon: Icons.swap_vert_rounded,
                            iconColor: kOrange,
                            value: _settings.invertTilt,
                            onChanged: (val) =>
                                _save(_settings.copyWith(invertTilt: val)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('SOUND & HAPTICS', kLime),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: kAsymmetricRadius,
                        border: Border.all(color: kInk, width: 3.0),
                        boxShadow: kCardShadow,
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: 'Sound Effects',
                            subtitle:
                                'Audio cues for correct, pass, and timer countdown',
                            icon: Icons.volume_up_rounded,
                            iconColor: kYellow,
                            value: _settings.soundEnabled,
                            onChanged: (val) =>
                                _save(_settings.copyWith(soundEnabled: val)),
                          ),
                          const Divider(height: 2, thickness: 2, color: kInk),
                          _buildSwitchTile(
                            title: 'Haptic Vibration',
                            subtitle:
                                'Tactile vibration on correct nodding & pass tilt',
                            icon: Icons.vibration_rounded,
                            iconColor: kLime,
                            value: _settings.vibrationEnabled,
                            onChanged: (val) =>
                                _save(_settings.copyWith(vibrationEnabled: val)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('DATA & RESET', kPink),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: kAsymmetricRadius,
                        border: Border.all(color: kInk, width: 3.0),
                        boxShadow: kCardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: kYellow,
                                border: Border.all(color: kInk, width: 2.0),
                              ),
                              child: const Icon(Icons.history_rounded,
                                  color: kInk, size: 22),
                            ),
                            title: Text(
                              'Clear Round History',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                              ),
                            ),
                            subtitle: Text(
                              '${_storage.roundHistory.length} saved round records',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kInkDim,
                              ),
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
                                      ? kCream
                                      : kOrange,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 2.0),
                                  boxShadow: _storage.roundHistory.isEmpty
                                      ? null
                                      : kSmallShadow,
                                ),
                                child: Text(
                                  'CLEAR',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 11,
                                    color: _storage.roundHistory.isEmpty
                                        ? kInkDim
                                        : kInk,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 2, thickness: 2, color: kInk),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: kPink,
                                border: Border.all(color: kInk, width: 2.0),
                              ),
                              child: const Icon(Icons.delete_forever_rounded,
                                  color: kInk, size: 22),
                            ),
                            title: Text(
                              'Reset All Data & Stats',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                              ),
                            ),
                            subtitle: Text(
                              'Deletes custom decks, favorites, and resets settings',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kInkDim,
                              ),
                            ),
                            trailing: GestureDetector(
                              onTap: () => _confirmResetAllData(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: kPink,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 2.0),
                                  boxShadow: kSmallShadow,
                                ),
                                child: Text(
                                  'RESET',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 11,
                                    color: kInk,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: kCream,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        child: Text(
                          'Cipher • Forehead Charades',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 12,
                            color: kInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color badgeColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kInk, width: 2.0),
          boxShadow: kSmallShadow,
        ),
        child: Text(
          title,
          style: GoogleFonts.bowlbyOne(
            fontSize: 12,
            color: kInk,
            letterSpacing: 0.5,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: kYellow,
              border: Border.all(color: kInk, width: 2.0),
            ),
            child: const Icon(Icons.timer_outlined, color: kInk, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Duration',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                Text(
                  'Initial timer for round starts',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kInkDim,
                  ),
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
                    color: selected ? kYellow : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 2.0),
                    boxShadow: selected ? kSmallShadow : null,
                  ),
                  child: Text(
                    '${d}s',
                    style: GoogleFonts.bowlbyOne(
                      fontSize: 12,
                      color: kInk,
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: iconColor,
          border: Border.all(color: kInk, width: 2.0),
        ),
        child: Icon(icon, color: kInk, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kInk,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kInkDim,
        ),
      ),
      value: value,
      activeThumbColor: kInk,
      activeTrackColor: kLime,
      inactiveThumbColor: kInkDim,
      inactiveTrackColor: Colors.white,
      trackOutlineColor: WidgetStateProperty.all(kInk),
      onChanged: onChanged,
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(
          borderRadius: kAsymmetricRadius,
          side: const BorderSide(color: kCream, width: 3.5),
        ),
        title: Text(
          'Clear History?',
          style: GoogleFonts.bowlbyOne(fontSize: 22, color: kYellow),
        ),
        content: Text(
          'All your previous round records will be removed permanently.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kCream,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.bowlbyOne(fontSize: 13, color: kCream),
            ),
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
                color: kOrange,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kInk, width: 2.0),
                boxShadow: kSmallShadow,
              ),
              child: Text(
                'CLEAR',
                style: GoogleFonts.bowlbyOne(fontSize: 13, color: kInk),
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
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(
          borderRadius: kAsymmetricRadius,
          side: const BorderSide(color: kCream, width: 3.5),
        ),
        title: Text(
          'Reset All Data?',
          style: GoogleFonts.bowlbyOne(fontSize: 22, color: kPink),
        ),
        content: Text(
          'This will permanently delete all custom decks, favorites, and round history, and restore default settings.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kCream,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.bowlbyOne(fontSize: 13, color: kCream),
            ),
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
                  content: Text(
                    'All data has been reset to defaults.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: const BorderSide(color: kInk, width: 2.0),
                  ),
                  backgroundColor: kYellow,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPink,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kInk, width: 2.0),
                boxShadow: kSmallShadow,
              ),
              child: Text(
                'RESET EVERYTHING',
                style: GoogleFonts.bowlbyOne(fontSize: 13, color: kInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
