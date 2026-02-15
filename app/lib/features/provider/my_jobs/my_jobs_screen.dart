import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/service_request_model.dart';
import '../../../shared/utils/date_formatter.dart';
import '../../../shared/utils/phone_actions.dart';
import '../state/provider_jobs_providers.dart';

class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen> {
  ServiceRequestStatus _selected = ServiceRequestStatus.accepted;
  String? _activeJobId;
  String? _activeAction;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(assignedJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Trabajos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ServiceRequestStatus>(
              segments: const [
                ButtonSegment(
                  value: ServiceRequestStatus.accepted,
                  label: Text('ACCEPTED'),
                ),
                ButtonSegment(
                  value: ServiceRequestStatus.inProgress,
                  label: Text('IN_PROGRESS'),
                ),
                ButtonSegment(
                  value: ServiceRequestStatus.completed,
                  label: Text('COMPLETED'),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) {
                setState(() {
                  _selected = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: jobsAsync.when(
              data: (jobs) {
                final filtered = jobs.where((job) => job.status == _selected).toList(growable: false);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No hay trabajos en este estado'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refreshJobs,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final job = filtered[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.district?.name ?? 'Distrito ${job.districtId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _StatusChip(status: job.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Fecha: ${formatDateTime(job.scheduledAt)}'),
                              Text('Precio: ${job.priceTotal.toStringAsFixed(2)}'),
                              Text('Horas: ${job.hoursRequested}'),
                              if (job.client != null) ...[
                                const SizedBox(height: 4),
                                Text('Cliente: ${job.client!.fullName}'),
                                Row(
                                  children: [
                                    Text('Tel: ${job.client!.phone}'),
                                    PhoneActionButtons(phone: job.client!.phone),
                                  ],
                                ),
                              ],
                              if (job.status == ServiceRequestStatus.accepted) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _isBusy(job.id)
                                            ? null
                                            : () => _startService(job.id),
                                        child: _actionIndicator(
                                          job.id,
                                          'start',
                                          'Iniciar Servicio',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isBusy(job.id)
                                            ? null
                                            : () => _cancelService(job.id),
                                        child: _actionIndicator(
                                          job.id,
                                          'cancel',
                                          'Cancelar',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (job.status == ServiceRequestStatus.inProgress) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isBusy(job.id)
                                        ? null
                                        : () => _completeService(job.id),
                                    child: _actionIndicator(
                                      job.id,
                                      'complete',
                                      'Completar Servicio',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    mapProviderError(error),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshJobs() async {
    final _ = await ref.refresh(assignedJobsProvider.future);
  }

  bool _isBusy(String jobId) => _activeJobId == jobId;

  Widget _actionIndicator(String jobId, String action, String label) {
    if (_activeJobId == jobId && _activeAction == action) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(label);
  }

  Future<void> _startService(String requestId) async {
    final confirmed = await _confirmAction(
      title: 'Iniciar servicio',
      content: '¿Confirmas que deseas iniciar este trabajo?',
      confirmText: 'Iniciar',
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _activeJobId = requestId;
      _activeAction = 'start';
    });

    try {
      final repository = ref.read(providerJobsRepositoryProvider);
      await repository.startJob(requestId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio iniciado')),
      );
      await _refreshJobs();
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = ServiceRequestStatus.inProgress;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapProviderError(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeJobId = null;
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _completeService(String requestId) async {
    final confirmed = await _confirmAction(
      title: 'Completar servicio',
      content: '¿Confirmas que deseas marcar este trabajo como completado?',
      confirmText: 'Completar',
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _activeJobId = requestId;
      _activeAction = 'complete';
    });

    try {
      final repository = ref.read(providerJobsRepositoryProvider);
      await repository.completeJob(requestId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio completado')),
      );
      await _refreshJobs();
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = ServiceRequestStatus.completed;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapProviderError(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeJobId = null;
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _cancelService(String requestId) async {
    final reason = await _promptCancellationReason();
    if (reason == null) {
      return;
    }

    setState(() {
      _activeJobId = requestId;
      _activeAction = 'cancel';
    });

    try {
      final repository = ref.read(providerJobsRepositoryProvider);
      await repository.cancelJob(requestId: requestId, reason: reason);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada')),
      );
      await _refreshJobs();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapProviderError(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeJobId = null;
          _activeAction = null;
        });
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<String?> _promptCancellationReason() async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cancelar servicio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Motivo de cancelación',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(() {
                        errorText = 'El motivo es obligatorio';
                      });
                      return;
                    }
                    Navigator.of(context).pop(text);
                  },
                  child: const Text('Confirmar cancelación'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusMeta(status);
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

(String, Color) _statusMeta(ServiceRequestStatus status) {
  switch (status) {
    case ServiceRequestStatus.pending:
      return ('PENDING', Colors.orange);
    case ServiceRequestStatus.accepted:
      return ('ACCEPTED', Colors.blue);
    case ServiceRequestStatus.inProgress:
      return ('IN_PROGRESS', Colors.indigo);
    case ServiceRequestStatus.completed:
      return ('COMPLETED', Colors.green);
    case ServiceRequestStatus.cancelled:
      return ('CANCELLED', Colors.red);
    case ServiceRequestStatus.expired:
      return ('EXPIRED', Colors.grey);
  }
}
