# CODEBUDDY.md

面向在本仓库工作的自动化助手。记录环境约定与硬性流程，改动前先读。

## 项目

- SakuraMedia **客户端**，Flutter（`pubspec.yaml` name: `sakuramedia`，Dart SDK >=3.12）
- 支持 android / ios / linux / macos / windows
- 同产品的后端是另一个仓库 `sakuramediabe`（本文件不覆盖）

## 远端与分支

| 远端 | 地址 | 用途 |
| --- | --- | --- |
| `origin` | github.com/csjiangjinfu-lab/sakuramedia | 我们的 GitHub 镜像，改动合并后推这里 |
| `gitea` | 自建 Gitea 镜像（地址不在仓库里写，见本地 git remote） | 按需同步 |
| `upstream` | github.com/tinypinglite/sakuramedia | 上游主仓，只读，持续有新提交 |

当前工作分支是 `main`。

## 硬性流程

1. **改代码前必须先同步上游**：`git fetch upstream && git merge upstream/main`，把上游更新拉进当前分支，再动手改。上游长期有 skills / agent-connect / 合并播放等新提交，不同步会导致基于旧代码改动、后续大面积冲突。
2. 合并产生冲突时先停下报告，不要用 `--force` / `-X ours` 之类的手段覆盖本地提交。
3. 改完推 `origin main`；需要时再推 `gitea`。
4. 工作区不干净时不要切分支或做会丢改动的操作。

## 禁止事项

- **不要在任何托管 Gitea 的那台服务器上执行本项目的构建/打包**。那台机器还跑着 Actions runner 和若干反向代理服务，之前跑 Flutter/Android 打包把 CPU 打满，整机卡死只能重启。需要构建就在本机或其它主机跑。
- 该服务器的 runner 注册了 `ubuntu-latest` 标签，Gitea Actions 里写 `runs-on: ubuntu-latest` 的任务会被它接走；给 Gitea 用的工作流应改用专用标签。
- 不要把凭据（PAT、密码、API key）写进仓库、日志或提交信息。

## 本地开发常用命令

```bash
flutter pub get          # 拉依赖
flutter analyze          # 静态检查
flutter test             # 单测
bash scripts/test.sh     # 仓库自带的测试脚本
```

修改涉及多端渲染或生成的文案时，注意 `l10n.yaml` 与 `l10n/` 下的生成产物。

## CI

- 工作流在 `.github/workflows/`：`ci.yml`、`release.yml`、`release-{android,ios,linux,macos,windows}.yml`、`docs.yml`
- 平台标签：`ubuntu-latest` / `macos-latest` / `windows-2022`（GitHub 托管，可正常使用）
- 发版走 tag + Release，与上游版本号保持 `vX.Y.Z` 约定

## 提交信息

沿用现有风格：`feat(client): ...` / `fix(client): ...` / `chore: ...` / `ci: ...`，描述用中文，说明"做了什么"而不是"改了哪些文件"。
