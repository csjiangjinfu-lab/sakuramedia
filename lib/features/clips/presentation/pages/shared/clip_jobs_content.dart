import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/data/dto/clip_job_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

/// 异步剪辑任务列表共享内容。
///
/// 桌面与移动只在留白与壳层不同：数据、轮询、取消/重试逻辑都收在这里。
/// 轮询只在页面挂载期间生效（[dispose] 取消定时器）。
class ClipJobsContent extends ConsumerStatefulWidget {
  const ClipJobsContent({super.key, required this.mobile});

  final bool mobile;

  @override
  ConsumerState<ClipJobsContent> createState() => _ClipJobsContentState();
}

class _ClipJobsContentState extends ConsumerState<ClipJobsContent> {
  static const Duration _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  bool _loading = true;
  String? _error;
  List<ClipJobDto> _jobs = const <ClipJobDto>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final page = await ref
          .read(clipsApiProvider)
          .listClipJobs(page: 1, pageSize: 50);
      if (!mounted) {
        return;
      }
      setState(() {
        _jobs = page.items;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (silent) {
        // 轮询失败不打扰用户：保留上一份列表，等下一次轮询恢复。
        setState(() => _loading = false);
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = apiErrorMessage(
          error,
          fallback: l10n.clipJobsLoadFailed,
          l10n: l10n,
        );
      });
    }
  }

  Future<void> _cancel(ClipJobDto job) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(clipsApiProvider).cancelClipJob(jobId: job.jobId);
      await _load(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: l10n.clipJobsActionFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _retry(ClipJobDto job) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(clipsApiProvider).retryClipJob(jobId: job.jobId);
      await _load(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: l10n.clipJobsActionFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
    }
  }

  String _stateLabel(AppLocalizations l10n, String state) {
    switch (state) {
      case 'queued':
        return l10n.clipJobStateQueued;
      case 'running':
        return l10n.clipJobStateRunning;
      case 'deferred':
        return l10n.clipJobStateDeferred;
      case 'succeeded':
        return l10n.clipJobStateSucceeded;
      case 'failed':
        return l10n.clipJobStateFailed;
      case 'canceled':
        return l10n.clipJobStateCanceled;
    }
    return state;
  }

  String _errorLabel(AppLocalizations l10n, ClipJobDto job) {
    switch (job.lastErrorCode) {
      case 'playback_active':
        return l10n.clipJobDeferredPlayback;
      case 'media_operation_busy':
        return l10n.clipJobDeferredBusy;
      case 'provider_unavailable':
        return l10n.clipJobDeferredProvider;
      case 'source_not_found':
        return l10n.clipJobFailedSource;
    }
    return job.lastErrorMessage ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error case final error?) {
      return AppErrorState(
        key: const Key('clip-jobs-error-state'),
        title: l10n.clipJobsLoadFailed,
        message: error,
        retryKey: const Key('clip-jobs-error-retry'),
        onRetry: () => unawaited(_load()),
      );
    }
    if (_jobs.isEmpty) {
      return AppEmptyState(
        key: const Key('clip-jobs-empty-state'),
        icon: Icons.video_library_outlined,
        message: l10n.clipJobsEmpty,
      );
    }
    return ListView.separated(
      key: const Key('clip-jobs-list'),
      padding: EdgeInsets.all(widget.mobile ? 12 : 24),
      itemCount: _jobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildJobCard(context, l10n, _jobs[index]),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    AppLocalizations l10n,
    ClipJobDto job,
  ) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final range =
        '${formatMediaTimecode(job.startOffsetSeconds)} - '
        '${formatMediaTimecode(job.endOffsetSeconds)}';
    final reason = _errorLabel(l10n, job);
    final heading = job.movieNumber ?? job.title;
    return Container(
      key: Key('clip-job-row-${job.jobId}'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: context.appRadius.smBorder,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  _stateLabel(l10n, job.state),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            '$range  ${job.title}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          if (reason.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.xs),
            Text(
              reason,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ],
          SizedBox(height: spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (job.canCancel)
                AppTextButton(
                  key: Key('clip-job-cancel-${job.jobId}'),
                  label: l10n.clipJobCancel,
                  size: AppTextButtonSize.small,
                  onPressed: () => unawaited(_cancel(job)),
                ),
              if (job.canRetry)
                AppTextButton(
                  key: Key('clip-job-retry-${job.jobId}'),
                  label: l10n.clipJobRetry,
                  size: AppTextButtonSize.small,
                  emphasis: AppTextButtonEmphasis.accent,
                  onPressed: () => unawaited(_retry(job)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
