import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/provider_ratings_summary.dart';
import '../../../shared/models/service_request_model.dart';
import '../state/client_requests_providers.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  ServiceRequestModel? _request;
  ProviderRatingsSummary? _providerRatings;
  String? _error;
  bool _loading = true;
  bool _providerRatingsLoading = false;
  bool _cancelSubmitting = false;
  bool _ratingSubmitting = false;
  bool _ratingSubmitted = false;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Duration _remaining = Duration.zero;
  int _selectedStars = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle Solicitud')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle Solicitud')),
        body: const Center(child: Text('Solicitud no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Solicitud'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Estado', request.status.value),
          _row('Distrito', request.district?.name ?? request.districtId),
          _row('Precio', request.priceTotal.toStringAsFixed(2)),
          _row('Direccion', request.addressDetail),
          _row('Fecha (local)', request.scheduledAt.toLocal().toString()),
          if (request.status == ServiceRequestStatus.pending)
            _row('Tiempo restante', _formatRemaining(_remaining)),
          if (request.status == ServiceRequestStatus.cancelled && request.cancellationReason != null)
            _row('Motivo cancelación', request.cancellationReason!),
          if (_isProviderAssigned(request)) ...[
            const SizedBox(height: 12),
            const Text(
              'Proveedor asignado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _row('Nombre', request.provider?.fullName ?? request.providerId!),
            if (request.provider != null) _row('Telefono', request.provider!.phone),
            _buildProviderRatingSummary(),
          ],
          if (_canCancel(request.status)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cancelSubmitting ? null : _cancelRequest,
              icon: _cancelSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar solicitud'),
            ),
          ],
          if (request.status == ServiceRequestStatus.completed) ...[
            const SizedBox(height: 16),
            _buildRatingCard(),
          ],
          if (request.status == ServiceRequestStatus.expired)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nadie aceptó. Intenta de nuevo.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.go('/client/request/new'),
                    child: const Text('Crear nueva solicitud'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildProviderRatingSummary() {
    if (_providerRatingsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_providerRatings == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _row(
        'Rating promedio',
        '${_providerRatings!.averageStars.toStringAsFixed(2)} (${_providerRatings!.totalRatings} calificaciones)',
      ),
    );
  }

  Widget _buildRatingCard() {
    if (_ratingSubmitted) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calificación',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Ya registraste tu calificación para este servicio.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calificar servicio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: List.generate(5, (index) {
                final stars = index + 1;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedStars = stars;
                    });
                  },
                  icon: Icon(
                    stars <= _selectedStars ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade700,
                  ),
                );
              }),
            ),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _ratingSubmitting ? null : _submitRating,
                child: _ratingSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar Calificación'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRequest() async {
    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final request = await repo.getRequestById(widget.requestId);
      if (!mounted) {
        return;
      }
      setState(() {
        _request = request;
        _loading = false;
        _error = null;
      });
      _setupTimersForStatus(request);
      if (request.providerId != null) {
        await _loadProviderRatings(request.providerId!);
      } else if (mounted) {
        setState(() {
          _providerRatings = null;
          _providerRatingsLoading = false;
          _ratingSubmitted = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapDioErrorToMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadProviderRatings(String providerId) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _providerRatingsLoading = true;
    });
    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final ratings = await repo.getProviderRatings(providerId);
      if (!mounted) {
        return;
      }
      final currentRequestId = _request?.id;
      final alreadyRated = currentRequestId != null &&
          ratings.ratings.any((rating) => rating.serviceRequestId == currentRequestId);
      setState(() {
        _providerRatings = ratings;
        _ratingSubmitted = alreadyRated;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerRatings = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _providerRatingsLoading = false;
        });
      }
    }
  }

  void _setupTimersForStatus(ServiceRequestModel request) {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();

    if (request.status != ServiceRequestStatus.pending) {
      _remaining = Duration.zero;
      return;
    }

    _updateRemaining(request.expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(request.expiresAt);
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final repo = ref.read(clientRequestsRepositoryProvider);
      try {
        final fresh = await repo.getRequestById(widget.requestId);
        if (!mounted) {
          return;
        }
        final previousProviderId = _request?.providerId;
        setState(() {
          _request = fresh;
        });
        if (fresh.providerId != null && fresh.providerId != previousProviderId) {
          await _loadProviderRatings(fresh.providerId!);
        }
        if (fresh.status != ServiceRequestStatus.pending) {
          _countdownTimer?.cancel();
          _pollingTimer?.cancel();
        }
      } catch (_) {
        // Silent retry on next polling tick.
      }
    });
  }

  void _updateRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now().toUtc());
    if (!mounted) {
      return;
    }
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  Future<void> _cancelRequest() async {
    final request = _request;
    if (request == null) {
      return;
    }

    final reason = await _promptCancellationReason();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    setState(() {
      _cancelSubmitting = true;
    });
    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      final updated = await repo.cancelRequest(requestId: request.id, reason: reason.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _request = updated;
      });
      _setupTimersForStatus(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada correctamente')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapDioErrorToMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitRating() async {
    final request = _request;
    if (request == null) {
      return;
    }
    setState(() {
      _ratingSubmitting = true;
    });
    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      await repo.submitRating(
        requestId: request.id,
        stars: _selectedStars,
        comment: _commentController.text,
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      setState(() {
        _ratingSubmitted = true;
      });
      if (request.providerId != null) {
        await _loadProviderRatings(request.providerId!);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación enviada')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is DioException && error.response?.statusCode == 409) {
        setState(() {
          _ratingSubmitted = true;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapDioErrorToMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _ratingSubmitting = false;
        });
      }
    }
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
              title: const Text('Cancelar solicitud'),
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

  bool _isProviderAssigned(ServiceRequestModel request) =>
      request.providerId != null || request.provider != null;

  bool _canCancel(ServiceRequestStatus status) =>
      status == ServiceRequestStatus.pending || status == ServiceRequestStatus.accepted;

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
