# RS-IR 与翻译目标

> **中文** · [English](../en/rs-ir-and-translation.md)

RS-IR（Register Semantics Intermediate Representation）是寄存器提取与设备建模
之间的机器可读中间表示。它把寄存器行为抽象为 **Trigger / Condition / Transition**
三元组，并提供固定词表、校验器和到 QEMU 机制的翻译清单。

## 输出与位置

一次完整的寄存器提取产生：

- `output/register-contract.md`：人读的行为契约，评审的权威记录；
- `output/register-semantics.ir`：RS-IR 文本，机器可读 companion；
- 原始 trace/GDB/QEMU debug 证据保留在 `logs/` 或原路径，不复制进 IR。

文件模板/示例/词表/校验器：

- `skills/qemu-register-extraction/assets/register-semantics-template.ir`
- `skills/qemu-register-extraction/assets/register-semantics-example.ir`
- `skills/qemu-register-extraction/assets/ir-ops.def`
- `skills/qemu-register-extraction/scripts/validate_register_ir.py`

## 三元组与词表

| 原语 | 作用 |
| --- | --- |
| Trigger | 事件：寄存器读/写、字段写、reset、timer 到期、IRQ 输入、DMA 完成、命令、enable 变化、guest 动作 |
| Condition | 纯谓词：all_of/any_of/not、eq/ne/lt/le/gt/ge、bit_set/bit_clear、masked_eq、in_range、fifo_*、counter_cmp |
| Transition | 有序操作：字段/状态赋值、set/clear/toggle bits、FIFO push/pop、IRQ assert/deassert、timer 调度、DMA、异常、事件、clear_on_read、log_unimp |

操作数类型（DEF 表中的 signature）：

| 类 | 含义 |
| --- | --- |
| B | 嵌套 condition 表达式 |
| R | register / field / state symbol |
| S | 任意 symbol |
| I / T / F / E | irq / timer / fifo / event symbol |
| M | symbol 或字面量 |
| V | constant symbol 或字面量 |

flags：

- `SIDE_EFFECTS`、`PURE`、`GUEST_VISIBLE`、`MIGRATABLE`、
  `RESET_AFFECTING`、`LOGGING_ONLY`、`EXPANDS`、`UNSUPPORTED`。

## 文本格式示例

```text
ir 1.0
target ip demo-timer-1.0
target variants demo-soc
target workload "periodic timer interrupt"
source DRV "drivers/demo-timer.c:10-120"
source MAN "Demo Timer TRM, section 4"

symbol register CTRL offset=0x00 width=32 access=rw reset=0x0 source=DRV
symbol field CTRL.EN bits=0 access=rw source=DRV
symbol field CTRL.MODE bits=1..2 access=rw source=MAN
symbol constant MODE_PERIODIC value=1 source=MAN
symbol constant PERIOD value=1000
symbol timer period_timer source=DRV
symbol irq irq0 kind=level source=MAN
symbol address UNMODELED_WINDOW base=0x1000 size=0x100 status=unimplemented placeholder=board_unimpl source=MAN

rule R1 "enable periodic mode schedules the period timer" tier=driver confidence=HIGH sources=DRV,MAN
  trigger register_write CTRL
  condition all_of(bit_set(CTRL.EN), eq(CTRL.MODE, MODE_PERIODIC))
  transition schedule_timer(period_timer, PERIOD)
  framework registerinfo hook=post_write rationale="schedule after write commits"
  observe trace="demo_timer.r1" log="none" error="none"
  qtest "write CTRL with EN=1 and MODE=PERIODIC, then check timer scheduled"

flow init R1
unresolved "PERIOD is not documented"
```

## observe 与占位

- `observe trace=<event>`：material transition 的稳定 trace event；
- `observe log=none|unimp|guest_error|both`：QEMU log mask；
- `observe error=none|guest_error|error_report|assert`：非法访问/内部 invariant 策略；
- guest-visible rule 必须有 observe（trace 或 log 至少一个）；
- `UNSUPPORTED` / `LOGGING_ONLY` 必须有 `log=unimp`（或 both）和 gap；
- `symbol address ... status=unimplemented placeholder=<name>`：板卡级 Unimplemented
  Device 占位；真实设备落地后移除。

## 翻译目标

### 1. 外设行为 → RegisterInfo

| RS-IR 元素 | QEMU 实现 |
| --- | --- |
| framework registerinfo + trigger/hook | `RegisterAccessInfo` access type 与 pre/post hook |
| symbol tables | device state + `VMStateDescription` |
| condition | 回调 guard/预写过滤 |
| transition | post-write/post-read hook、IRQ、timer、FIFO、DMA、异常 |
| rule id | 模型注释/trace event/qtest 名 |

### 2. 板卡占位 → Unimplemented Device

- `status=unimplemented` 的 address → 板卡/SoC 的 placeholder，带 base/size/name/
  owner/source；
- placeholder 只保证地址存在并可见（trace/`LOG_UNIMP`），不实现寄存器行为；
- 真实设备落地后同一变更内移除 placeholder 和 map 行；
- placeholder 不能算 modeled behavior，也不能作为 PASS 依据。

### 3. 错误处理与可观测性

| 情况 | 要求 |
| --- | --- |
| guest 写只读/保留字段 | 忽略写 + `LOG_GUEST_ERROR` |
| 不支持的访问宽度/对齐 | 按契约拒绝/处理 + `LOG_GUEST_ERROR` |
| guest 访问未实现窗口/placeholder | trace + `LOG_UNIMP`；不要伪造 ready |
| 模型 invariant 破坏 | `error_report` / assert，带 rule id |
| guest 触发 DMA/地址错误 | 走文档化错误路径 + guest error |
| host/资源失败 | `error_report` / `error_setg`，不隐藏 |

## 翻译工作清单

```bash
python3 skills/qemu-register-extraction/scripts/validate_register_ir.py \
    .oh-my-qemu/<task-slug>/output/register-semantics.ir
python3 skills/qemu-register-extraction/scripts/validate_register_ir.py --translate \
    .oh-my-qemu/<task-slug>/output/register-semantics.ir
```

`--translate` 输出 TSV：

```text
kind    id               mechanism            hook        trace            log    error        qtests  placeholder
rule    R1               registerinfo         post_write  demo_timer.r1    none   none         1       -
rule    R2               manual-mmio          manual      demo_timer.r2    none   guest_error  1       -
address UNMODELED_WINDOW unimplemented-device -           -                -      -            0       board_unimpl
```

模型实现与测试按这份清单展开，详见
`skills/qemu-peripheral-modeling/references/ir-to-registerinfo.md` 和
`skills/qemu-board-modeling/references/unimplemented-device.md`。

## 与人工契约的关系

- `register-contract.md` 是行为权威；RS-IR 是机器可读 companion；
- 两者共享 evidence、rule id、unknowns；冲突时以契约为准并修正 IR；
- validator 只检查结构/引用/flag/arity，不证明硬件事实为真；来源仍要人工核实。

## 边界

- 本地建模/验证工件，不生成上游提交内容；
- 不生成 C 模板；模型由 agent/人按 IR 手写；
- 不把 logging sink、placeholder、boot banner 当作已建模行为。

## 相关文档

- [architecture.md](architecture.md)
- [modeling-workflow.md](modeling-workflow.md)
- `skills/qemu-register-extraction/references/semantic-ir.md`
- `skills/qemu-register-extraction/assets/ir-ops.def`
