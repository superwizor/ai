import 'package:flutter/material.dart';

class EuphireTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const EuphireTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        // Tu można w przyszłości rozszerzyć o specyficzne stylowanie dla Euphire
        // zgodnie z systemem designu np. filled: true, fillColor: Frost White itd.
      ),
    );
  }
}
