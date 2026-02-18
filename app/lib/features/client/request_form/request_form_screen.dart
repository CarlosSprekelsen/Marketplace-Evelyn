import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/price_quote.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../auth/state/auth_notifier.dart';
import '../addresses/address_picker_widget.dart';
import '../state/client_requests_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({
    super.key,
    this.prefillDistrictId,
    this.prefillAddressStreet,
    this.prefillAddressNumber,
    this.prefillAddressFloorApt,
    this.prefillAddressReference,
    this.prefillHours,
  });

  final String? prefillDistrictId;
  final String? prefillAddressStreet;
  final String? prefillAddressNumber;
  final String? prefillAddressFloorApt;
  final String? prefillAddressReference;
  final int? prefillHours;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _floorAptController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _districtId;
  String? _selectedAddressId;
  int _hours = 1;
  DateTime? _scheduledAt;
  PriceQuote? _quote;
  bool _loadingQuote = false;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.prefillDistrictId != null) {
      _districtId = widget.prefillDistrictId;
    }
    if (widget.prefillAddressStreet != null) {
      _streetController.text = widget.prefillAddressStreet!;
    }
    if (widget.prefillAddressNumber != null) {
      _numberController.text = widget.prefillAddressNumber!;
    }
    if (widget.prefillAddressFloorApt != null) {
      _floorAptController.text = widget.prefillAddressFloorApt!;
    }
    if (widget.prefillAddressReference != null) {
      _referenceController.text = widget.prefillAddressReference!;
    }
    if (widget.prefillHours != null) {
      _hours = widget.prefillHours!;
    }
  }

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
      appBar: AppBar(
        title: const Text('Solicitar Limpieza'),
      ),
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
                  districtsAsync.when(
                    data: (districts) {
                      _districtId ??= districts.isNotEmpty ? districts.first.id : null;
                      final selectedDistrict = districts.where((d) => d.id == _districtId).firstOrNull;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _districtId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Distrito',
                            ),
                            items: districts
                                .map((district) {
                                  return DropdownMenuItem<String>(
                                    value: district.id,
                                    child: Text(district.name),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              setState(() {
                                _districtId = value;
                                _quote = null;
                              });
                              _fetchQuoteIfReady();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Selecciona un distrito';
                              }
                              return null;
                            },
                          ),
                          if (selectedDistrict != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  selectedDistrict.hasActiveProviders
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: selectedDistrict.hasActiveProviders
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    selectedDistrict.hasActiveProviders
                                        ? 'Hay proveedores activos en este distrito'
                                        : 'No hay proveedores activos — tu solicitud podría expirar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selectedDistrict.hasActiveProviders
                                          ? Colors.green.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text(
                      'No se pudo cargar distritos: ${mapDioErrorToMessage(error)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    validator: (value) {
                      if (_selectedAddressId != null) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la calle o avenida';
                      }
                      if (value.length > 200) {
                        return 'Máximo 200 caracteres';
                      }
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
                    validator: (value) {
                      if (_selectedAddressId != null) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el número';
                      }
                      if (value.length > 50) {
                        return 'Máximo 50 caracteres';
                      }
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
                    validator: (value) {
                      if (value != null && value.length > 100) {
                        return 'Máximo 100 caracteres';
                      }
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
                    validator: (value) {
                      if (value != null && value.length > 300) {
                        return 'Máximo 300 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _hours,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Horas',
                    ),
                    items: List<int>.generate(8, (index) => index + 1)
                        .map(
                          (hours) => DropdownMenuItem<int>(
                            value: hours,
                            child: Text('$hours hora(s)'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _hours = value ?? 1;
                        _quote = null;
                      });
                      _fetchQuoteIfReady();
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _pickDateTime,
                    child: Text(
                      _scheduledAt == null
                          ? 'Seleccionar fecha y hora'
                          : 'Fecha: ${formatDateTime(_scheduledAt!)}',
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              _quote!.districtName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_quote!.hours} hora${_quote!.hours == 1 ? '' : 's'} x \$${_quote!.pricePerHour.toStringAsFixed(2)}/hora',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Divider(height: 20),
                            Text(
                              'Total: \$${_quote!.priceTotal.toStringAsFixed(2)}',
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
                    const SizedBox(height: 16),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: _submitting ? null : _onConfirmPressed,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar Solicitud'),
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

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final selectedMinute = await _pickSlotMinute();
    if (selectedMinute == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        selectedMinute ~/ 60,
        selectedMinute % 60,
      );
    });
  }

  Future<int?> _pickSlotMinute() async {
    final slots = <TimeOfDay>[];
    for (int h = 6; h <= 21; h++) {
      slots.add(TimeOfDay(hour: h, minute: 0));
      if (h < 21) {
        slots.add(TimeOfDay(hour: h, minute: 30));
      }
    }

    return showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Selecciona hora'),
          children: slots.map((slot) {
            final label =
                '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, slot.hour * 60 + slot.minute),
              child: Text(label, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _onConfirmPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final districtId = _districtId;
    if (districtId == null || districtId.isEmpty) {
      setState(() => _message = 'Selecciona un distrito');
      return;
    }
    if (_scheduledAt == null) {
      setState(() => _message = 'Selecciona fecha y hora');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final request = await repo.createRequest(
        districtId: districtId,
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
        scheduledAtLocal: _scheduledAt!,
      );
      if (!mounted) {
        return;
      }
      context.go('/client/requests/${request.id}');
    } catch (error) {
      setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
