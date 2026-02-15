import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/provider_available_job.dart';
import '../../../shared/utils/date_formatter.dart';
import '../state/provider_jobs_providers.dart';

class AvailableJobsScreen extends ConsumerStatefulWidget {
  const AvailableJobsScreen({super.key});

  @override
  ConsumerState<AvailableJobsScreen> createState() => _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends ConsumerState<AvailableJobsScreen> {
  final List<ProviderAvailableJob> _jobs = [];
  Timer? _pollingTimer;
  Timer? _tickerTimer;
  bool _loading = true;
  String? _error;
  String? _acceptingJobId;
  int _pollSeconds = 10;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajos Disponibles'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadJobs(isManualRefresh: true),
      child: _jobs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 140),
                Center(
                  child: Text('No hay trabajos disponibles en tu zona'),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = _jobs[index];
                final remaining = _remainingLabel(job.expiresAt);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.districtName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('Horas: ${job.hoursRequested}'),
                        Text('Precio: ${job.priceTotal.toStringAsFixed(2)}'),
                        Text('Fecha: ${formatDateTime(job.scheduledAt)}'),
                        Text('Expira en: $remaining'),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _acceptingJobId == job.id
                                ? null
                                : () => _acceptJob(job.id),
                            child: _acceptingJobId == job.id
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Aceptar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _loadJobs({bool isManualRefresh = false}) async {
    _pollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repository = ref.read(providerJobsRepositoryProvider);
      final jobs = await repository.getAvailableJobs();
      if (!mounted) {
        return;
      }
      setState(() {
        _jobs
          ..clear()
          ..addAll(jobs);
        _pollSeconds = jobs.isEmpty ? 60 : 10;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapProviderError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _scheduleNextPoll();
      }
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer(Duration(seconds: _pollSeconds), () {
      _loadJobs();
    });
  }

  Future<void> _acceptJob(String id) async {
    setState(() {
      _acceptingJobId = id;
    });

    try {
      final repository = ref.read(providerJobsRepositoryProvider);
      await repository.acceptJob(id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trabajo aceptado correctamente')),
      );
      context.go('/provider/jobs/mine');
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is DioException && error.response?.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya fue tomado')),
        );
        await _loadJobs(isManualRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapProviderError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingJobId = null;
        });
      }
    }
  }

  String _remainingLabel(DateTime expiresAt) {
    final seconds = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    final safeSeconds = seconds.isNegative ? 0 : seconds;
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final remSeconds = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remSeconds';
  }
}
