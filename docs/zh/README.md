# Oh My QEMU 架构与流程文档

> **中文** · [English](../en/README.md)

本目录存放 Oh My QEMU 的架构设计、建模流程、RS-IR 与翻译目标等文档。
可独立安装的 skill 定义仍然以 `skills/<name>/SKILL.md` 为准；这里记录的是
**跨 skill 的整体设计和执行流程**，方便人类评审、新人上手和后续演进。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) · [English](../en/architecture.md) | 整体架构：分层、19 个 skill 的职责、数据流、审计工作区、门禁与边界 |
| [modeling-workflow.md](modeling-workflow.md) · [English](../en/modeling-workflow.md) | 端到端建模流程：P0-P8、round loop、独立评审回路、停止条件、常用命令 |
| [rs-ir-and-translation.md](rs-ir-and-translation.md) · [English](../en/rs-ir-and-translation.md) | RS-IR 设计、词表、observe/placeholder、到 RegisterInfo / Unimplemented Device 的翻译 |
| [English](../en/README.md) | English version of this index |
| [assets/](assets/) | 中文流程图与架构图的 PNG/SVG/Graphviz 源文件 |

## 核心设计目标

1. **一个顶层入口**：用户说“建模 X / 继续下一轮”时，只调用 `qemu-modeler`，
   由它决定加载哪些领域 skill、按什么阶段执行、什么时候 review、何时停止。
2. **证据优先**：每个行为、reset 值、寄存器 bit、启动结论都要有来源（源码/手册/
   追踪）和可复现证据；不接受“看起来能跑”。
3. **可审计**：所有中间产物落在 `.oh-my-qemu/<task-slug>/` 下，包含 audit、
   commands、logs、scripts、output；状态和轮次记录可恢复。
4. **硬门禁**：PASS 必须有 marker 或可证伪 qtest；review 通过前不推进；脚本负责
   可机器检查的部分（gates、RS-IR、review packet），人/agent 负责判断。
5. **边界清晰**：RegisterInfo 负责外设行为，Unimplemented Device 负责板卡级占位；
   本地建模不生成上游提交内容。

## 快速开始

```bash
# 场景一：完整建模任务，从顶层入口开始
#   在支持 skill 的 agent 中说：
#   用 qemu-modeler 建模 <设备/板卡>，验收标准是 <...>

# 场景二：只做某一类任务
#   qemu-register-extraction / qemu-peripheral-modeling / qemu-board-modeling ...

# 场景三：校验已有任务状态
bash skills/qemu-modeler/scripts/loop-state.sh show .oh-my-qemu/<task-slug>
bash skills/qemu-model-review/scripts/review-checks.sh --task-dir .oh-my-qemu/<task-slug>
```

## 19 个 skill 的分层

| 层 | Skill |
| --- | --- |
| 顶层编排与评审 | `qemu-modeler`、`qemu-model-review` |
| 横切规则 | `qemu-workflow`、`qemu-agent-feedback` |
| 证据与契约 | `qemu-register-extraction`、`qemu-board-modeling` |
| 建模实现 | `qemu-peripheral-modeling`、`qemu-board-modeling`、`qemu-tcg-frontend`、`qemu-tcg-backend` |
| 构建/镜像/启动 | `qemu-build`、`qemu-kernel-build`、`qemu-uboot-build`、`qemu-image`、`qemu-boot-run`、`qemu-linux-boot` |
| 验证/调试/文档 | `qemu-qtest`、`qemu-model-verification`、`qemu-debug`、`qemu-rst-documentation` |

## 图的维护方式

- 图源是 `assets/*.dot`（Graphviz），可编辑后重新生成：

```bash
cd docs/zh/assets
dot -Tpng -Gdpi=150 modeling-flow.dot -o modeling-flow.png
dot -Tsvg modeling-flow.dot -o modeling-flow.svg
dot -Tpng -Gdpi=150 modeling-architecture.dot -o modeling-architecture.png
dot -Tsvg modeling-architecture.dot -o modeling-architecture.svg
```

- 架构或流程变化时，同时更新对应 `.md` 和图源，避免文档与 skill 不一致。
- 仓库校验：

```bash
npm run codex:skills:validate
npm run test:skill-scripts
```

## 相关链接

- 仓库入口：[README.md](../../README.md)
- Skill 规则：[AGENTS.md](../../AGENTS.md)、[skills/](../../skills/)
- 站点文档：[site/](../../site/)
