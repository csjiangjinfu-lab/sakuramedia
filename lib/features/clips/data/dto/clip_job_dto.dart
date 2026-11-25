/// 异步剪辑任务（后端 ClipJobResource）。
class ClipJobDto {
  const ClipJobDto({
    required this.jobId,
    required this.mediaId,
    required this.movieNumber,
    required this.startOffsetSeconds,
    required this.endOffsetSeconds,
    required this.title,
    required this.state,
    required this.attempts,
    required this.deferCount,
    required this.clipId,
    required this.lastErrorCode,
    required this.lastErrorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int jobId;
  final int? mediaId;
  final String? movieNumber;
  final int startOffsetSeconds;
  final int endOffsetSeconds;
  final String title;
  final String state;
  final int attempts;
  final int deferCount;
  final int? clipId;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive =>
      state == 'queued' || state == 'running' || state == 'deferred';
  bool get canCancel => state == 'queued' || state == 'deferred';
  bool get canRetry => state == 'failed';

  factory ClipJobDto.fromJson(Map<String, dynamic> json) {
    return ClipJobDto(
      jobId: json['job_id'] as int? ?? 0,
      mediaId: json['media_id'] as int?,
      movieNumber: json['movie_number'] as String?,
      startOffsetSeconds: json['start_offset_seconds'] as int? ?? 0,
      endOffsetSeconds: json['end_offset_seconds'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? 'queued',
      attempts: json['attempts'] as int? ?? 0,
      deferCount: json['defer_count'] as int? ?? 0,
      clipId: json['clip_id'] as int?,
      lastErrorCode: json['last_error_code'] as String?,
      lastErrorMessage: json['last_error_message'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
