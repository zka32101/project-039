import 'package:flutter/material.dart';

/// 二度押し防止付きの主要ボタン（設計書Step5.5チェック項目）。
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isProcessing = false;

  Future<void> _handlePressed() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _handlePressed,
      child: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(widget.label),
    );
  }
}
