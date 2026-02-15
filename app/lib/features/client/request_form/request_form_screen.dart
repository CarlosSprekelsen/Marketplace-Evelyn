import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/price_quote.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/client_requests_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({
    super.key,
    this.prefillDistrictId,
    this.prefillAddress,
    this.prefillHours,
  });

  final String? prefillDistrictId;
  final String? prefillAddress;
  final int? prefillHours;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  String? _districtId;
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
    if (widget.prefillAddress != null) {
      _addressController.text = widget.prefillAddress!;
    }
    if (widget.prefillHours != null) {
      _hours = widget.prefillHours!;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
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
                      return DropdownButtonFormField<String>(
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
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selecciona un distrito';
                          }
                          return null;
                        },
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
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Dirección detallada',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la dirección';
                      }
                      if (value.length > 500) {
                        return 'Máximo 500 caracteres';
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
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loadingQuote ? null : _onQuotePressed,
                          child: _loadingQuote
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Ver Precio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting ? null : _onConfirmPressed,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Confirmar Solicitud'),
                        ),
                      ),
                    ],
                  ),
                  if (_quote != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cotizacion',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Distrito: ${_quote!.districtName}'),
                            Text('Horas: ${_quote!.hours} hora${_quote!.hours == 1 ? '' : 's'}'),
                            Text('Precio por hora: ${_quote!.pricePerHour.toStringAsFixed(2)}'),
                            Text(
                              'Total: \$${_quote!.priceTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  Future<void> _onQuotePressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final districtId = _districtId;
    if (districtId == null || districtId.isEmpty) {
      setState(() => _message = 'Selecciona un distrito');
      return;
    }

    setState(() {
      _loadingQuote = true;
      _message = null;
    });

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final quote = await repo.getQuote(districtId: districtId, hours: _hours);
      setState(() => _quote = quote);
    } catch (error) {
      setState(() => _message = mapDioErrorToMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loadingQuote = false);
      }
    }
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
        addressDetail: _addressController.text.trim(),
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
