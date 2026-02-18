import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/price_quote.dart';
import '../../auth/state/auth_notifier.dart';
import '../addresses/address_picker_widget.dart';
import '../state/client_requests_providers.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key});

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _floorAptController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _districtId;
  String? _selectedAddressId;
  int _hours = 1;
  int _dayOfWeek = 1; // 1=Mon
  String _timeOfDay = '10:00';
  PriceQuote? _quote;
  bool _loadingQuote = false;
  bool _submitting = false;
  String? _message;

  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void dispose() {
    _streetController.dispose();
    _numberController.dispose();
    _floorAptController.dispose();
    _referenceController.dispose();
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
                        onChanged: (v) {
                          setState(() {
                            _districtId = v;
                            _quote = null;
                          });
                          _fetchQuoteIfReady();
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un distrito' : null,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error cargando distritos: ${mapDioErrorToMessage(e)}',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 12),

                  // Address picker + fields
                  AddressPickerWidget(
                    selectedAddressId: _selectedAddressId,
                    onAddressSelected: (addr) {
                      setState(() {
                        _selectedAddressId = addr.id;
                        _districtId = addr.districtId;
                        _streetController.text = addr.addressStreet;
                        _numberController.text = addr.addressNumber;
                        _floorAptController.text = addr.addressFloorApt ?? '';
                        _referenceController.text = addr.addressReference ?? '';
                        _quote = null;
                      });
                      _fetchQuoteIfReady();
                    },
                    onNewAddress: () {
                      setState(() {
                        _selectedAddressId = null;
                        _streetController.clear();
                        _numberController.clear();
                        _floorAptController.clear();
                        _referenceController.clear();
                      });
                    },
                  ),
                  TextFormField(
                    controller: _streetController,
                    readOnly: _selectedAddressId != null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Calle / Avenida',
                    ),
                    validator: (v) {
                      if (_selectedAddressId != null) return null;
                      if (v == null || v.trim().isEmpty) return 'Ingresa la calle o avenida';
                      if (v.length > 200) return 'Máximo 200 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numberController,
                    readOnly: _selectedAddressId != null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nº Casa / Edificio',
                    ),
                    validator: (v) {
                      if (_selectedAddressId != null) return null;
                      if (v == null || v.trim().isEmpty) return 'Ingresa el número';
                      if (v.length > 50) return 'Máximo 50 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _floorAptController,
                    readOnly: _selectedAddressId != null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Piso / Apartamento (opcional)',
                    ),
                    validator: (v) {
                      if (v != null && v.length > 100) return 'Máximo 100 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referenceController,
                    readOnly: _selectedAddressId != null,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Punto de referencia (opcional)',
                      hintText: 'Ej: frente al parque, casa color azul',
                    ),
                    validator: (v) {
                      if (v != null && v.length > 300) return 'Máximo 300 caracteres';
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
                    onChanged: (v) {
                      setState(() {
                        _hours = v ?? 1;
                        _quote = null;
                      });
                      _fetchQuoteIfReady();
                    },
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
                  const SizedBox(height: 12),

                  // Auto pricing
                  if (_loadingQuote)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (_quote != null) ...[
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_quote!.hours} hora${_quote!.hours == 1 ? '' : 's'} x \$${_quote!.pricePerHour.toStringAsFixed(2)}/hora',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Divider(height: 20),
                            Text(
                              'Total por sesión: \$${_quote!.priceTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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

  Future<void> _fetchQuoteIfReady() async {
    final districtId = _districtId;
    if (districtId == null || districtId.isEmpty) return;

    setState(() {
      _loadingQuote = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final quote = await repo.getQuote(districtId: districtId, hours: _hours);
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
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
        addressId: _selectedAddressId,
        addressStreet: _selectedAddressId == null ? _streetController.text.trim() : null,
        addressNumber: _selectedAddressId == null ? _numberController.text.trim() : null,
        addressFloorApt: _selectedAddressId == null && _floorAptController.text.trim().isNotEmpty
            ? _floorAptController.text.trim()
            : null,
        addressReference: _selectedAddressId == null && _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : null,
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
