// lib/widgets/custom_input_field.dart

import 'package:flutter/material.dart';

// 1. Convertido para StatefulWidget para gerenciar o estado de visibilidade
class CustomInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const CustomInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  // 2. Variável de estado para controlar se a senha está oculta
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    // A senha sempre começa oculta
    _isObscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        // 3. Adiciona o ícone de "olho" APENAS se for um campo de senha
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(
            // Alterna o ícone baseado no estado de _isObscured
            _isObscured ? Icons.visibility_off : Icons.visibility,
            color: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () {
            // 4. Atualiza o estado ao ser pressionado, fazendo o widget se reconstruir
            setState(() {
              _isObscured = !_isObscured;
            });
          },
        )
            : null, // Se não for senha, não há ícone.
      ),
      // 5. O obscureText agora é controlado pela nossa variável de estado
      obscureText: _isObscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: Theme.of(context).textTheme.bodyLarge,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
    );
  }
}