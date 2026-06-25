---
title: "Implementing Oh My QEMU with Humanize ideas"
description: "How Humanize's loop engineering, workflow graph, and flow primitive ideas shape Oh My QEMU's QEMU modeling workflow."
pubDate: 2026-06-25
author: "Zevorn"
tags: ["workflow", "humanize", "qemu"]
draft: false
---

Oh My QEMU is an attempt to turn several years of QEMU modeling experience into an executable workflow. It is not just a collection of prompts. It is a way to make long-running hardware modeling work observable, recoverable, and reviewable.

The design is heavily influenced by Humanize. Humanize treats agent coding as loop engineering: define the goal, build in small steps, review every step, preserve local memory, and keep the task moving toward the original acceptance criteria.

Oh My QEMU applies the same idea to QEMU device, board, boot, and debug work.

## From commands to workflows

A command is useful when the task is small. It wraps a repeated prompt behind a shortcut.

A skill is stronger. It can include instructions, scripts, templates, and trigger conditions. It tells the agent how to handle a class of tasks, not just one action.

But QEMU modeling needs more than isolated skills. A board model may require datasheet research, register extraction, image packaging, boot testing, qtest coverage, trace analysis, and documentation. Those steps have order, state, failure paths, and exit conditions.

That is why Oh My QEMU is built around workflows. The workflow decides what phase the task is in, what evidence is needed before moving forward, and when the final result is ready for human review.

## Humanize as loop engineering

The most important Humanize idea is the loop.

A human starts by defining the goal, constraints, and acceptance criteria. A builder agent implements one slice. A reviewer checks whether the slice is correct, scoped, and aligned with the goal. The loop continues until the work is complete.

For QEMU work, this matters because progress can be misleading. A guest may boot a little further while the device model is still wrong. A qtest may pass while the register semantics are guessed. A local patch may compile while the provenance is unclear.

Oh My QEMU keeps the loop evidence-first. Every meaningful step should leave a record: source provenance, command lines, logs, traces, qtest output, boot results, and unresolved assumptions.

## Flow primitives for QEMU work

Humanize also suggests a useful abstraction: make the workflow out of stable primitives.

Oh My QEMU defines these primitives around QEMU tasks:

- source provenance records where facts came from;
- register extraction turns datasheets and drivers into a model contract;
- image layout records partitions, offsets, firmware, and kernel artifacts;
- boot run captures reproducible QEMU commands and logs;
- model verification classifies behavior as PASS, FAIL, or INCONCLUSIVE;
- qtest provides narrow regression evidence;
- debug and trace workflows capture the reason a model or guest stops moving.

Each primitive has a clear input, output, and evidence boundary. Larger workflows are composed from these pieces: peripheral modeling, board modeling, firmware boot, direct Linux boot, TCG instruction work, and documentation.

## Dynamic workflow for real hardware models

Static workflows are useful, but hardware modeling often changes shape while the task is running.

A board may contain many devices. Some need accurate MMIO behavior; others only need enough behavior to let early boot continue. A task may start as direct Linux boot, then require firmware boot. A missing interrupt may require qtest, trace events, or a gdbstub session.

Oh My QEMU therefore treats the workflow as dynamic. The goal stays stable, but the next step can be replanned from the current evidence. The agent can combine flow primitives as needed instead of following a single fixed script.

This is the same direction as Humanize 3.0: the agent executes a workflow, but can also adapt the workflow through observable state, checkpoints, and review boundaries.

## The implementation principle

The practical rule is simple: do not trust progress without evidence.

Oh My QEMU stores task artifacts under `build/agent/<task-slug>/`. Plans, logs, traces, source notes, command lines, review ledgers, and final summaries stay there instead of polluting the QEMU source tree.

That artifact boundary makes long tasks easier to resume. It also makes the final handoff cleaner. Local checkpoint commits can exist during development, but the final QEMU-style series should be split and reviewed by a human.

## Why this matters

QEMU modeling is a good stress test for agent workflows. The task is long, the state is complex, and success is not binary. A model can be partially correct for hours before the real bug appears.

Humanize provides the engineering shape: loop, review, memory, checkpoints, and dynamic flow. Oh My QEMU instantiates that shape for hardware modeling: flow primitives, evidence ledgers, boot artifacts, and verification gates.

The result is not an agent that magically writes a board model in one shot. The result is a workflow that can keep moving through uncertainty without losing the goal, the evidence, or the ability for a human to review what happened.
