/// The optional deal-number field on both setup screens (#58): digits only,
/// 1–999999, blank for a random deal.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:honest_solitaire/engine/deal_number.dart';

import '../theme/palette.dart';
import '../widgets/option_panel.dart';
import '../widgets/screen_header.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';

/// What the field holds.
sealed class DealNumberInput {
  const DealNumberInput();
}

/// Nothing typed: a random deal.
class Blank extends DealNumberInput {
  const Blank();
}

class Valid extends DealNumberInput {
  const Valid(this.number);

  final DealNumber number;
}

/// Digits outside 1..999999 (0, 000, 1000000); Deal is disabled.
class Invalid extends DealNumberInput {
  const Invalid();
}

/// Reads the field's text: blank, a valid number, or invalid. Leading
/// zeros are ignored.
DealNumberInput parseDealNumber(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty) return const Blank();
  final value = int.tryParse(digits);
  if (value == null || value < DealNumber.min || value > DealNumber.max) {
    return const Invalid();
  }
  return Valid(DealNumber(value));
}

const dealNumberError = 'Enter 1 to ${DealNumber.max}';
const dealNumberErrorColor = Palette.amber;

/// Keeps ASCII digits only (typed or pasted), capped at seven.
class _DigitsOnly extends TextInputFormatter {
  const _DigitsOnly();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length > 7) digits = digits.substring(0, 7);
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class DealNumberField extends StatefulWidget {
  const DealNumberField({
    super.key,
    required this.accent,
    required this.scale,
    required this.onChanged,
  });

  final SetupAccent accent;
  final double scale;
  final ValueChanged<DealNumberInput> onChanged;

  @override
  State<DealNumberField> createState() => _DealNumberFieldState();
}

class _DealNumberFieldState extends State<DealNumberField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  DealNumberInput _input = const Blank();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(() => setState(() {}));
  }

  void _onText() {
    final input = parseDealNumber(_controller.text);
    final wasInvalid = _input is Invalid;
    setState(() => _input = input);
    if (input is Invalid && !wasInvalid) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        dealNumberError,
        TextDirection.ltr,
      );
    }
    widget.onChanged(input);
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final invalid = _input is Invalid;
    final border = invalid
        ? dealNumberErrorColor
        : _focus.hasFocus
        ? widget.accent.border
        : const Color(0x4DFFFFFF);
    return Panel(
      scale: s,
      color: const Color(0x0DFFFFFF),
      padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 14 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Deal number',
              style: TextStyle(
                fontSize: 13.5 * s,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Replay a deal by its number — leave blank for a random deal',
            style: TextStyle(
              fontSize: 11 * s,
              height: 1.4,
              color: Palette.textBody,
            ),
          ),
          SizedBox(height: 12 * s),
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 12 * s),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  // TextField needs a Material ancestor; the screens have
                  // none (plain DecoratedBox scaffolds).
                  child: Material(
                    type: MaterialType.transparency,
                    child: Semantics(
                      label: 'Deal number, optional',
                      textField: true,
                      child: TextField(
                        key: const Key('deal-number-field'),
                        controller: _controller,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: const [_DigitsOnly()],
                        style: TextStyle(
                          fontSize: 15 * s,
                          fontFamily: kFontMono,
                          color: Palette.paleText,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Random',
                          hintStyle: TextStyle(
                            fontSize: 15 * s,
                            color: Palette.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  Semantics(
                    button: true,
                    label: 'Clear deal number',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const Key('deal-number-clear'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _clear,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: GlyphIcon(
                            Glyph.close,
                            size: 12 * s,
                            color: Palette.mist,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (invalid) ...[
            SizedBox(height: 8 * s),
            Text(
              dealNumberError,
              key: const Key('deal-number-error'),
              style: TextStyle(
                fontSize: 11 * s,
                height: 1.3,
                color: dealNumberErrorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
