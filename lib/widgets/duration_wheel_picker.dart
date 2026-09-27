import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../logic/time_format.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Wheels to dial in a time like an alarm clock — minutes, seconds, then
/// one wheel per digit of the milliseconds (tenths, hundredths,
/// thousandths), with an hours wheel in front when [showHours]. Every wheel
/// loops, and [onChanged] fires with the total in milliseconds on each
/// turn.
class DurationWheelPicker extends StatefulWidget {
  final int initialMs;
  final bool showHours;
  final ValueChanged<int> onChanged;
  const DurationWheelPicker({super.key, required this.initialMs, required this.showHours, required this.onChanged});

  @override
  State<DurationWheelPicker> createState() => _DurationWheelPickerState();
}

class _DurationWheelPickerState extends State<DurationWheelPicker> {
  late int _h, _m, _s, _d1, _d2, _d3;
  final _controllers = <String, FixedExtentScrollController>{};

  @override
  void initState() {
    super.initState();
    var rest = widget.initialMs.clamp(0, 100 * 3600 * 1000 - 1);
    final millis = rest % 1000;
    rest ~/= 1000;
    _s = rest % 60;
    rest ~/= 60;
    _m = rest % 60;
    _h = rest ~/ 60;
    _d1 = millis ~/ 100;
    _d2 = millis ~/ 10 % 10;
    _d3 = millis % 10;
    for (final (k, v) in [('h', _h), ('m', _m), ('s', _s), ('d1', _d1), ('d2', _d2), ('d3', _d3)]) {
      _controllers[k] = FixedExtentScrollController(initialItem: v);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => (((widget.showHours ? _h : 0) * 60 + _m) * 60 + _s) * 1000 + _d1 * 100 + _d2 * 10 + _d3;

  void _set(void Function() change) {
    setState(change);
    widget.onChanged(_total);
  }

  Widget _wheel(String key, int count, ValueChanged<int> onSelected, {double width = 56, bool pad = true}) {
    return SizedBox(
      width: width,
      child: CupertinoPicker(
        key: ValueKey('wheel-$key'),
        scrollController: _controllers[key],
        itemExtent: 44,
        looping: true,
        squeeze: 1.1,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) => _set(() => onSelected(i % count)),
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                pad ? i.toString().padLeft(2, '0') : '$i',
                style: dispFont(size: 28, weight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }

  static const _wheelHeight = 200.0;

  /// A wheel with its unit label underneath, so both always line up.
  Widget _column(Widget wheel, String unit) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: _wheelHeight, child: wheel),
      const SizedBox(height: 4),
      Text(
        unit,
        style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4),
      ),
    ],
  );

  Widget _sep(String s) => Padding(
    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 19),
    child: Text(
      s,
      style: dispFont(size: 28, weight: FontWeight.w700, color: AppColors.mut),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const digit = 30.0;
    // Scaled down as a whole (band included) on a screen too narrow for
    // every wheel, rather than overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          // The band the selected values sit in, drawn once across every
          // wheel.
          Positioned(
            left: 0,
            right: 0,
            top: (_wheelHeight - 44) / 2,
            height: 44,
            child: Container(
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showHours) ...[_column(_wheel('h', 100, (v) => _h = v, width: 50, pad: false), 'H'), _sep(':')],
              _column(_wheel('m', 60, (v) => _m = v), 'MIN'),
              _sep(':'),
              _column(_wheel('s', 60, (v) => _s = v), 'S'),
              _sep('.'),
              _column(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _wheel('d1', 10, (v) => _d1 = v, width: digit, pad: false),
                    _wheel('d2', 10, (v) => _d2 = v, width: digit, pad: false),
                    _wheel('d3', 10, (v) => _d3 = v, width: digit, pad: false),
                  ],
                ),
                'MS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to dial in `playerName`'s time on [DurationWheelPicker] —
/// starting from [currentMs] when already set, otherwise from [startFromMs]
/// (their record, so reaching a close time takes just a few flicks). A
/// "Saisir au clavier" link swaps the wheels for a text field (see
/// [parseDuration]). Returns the time in milliseconds, or null if closed.
Future<int?> showDurationPickerSheet(BuildContext context, {required String playerName, required int currentMs, int? startFromMs}) {
  final start = currentMs > 0 ? currentMs : (startFromMs ?? 0);
  var value = start;
  var showHours = start >= 3600 * 1000;
  var keyboard = false;
  final ctrl = TextEditingController(text: start > 0 ? formatDuration(start) : '');
  String? error;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        void submit() {
          if (keyboard) {
            final ms = parseDuration(ctrl.text);
            if (ms == null) {
              setState(() => error = 'Format attendu : 1:52.340');
              return;
            }
            Navigator.of(sheetContext).pop(ms);
          } else if (value > 0) {
            Navigator.of(sheetContext).pop(value);
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temps de $playerName',
                    style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 14),
                  if (keyboard) ...[
                    Text(
                      'Minutes:secondes.millièmes — ex. 1:52.340',
                      style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: dispFont(size: 28, weight: FontWeight.w700, color: AppColors.ink),
                      decoration: appFieldDecoration(hintText: '1:52.340'),
                      onChanged: (_) {
                        if (error != null) setState(() => error = null);
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ] else
                    DurationWheelPicker(key: ValueKey(showHours), initialMs: value, showHours: showHours, onChanged: (ms) => setState(() => value = ms)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Pressable(
                          onTap: () => setState(() {
                            if (keyboard) {
                              // Back to the wheels on whatever was typed, if valid.
                              value = parseDuration(ctrl.text) ?? value;
                              showHours = showHours || value >= 3600 * 1000;
                            } else {
                              ctrl.text = value > 0 ? formatDuration(value) : '';
                            }
                            keyboard = !keyboard;
                            error = null;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              keyboard ? 'Utiliser les roues' : 'Saisir au clavier',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!keyboard && !showHours)
                        Pressable(
                          onTap: () => setState(() => showHours = true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '+ Heures',
                              style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Valider', onPressed: !keyboard && value == 0 ? null : submit),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
