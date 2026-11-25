import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/data/dto/clip_job_dto.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

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

  /// 是否至少成功加载过一次列表。轮询失败只在已有数据时静默吞掉，
  /// 否则会把「首屏加载失败」永远显示成「暂无任务」。
  bool _hasLoadedOnce = false;
  List<ClipJobDto> _jobs = const <ClipJobDto>[];

  /// 请求序号：每次 [_load] 自增，回来的响应若序号过期就丢弃，
  /// 避免轮询与手动刷新（或取消/重试后的刷新）互相覆盖。
  int _loadSeq = 0;

  /// 正在执行取消/重试的 job；同一时间只允许一个动作，避免重复提交。
  int? _pendingJobId;

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
    final seq = ++_loadSeq;
    try {
      final page = await ref
          .read(clipsApiProvider)
          .listClipJobs(page: 1, pageSize: 50);
      if (!mounted || seq != _loadSeq) {
        return;
      }
      setState(() {
        _jobs = page.items;
        _error = null;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted || seq != _loadSeq) {
        return;
      }
      if (silent && _hasLoadedOnce) {
        // 已有数据时轮询失败不打扰用户：保留上一份列表，等下一次轮询恢复。
        // 此时 _loading 早已是 false，不能在这里改它。
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

  void _retryLoad() {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_load());
  }

  Future<void> _cancel(ClipJobDto job) async {
    if (_pendingJobId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _pendingJobId = job.jobId);
    try {
      await ref.read(clipsApiProvider).cancelClipJob(jobId: job.jobId);
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.clipJobsActionFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      // 先解除忙碌态再刷新列表：刷新慢时按钮不会一直转圈。
      if (mounted) {
        setState(() => _pendingJobId = null);
      }
    }
    if (mounted) {
      await _load(silent: true);
    }
  }

  Future<void> _retry(ClipJobDto job) async {
    if (_pendingJobId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _pendingJobId = job.jobId);
    try {
      await ref.read(clipsApiProvider).retryClipJob(jobId: job.jobId);
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.clipJobsActionFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      // 先解除忙碌态再刷新列表：刷新慢时按钮不会一直转圈。
      if (mounted) {
        setState(() => _pendingJobId = null);
      }
    }
    if (mounted) {
      await _load(silent: true);
    }
  }

  /// 打开已生成切片：任务列表只带 clip_id，播放地址要再拉一次详情。
  Future<void> _openClip(ClipJobDto job) async {
    final clipId = job.clipId;
    if (clipId == null || _pendingJobId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    // 拉详情期间占用同一个忙碌位，避免连点重复请求与重复起播。
    setState(() => _pendingJobId = job.jobId);
    try {
      final detail = await ref
          .read(clipsApiProvider)
          .getClipDetail(clipId: clipId);
      if (!mounted) {
        return;
      }
      await launchClipPlayback(
        context,
        streamUrl: detail.streamUrl,
        title: detail.title,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.clipJobsActionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _pendingJobId = null);
      }
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

  /// 任务状态 → 共享语义：失败 error、成功 success、运行中 info、
  /// 延后 warning、排队/取消 neutral。
  AppStatusChipPalette _statePalette(String state) {
    final semantic = switch (state) {
      'failed' => AppStatusSemantic.error,
      'succeeded' => AppStatusSemantic.success,
      'running' => AppStatusSemantic.inProgress,
      'deferred' => AppStatusSemantic.warning,
      _ => AppStatusSemantic.neutral,
    };
    return AppStatusChipPalette.forSemantic(semantic);
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
    final spacing = context.appSpacing;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error case final error?) {
      return AppErrorState(
        key: const Key('clip-jobs-error-state'),
        title: l10n.clipJobsLoadFailed,
        message: error,
        retryKey: const Key('clip-jobs-error-retry'),
        onRetry: _retryLoad,
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
      padding: EdgeInsets.all(
        widget.mobile ? spacing.md : AppPageInsets.desktop,
      ),
      itemCount: _jobs.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) =>
          _buildJobCard(context, l10n, _jobs[index]),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    AppLocalizations l10n,
    ClipJobDto job,
  ) {
    final spacing = context.appSpacing;
    final range =
        '${formatMediaTimecode(job.startOffsetSeconds)} - '
        '${formatMediaTimecode(job.endOffsetSeconds)}';
    final reason = _errorLabel(l10n, job);
    // AppContentCard 的标题没有 maxLines：编号正常是短文本，只有编号缺失时
    // 才退回标题文本（长标题会换行，接受，不为一行截断另造参数）。
    // 编号可能是空串（后端字段存在但没值），空串当标题会让卡片头部留白。
    final hasMovieNumber = job.movieNumber?.trim().isNotEmpty ?? false;
    final heading = hasMovieNumber ? job.movieNumber! : job.title;
    // 标题已经是标题文本时正文不再重复；标题是编号时正文补上标题。
    final detail = hasMovieNumber ? '$range  ${job.title}' : range;
    final isPending = _pendingJobId == job.jobId;
    final canAct = _pendingJobId == null;
    return AppContentCard(
      key: Key('clip-job-row-${job.jobId}'),
      title: heading,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      headerTrailing: AppStatusChip(
        label: _stateLabel(l10n, job.state),
        palette: _statePalette(job.state),
        dense: true,
      ),
      headerBottomSpacing: spacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            detail,
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
              if (job.state == 'succeeded' && job.clipId != null)
                AppTextButton(
                  key: Key('clip-job-view-${job.jobId}'),
                  label: l10n.clipCollectionPlay,
                  size: AppTextButtonSize.small,
                  emphasis: AppTextButtonEmphasis.accent,
                  isLoading: isPending,
                  onPressed: canAct ? () => unawaited(_openClip(job)) : null,
                ),
              if (job.canCancel)
                AppTextButton(
                  key: Key('clip-job-cancel-${job.jobId}'),
                  label: l10n.clipJobCancel,
                  size: AppTextButtonSize.small,
                  isLoading: isPending,
                  onPressed: canAct ? () => unawaited(_cancel(job)) : null,
                ),
              if (job.canRetry)
                AppTextButton(
                  key: Key('clip-job-retry-${job.jobId}'),
                  label: l10n.clipJobRetry,
                  size: AppTextButtonSize.small,
                  emphasis: AppTextButtonEmphasis.accent,
                  isLoading: isPending,
                  onPressed: canAct ? () => unawaited(_retry(job)) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
