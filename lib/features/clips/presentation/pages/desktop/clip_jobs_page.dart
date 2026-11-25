import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/presentation/pages/shared/clip_jobs_content.dart';

/// 桌面剪辑任务页壳：布局差异收在共享内容层内。
class DesktopClipJobsPage extends StatelessWidget {
  const DesktopClipJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipJobsContent(mobile: false);
  }
}
