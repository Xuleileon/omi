import 'package:flutter/material.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/utils/l10n_extensions.dart';

class RecordingSettingsPage extends StatefulWidget {
  const RecordingSettingsPage({super.key});

  @override
  State<RecordingSettingsPage> createState() => _RecordingSettingsPageState();
}

class _RecordingSettingsPageState extends State<RecordingSettingsPage> {
  late bool _continuousRecordingEnabled;
  late bool _autoStartRecording;
  late int _batteryThreshold;

  @override
  void initState() {
    super.initState();
    _continuousRecordingEnabled = SharedPreferencesUtil().continuousRecordingEnabled;
    _autoStartRecording = SharedPreferencesUtil().autoStartRecording;
    _batteryThreshold = SharedPreferencesUtil().recordingBatteryThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Recording Settings'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _buildSection(
              title: '24-Hour Recording',
              children: [
                _buildSwitchTile(
                  title: 'Enable Continuous Recording',
                  subtitle: 'Record audio continuously using phone microphone',
                  value: _continuousRecordingEnabled,
                  onChanged: (value) {
                    setState(() {
                      _continuousRecordingEnabled = value;
                      SharedPreferencesUtil().continuousRecordingEnabled = value;
                      // If enabling, also enable auto-start by default
                      if (value && !_autoStartRecording) {
                        _autoStartRecording = true;
                        SharedPreferencesUtil().autoStartRecording = true;
                      }
                    });
                  },
                ),
                if (_continuousRecordingEnabled) ...[
                  const Divider(height: 1, color: Color(0xFF3C3C43)),
                  _buildSwitchTile(
                    title: 'Auto-Start on App Launch',
                    subtitle: 'Automatically start recording when app opens',
                    value: _autoStartRecording,
                    onChanged: (value) {
                      setState(() {
                        _autoStartRecording = value;
                        SharedPreferencesUtil().autoStartRecording = value;
                      });
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF3C3C43)),
                  _buildBatteryThresholdTile(),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryThresholdTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Battery Threshold',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                '$_batteryThreshold%',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pause recording when battery falls below this level',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.deepPurple,
              inactiveTrackColor: const Color(0xFF3C3C43),
              thumbColor: Colors.white,
              overlayColor: Colors.deepPurple.withOpacity(0.2),
            ),
            child: Slider(
              value: _batteryThreshold.toDouble(),
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (value) {
                setState(() {
                  _batteryThreshold = value.toInt();
                  SharedPreferencesUtil().recordingBatteryThreshold = _batteryThreshold;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'How it works',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Recording uses your phone\'s microphone\n'
            '• Audio is transcribed in real-time via WebSocket\n'
            '• A foreground service keeps recording active\n'
            '• Recording pauses when battery is low\n'
            '• Works without Omi hardware device',
            style: TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
