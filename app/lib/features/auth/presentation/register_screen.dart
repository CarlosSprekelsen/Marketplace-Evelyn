import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/user.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final RegExp _uaePhoneRegex = RegExp(r'^\+971\d{9}$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  UserRole _selectedRole = UserRole.client;
  String? _selectedDistrictId;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final districtsAsync = ref.watch(districtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Crear cuenta',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa un email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Minimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      border: OutlineInputBorder(),
                      hintText: '+971501234567',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu telefono';
                      }
                      if (!_uaePhoneRegex.hasMatch(value.trim())) {
                        return 'Formato inválido. Usa +971XXXXXXXXX';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                        value: UserRole.client,
                        label: Text('CLIENT'),
                      ),
                      ButtonSegment(
                        value: UserRole.provider,
                        label: Text('PROVIDER'),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (roles) {
                      setState(() {
                        _selectedRole = roles.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  districtsAsync.when(
                    data: (districts) {
                      if (districts.isEmpty) {
                        return const Text(
                          'No hay distritos disponibles',
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      _selectedDistrictId ??= districts.first.id;
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedDistrictId,
                        decoration: const InputDecoration(
                          labelText: 'Distrito',
                          border: OutlineInputBorder(),
                        ),
                        items: districts
                            .map(
                              (district) => DropdownMenuItem(
                                value: district.id,
                                child: Text(district.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrictId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selecciona un distrito';
                          }
                          return null;
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, __) => Column(
                      children: [
                        const Text(
                          'No se pudo cargar distritos. Verifica backend y red.',
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(districtsProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: authState.isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Acepto los '),
                        TextButton(
                          onPressed: () => context.push('/legal/terms'),
                          child: const Text('Términos'),
                        ),
                        const Text(' y la '),
                        TextButton(
                          onPressed: () => context.push('/legal/privacy'),
                          child: const Text('Política de Privacidad'),
                        ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 4),
                  if (authState.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        authState.message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: authState.isLoading || !_acceptedTerms
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }

                            final districtId = _selectedDistrictId;
                            if (districtId == null || districtId.isEmpty) {
                              return;
                            }

                            await authNotifier.register(
                              email: _emailController.text.trim(),
                              password: _passwordController.text,
                              fullName: _nameController.text.trim(),
                              phone: _phoneController.text.trim(),
                              role: _selectedRole,
                              districtId: districtId,
                            );
                          },
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrarse'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: authState.isLoading ? null : () => context.go('/login'),
                    child: const Text('Ya tengo cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
