[English](#english) | [中文](#中文)

## English

# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Amp](https://ampcode.com), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex CLI](https://github.com/openai/codex), or [OpenCode CLI](https://github.com/opencode-ai/opencode)) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
  - [Codex CLI](https://github.com/openai/codex) (`npm install -g @openai/codex` or `brew install --cask codex`)
  - [OpenCode CLI](https://github.com/opencode-ai/opencode) (`brew install opencode-ai/tap/opencode` or `curl -fsSL https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash`)
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Setup

### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# Copy the prompt template for your AI tool of choice:
# (Copy only the file(s) you plan to use.)
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md      # For Amp
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md      # For Claude Code
cp /path/to/ralph/CODEX.md scripts/ralph/CODEX.md        # For Codex CLI
cp /path/to/ralph/OPENCODE.md scripts/ralph/OPENCODE.md  # For OpenCode CLI

chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally

Copy the skills to your Amp, Claude, or Codex config for use across all projects:

For AMP
```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

For Claude Code
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

For Codex CLI
```bash
cp -r skills/prd "$CODEX_HOME/skills/"
cp -r skills/ralph "$CODEX_HOME/skills/"
```
If `$CODEX_HOME` is not set, use your Codex config directory (often `~/.codex`).

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

This enables automatic handoff when context fills up, allowing Ralph to handle large stories that exceed a single context window.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Using Amp (default)
./scripts/ralph/ralph.sh [max_iterations]

# Using Claude Code
./scripts/ralph/ralph.sh --tool claude [max_iterations]

# Using Codex CLI
./scripts/ralph/ralph.sh --tool codex [max_iterations]

# Using OpenCode CLI
./scripts/ralph/ralph.sh --tool opencode [max_iterations]
```

Default is 10 iterations. Use `--tool amp`, `--tool claude`, `--tool codex`, or `--tool opencode` to select your AI coding tool.

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances (supports `--tool amp`, `--tool claude`, `--tool codex`, or `--tool opencode`) |
| `prompt.md` | Prompt template for Amp |
| `CLAUDE.md` | Prompt template for Claude Code |
| `CODEX.md` | Prompt template for Codex CLI |
| `OPENCODE.md` | Prompt template for OpenCode CLI |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Amp, Claude Code, Codex CLI, or OpenCode CLI) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because AI coding tools automatically read these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

## 中文

# Ralph

![Ralph](ralph.webp)

Ralph 是一个自治的 AI 代理循环，会反复运行 AI 编码工具（[Amp](https://ampcode.com)、[Claude Code](https://docs.anthropic.com/en/docs/claude-code)、[Codex CLI](https://github.com/openai/codex)、或 [OpenCode CLI](https://github.com/opencode-ai/opencode)），直到所有 PRD 条目完成。每次迭代都会启动一个全新的实例并清空上下文。记忆通过 git 历史、`progress.txt` 和 `prd.json` 持久化。

基于 [Geoffrey Huntley 的 Ralph 模式](https://ghuntley.com/ralph/)。

[阅读我关于如何使用 Ralph 的深度文章](https://x.com/ryancarson/status/2008548371712135632)

## 前置条件

- 安装并完成认证的以下任一 AI 编码工具：
  - [Amp CLI](https://ampcode.com)（默认）
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)（`npm install -g @anthropic-ai/claude-code`）
  - [Codex CLI](https://github.com/openai/codex)（`npm install -g @openai/codex` 或 `brew install --cask codex`）
  - [OpenCode CLI](https://github.com/opencode-ai/opencode)（`brew install opencode-ai/tap/opencode` 或 `curl -fsSL https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash`）
- 已安装 `jq`（macOS 可用 `brew install jq`）
- 你的项目是一个 git 仓库

## 安装

### 选项 1：拷贝到你的项目

将 ralph 文件拷贝到你的项目中：

```bash
# 在你的项目根目录
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# 为你选择的 AI 工具拷贝提示模板：
# （只拷贝你计划使用的文件。）
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md      # 用于 Amp
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md      # 用于 Claude Code
cp /path/to/ralph/CODEX.md scripts/ralph/CODEX.md        # 用于 Codex CLI
cp /path/to/ralph/OPENCODE.md scripts/ralph/OPENCODE.md  # 用于 OpenCode CLI

chmod +x scripts/ralph/ralph.sh
```

### 选项 2：全局安装技能

将技能拷贝到你的 Amp、Claude 或 Codex 配置目录中，以便在所有项目中使用：

用于 AMP
```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

用于 Claude Code
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

用于 Codex CLI
```bash
cp -r skills/prd "$CODEX_HOME/skills/"
cp -r skills/ralph "$CODEX_HOME/skills/"
```
如果未设置 `$CODEX_HOME`，请使用你的 Codex 配置目录（通常是 `~/.codex`）。

### 配置 Amp 自动移交（推荐）

将以下内容添加到 `~/.config/amp/settings.json`：

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

这会在上下文即将用尽时启用自动移交，使 Ralph 能处理超过单次上下文窗口的大型任务。

## 工作流程

### 1. 创建 PRD

使用 PRD 技能生成详细需求文档：

```
Load the prd skill and create a PRD for [your feature description]
```

回答澄清问题。该技能会将输出保存到 `tasks/prd-[feature-name].md`。

### 2. 将 PRD 转换为 Ralph 格式

使用 Ralph 技能将 markdown PRD 转换为 JSON：

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

这会生成 `prd.json`，其中包含用于自动执行的用户故事。

### 3. 运行 Ralph

```bash
# 使用 Amp（默认）
./scripts/ralph/ralph.sh [max_iterations]

# 使用 Claude Code
./scripts/ralph/ralph.sh --tool claude [max_iterations]

# 使用 Codex CLI
./scripts/ralph/ralph.sh --tool codex [max_iterations]

# 使用 OpenCode CLI
./scripts/ralph/ralph.sh --tool opencode [max_iterations]
```

默认迭代次数为 10。使用 `--tool amp`、`--tool claude`、`--tool codex` 或 `--tool opencode` 来选择 AI 编码工具。

Ralph 将执行：
1. 创建功能分支（来自 PRD 的 `branchName`）
2. 选择最高优先级且 `passes: false` 的故事
3. 实现该单个故事
4. 运行质量检查（类型检查、测试）
5. 通过检查后提交
6. 更新 `prd.json` 将该故事标记为 `passes: true`
7. 将学习记录追加到 `progress.txt`
8. 重复上述步骤直到全部通过或达到最大迭代次数

## 关键文件

| 文件 | 用途 |
|------|------|
| `ralph.sh` | 负责启动全新 AI 实例的 bash 循环（支持 `--tool amp`、`--tool claude`、`--tool codex`、或 `--tool opencode`） |
| `prompt.md` | Amp 的提示模板 |
| `CLAUDE.md` | Claude Code 的提示模板 |
| `CODEX.md` | Codex CLI 的提示模板 |
| `OPENCODE.md` | OpenCode CLI 的提示模板 |
| `prd.json` | 带 `passes` 状态的用户故事（任务列表） |
| `prd.json.example` | PRD 格式示例 |
| `progress.txt` | 追加式学习记录，供未来迭代使用 |
| `skills/prd/` | 生成 PRD 的技能 |
| `skills/ralph/` | 将 PRD 转为 JSON 的技能 |
| `flowchart/` | Ralph 工作方式的交互式可视化 |

## 流程图

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[查看交互式流程图](https://snarktank.github.io/ralph/)** - 点击查看每个步骤的动画。

`flowchart/` 目录包含源代码。本地运行：

```bash
cd flowchart
npm install
npm run dev
```

## 关键概念

### 每次迭代 = 全新上下文

每次迭代都会启动一个 **新的 AI 实例**（Amp、Claude Code、Codex CLI 或 OpenCode CLI）并清空上下文。迭代之间唯一的记忆来源是：
- Git 历史（之前迭代的提交）
- `progress.txt`（学习记录与上下文）
- `prd.json`（哪些故事已完成）

### 小任务

每条 PRD 项目应该小到能在一个上下文窗口内完成。如果任务太大，LLM 会在完成前耗尽上下文并产生质量较差的代码。

合适大小的故事：
- 增加数据库字段并迁移
- 在现有页面添加 UI 组件
- 更新 server action 的逻辑
- 给列表增加筛选下拉

过大（请拆分）：
- “构建整个仪表盘”
- “添加认证”
- “重构 API”

### AGENTS.md 更新非常关键

每次迭代结束后，Ralph 会更新相关的 `AGENTS.md` 文件以记录学习内容。这很关键，因为 AI 编码工具会自动读取这些文件，让后续迭代（以及后续的人类开发者）获益于已发现的模式、注意事项和约定。

AGENTS.md 可新增的内容示例：
- 已发现的模式（“此代码库用 X 实现 Y”）
- 注意事项（“修改 W 时不要忘记更新 Z”）
- 有用上下文（“设置面板在组件 X 中”）

### 反馈回路

Ralph 只有在存在反馈回路时才有效：
- 类型检查能捕获类型错误
- 测试验证行为
- CI 必须保持绿色（错误会在迭代中不断叠加）

### UI 故事的浏览器验证

前端故事的验收标准必须包含“Verify in browser using dev-browser skill”。Ralph 会使用 dev-browser 技能打开页面、与 UI 交互并确认修改有效。
