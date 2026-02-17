import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_notifier.dart';
import '../state/client_requests_providers.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key});

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  String? _districtId;
  int _hours = 1;
  int _dayOfWeek = 1; // 1=Mon
  String _timeOfDay = '10:00';
  bool _submitting = false;
  String? _message;

  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud Recurrente')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Programa limpieza semanal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // District dropdown
                  districtsAsync.when(
                    data: (districts) {
                      _districtId ??= districts.isNotEmpty ? districts.first.id : null;
                      return DropdownButtonFormField<String>(
                        initialValue: _districtId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Distrito',
                        ),
                        items: districts
                            .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                            .toList(growable: false),
                        onChanged: (v) => setState(() => _districtId = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un distrito' : null,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error cargando distritos: ${mapDioErrorToMessage(e)}',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 12),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Dirección detallada',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa la dirección';
                      if (v.length > 500) return 'Máximo 500 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Hours
                  DropdownButtonFormField<int>(
                    initialValue: _hours,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Horas',
                    ),
                    items: List.generate(8, (i) => i + 1)
                        .map((h) => DropdownMenuItem(value: h, child: Text('$h hora(s)')))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _hours = v ?? 1),
                  ),
                  const SizedBox(height: 16),

                  // Day of week
                  const Text('Día de la semana', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      return ChoiceChip(
                        label: Text(_dayLabels[i]),
                        selected: _dayOfWeek == day,
                        onSelected: (_) => setState(() => _dayOfWeek = day),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Time slot
                  const Text('Hora', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _pickTime,
                    child: Text('Hora: $_timeOfDay'),
                  ),
                  const SizedBox(height: 20),

                  // Preview
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Cada ${_dayLabels[_dayOfWeek - 1]} a las $_timeOfDay, $_hours hora(s)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!, style: const TextStyle(color: Colors.red)),
                    ),

                  FilledButton(
                    onPressed: _submitting ? null : _onSubmit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear Solicitud Recurrente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final slots = <String>[];
    for (int h = 6; h <= 21; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      if (h < 21) {
        slots.add('${h.toString().padLeft(2, '0')}:30');
      }
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Selecciona hora'),
        children: slots
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(s, style: const TextStyle(fontSize: 16)),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      setState(() => _timeOfDay = selected);
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_districtId == null || _districtId!.isEmpty) {
      setState(() => _message = 'Selecciona un distrito');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      await repo.createRecurringRequest(
        districtId: _districtId!,
        addressDetail: _addressController.text.trim(),
        hoursRequested: _hours,
        dayOfWeek: _dayOfWeek,
        timeOfDay: _timeOfDay,
      );
      if (!mounted) return;
      context.go('/client/recurring');
    } catch (error) {
      setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
