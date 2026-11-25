import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/presentation/pages/shared/clip_jobs_content.dart';

/// 移动剪辑任务页壳：布局差异收在共享内容层内。
class MobileClipJobsPage extends StatelessWidget {
  const MobileClipJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipJobsContent(mobile: true);
  }
}
