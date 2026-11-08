import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  UserRole _selectedRole = UserRole.produtor;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _toggleMode(bool registerMode) {
    if (_isRegisterMode == registerMode) return;

    setState(() {
      _isRegisterMode = registerMode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();

    bool success;

    if (_isRegisterMode) {
      success = await auth.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: _selectedRole,
      );
    } else {
      success = await auth.login(
        _email.text.trim(),
        _password.text,
        expectedRole: _selectedRole,
      );
    }

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error ??
                (_isRegisterMode
                    ? 'Não foi possível criar sua conta.'
                    : 'Falha no login. Verifique seus dados.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    if (!validEmail) {
      return 'Informe um e-mail válido.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha.';
    }

    if (_isRegisterMode && value.length < 12) {
      return 'A senha deve ter pelo menos 12 caracteres.';
    }

    if (_isRegisterMode && value.length > 72) {
      return 'A senha deve ter no máximo 72 caracteres.';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha.';
    }

    if (value != _password.text) {
      return 'As senhas não coincidem.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.agriculture,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'AgroMarkt',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _isRegisterMode
                            ? 'Crie sua conta para participar do AgroMarkt.'
                            : 'Entre para comparar produtos e ofertas agrícolas.',
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Alternância entre login e cadastro.
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Login'),
                            icon: Icon(Icons.login),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Criar conta'),
                            icon: Icon(Icons.person_add_alt_1),
                          ),
                        ],
                        selected: {_isRegisterMode},
                        onSelectionChanged: auth.loading
                            ? null
                            : (selection) {
                                _toggleMode(selection.first);
                              },
                      ),

                      const SizedBox(height: 24),

                      // Seleção de perfil.
                      const Text(
                        'Perfil da conta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.agriculture),
                              label: const Text('Produtor'),
                              selected: _selectedRole == UserRole.produtor,
                              onSelected: auth.loading
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedRole = UserRole.produtor;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              avatar: const Icon(Icons.store),
                              label: const Text('Fornecedor'),
                              selected: _selectedRole == UserRole.fornecedor,
                              onSelected: auth.loading
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedRole = UserRole.fornecedor;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Nome: somente no cadastro.
                      if (_isRegisterMode) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !auth.loading,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome completo',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (!_isRegisterMode) return null;

                            final name = value?.trim() ?? '';

                            if (name.length < 2 || name.length > 120) {
                              return 'Informe um nome entre 2 e 120 caracteres.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // E-mail.
                      TextFormField(
                        controller: _email,
                        enabled: !auth.loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateEmail,
                      ),

                      const SizedBox(height: 16),

                      // Senha.
                      TextFormField(
                        controller: _password,
                        enabled: !auth.loading,
                        obscureText: _obscurePassword,
                        textInputAction: _isRegisterMode
                            ? TextInputAction.next
                            : TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: _validatePassword,
                        onFieldSubmitted: (_) {
                          if (!_isRegisterMode) _submit();
                        },
                      ),

                      // Confirmação: somente no cadastro.
                      if (_isRegisterMode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPassword,
                          enabled: !auth.loading,
                          obscureText: _obscureConfirmation,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Confirmar senha',
                            prefixIcon: const Icon(Icons.lock_reset),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmation
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmation = !_obscureConfirmation;
                                });
                              },
                            ),
                          ),
                          validator: _validateConfirmation,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Botão principal.
                      FilledButton(
                        onPressed: auth.loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: auth.loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isRegisterMode
                                      ? 'Criar minha conta'
                                      : 'Entrar',
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _isRegisterMode
                            ? 'Ao criar sua conta, você poderá acessar os recursos do perfil selecionado.'
                            : 'Acesse sua conta para continuar.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
