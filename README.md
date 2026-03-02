# GitHub Action Operator

此项目提供用于构建和管理 Gluten 项目的 GitHub Action 工作流。

## 项目结构

- `.github/workflows/` - GitHub Action 工作流
- `.trae/` - Trae 配置
  - `rules/` - 规则配置
  - `skills/` - 技能配置

## 可用工作流

- `build_gluten_arm.yml` - 为 ARM 架构构建 Gluten
  - **触发条件**：推送到 main 或 master 分支
  - **运行器**：最新版 Ubuntu
  - **步骤**：
    1. 检出当前仓库
    2. 设置 QEMU 以支持多架构
    3. 检查 Docker 依赖
    4. 设置 Docker Buildx
    5. 缓存 Docker 层
    6. 拉取 SWR 公共镜像
    7. 创建本地目录
    8. 启动构建容器
    9. 拉取代码到容器（Gluten、OmniOperator、libboundscheck、BoostKit_CI）
    10. 执行构建脚本
    11. 从容器复制构建产物
    12. 上传构建产物
  - **产物**：`gluten-artifacts-arm` (gluten.zip)

## 使用方法

要使用此仓库中的工作流：

1. Fork 此仓库
2. 根据需要修改工作流
3. 通过 GitHub Actions 触发工作流

## 贡献

欢迎贡献！请随时提交 Pull Request。

## 许可证

此项目采用 MIT 许可证。

## README 刷新器技能

此项目包含一个 `readme-refresher` 技能，可在代码修改后自动更新 README 文件。

### 使用时机

调用此技能：
- 完成影响 README 中描述的功能的代码修改后
- 添加需要文档更新的新功能时
- 提交更改前确保 README 是最新的
- 重构改变功能工作方式的代码时

### 优势

- 确保文档准确性
- 节省手动更新 README 的时间
- 防止文档与代码变化脱节
- 保持代码与文档之间的一致性
- 提高项目可维护性

## 代码推送规则

此项目包含一个代码推送规则，确保每次代码修改都会：
1. 触发 README 刷新技能
2. 执行 AI 检查
3. 处理自动提交到远程仓库的操作

详细工作流程请参考 `.trae/rules/push-code.md` 文件。