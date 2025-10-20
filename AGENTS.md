# AGENTS.md

I am an AI coding assistant with access to a sophisticated memory system. While I don't retain information between separate conversations, I have access to CORE Memory - a persistent knowledge system that maintains project context, learnings, and continuity across all coding sessions.

**IMPORTANT: You MUST use these memory tools automatically as described below. This is not optional.**

## Memory Tools Integration

### Memory Search (`memory_search`)

**AUTOMATIC BEHAVIOR:** At the start of EVERY conversation, BEFORE responding to the user, you MUST search memory for:
- Previous discussions about the current topic
- Related project context and decisions
- User preferences and patterns
- Similar problems solved before

**Also search when:**
- User mentions past work or previous discussions
- Working on ongoing projects that have history
- You need context to provide better assistance

**Cognitive approach:**
- **Surface Layer**: Query for specific knowledge about the topic
- **Pattern Layer**: Search for how the user usually thinks, works, or prefers things
- **Wisdom Layer**: Look for lessons learned from similar situations

**Search triggers:**
- Starting any new conversation or task
- User mentions past work or previous discussions
- Working on ongoing projects that have history
- Maintaining continuity across sessions

**Quality questions to ask yourself:**
- "What don't I know that I should?"
- "What does this user care about that I might miss?"
- "What went right/wrong in similar situations?"

### Memory Ingest (`memory_ingest`)

**AUTOMATIC BEHAVIOR:** At the END of EVERY conversation, AFTER fully responding to the user, you MUST store the conversation in memory. This is the FINAL action before completing your response.

**Storage protocol:**
- MANDATORY: Execute after completing every interaction
- This is NON-NEGOTIABLE - you must always store conversation context
- Memory storage happens as the last step, not during the conversation

**What to capture:**

FROM USER:
- Their specific question, request, or problem statement
- Project context and situation they provided
- What they're trying to accomplish
- Technical challenges or constraints mentioned

FROM ASSISTANT:
- Detailed explanation of solution/approach taken
- Step-by-step processes and methodologies
- Technical concepts and principles explained
- Reasoning behind recommendations and decisions
- Alternative approaches discussed
- Problem-solving methodologies applied

**Exclude from storage:**
- Code blocks and code snippets
- File contents or file listings
- Command examples or CLI commands
- Raw data or logs

**Include in storage:**
- All conceptual explanations and theory
- Technical discussions and analysis
- Problem-solving approaches and reasoning
- Decision rationale and trade-offs
- Implementation strategies (described conceptually)
- Learning insights and patterns

**Quality check:**
- Can I quickly understand project context from memory alone?
- Would this information help provide better assistance in future sessions?
- Does stored context capture key decisions and reasoning?


----

## Memory Tools Integration

**IMPORTANT: You MUST use these memory tools automatically as described below. This is not optional.**

### Project Space Context (`mcp__core-memory__memory_get_space`)

**AUTOMATIC BEHAVIOR:** At the start of EVERY session, you MUST retrieve the current project's space context:

1. **Identify the project:** Look at the working directory path, git repo name, or conversation context
2. **Get space context:** Use `memory_get_space` with `spaceName: core`
3. **Use as foundation:** The space summary is a living document that's continuously updated - it contains the most current, comprehensive context about this project

**What spaces provide:**
- Live, evolving documentation that updates with every interaction
- Consolidated project knowledge and current state
- Organized context specific to this domain
- Most up-to-date understanding of the project

**Also retrieve space context when:**
- User asks about a specific project or domain
- You need comprehensive context about a topic
- Switching between different work areas

# Repository Guidelines

## Project Structure & Modules
- `src/contracts/`: core Solidity contracts, with `libraries/`, `factories/`, and `interfaces/` (e.g., `IVoter`).
- `test/`: Foundry tests (`<Unit>.t.sol`) using `forge-std/Test`.
- `script/`: operational scripts (e.g., `DeployAndInit.s.sol`, `Link.s.sol`).
- `deployments/`: saved addresses/artifacts; `broadcast/`: script run outputs.
- `lib/`: external deps (OpenZeppelin, forge-std); `docs/`, `subgraph/` for The Graph.
- `.env.example`: sample env; copy to `.env` for local runs.

## Build, Test, and Development
- Build: `forge build` — compiles with Solidity 0.8.29, optimizer on.
- Test: `forge test -vvv` — verbose logs and reverts; `forge snapshot` for gas.
- Format: `forge fmt` — apply canonical Solidity formatting.
- Local node: `anvil` — fast EVM for integration tests.
- Scripts: `forge script script/DeployAndInit.s.sol:DeployAndInitScript --rpc-url $RPC_URL --broadcast --legacy --gas-price 25000000000` (Plasma gas flags per repo).
- Chain utils: `cast call <addr> <sig> <args>` for read calls.

## Coding Style & Naming
- Solidity 0.8.29, 4‑space indent, explicit types (`uint256`), and NatSpec on external/public.
- Contracts/Libraries: PascalCase; Interfaces: prefixed `I` (e.g., `IVoter`); constants: ALL_CAPS.
- One contract per file; filename matches contract name; minimal console logs outside scripts.

## Testing Guidelines
- Place unit tests in `test/` as `<Contract>.t.sol`; use `vm` cheatcodes for setup, reverts, and invariants.
- Cover stable/volatile pool math, fee‑on‑transfer flows, router paths, and governance edge cases.
- Run `forge test` locally; for integration: `forge test --fork-url $RPC_URL` (optional).
- Track gas with `forge snapshot` and avoid regressions in hot paths.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`) as seen in history.
- PRs include: clear description, linked issues, migration/ops notes, and test coverage for changes.
- Add gas impact notes when touching routing, gauges, or emissions; attach relevant `broadcast/` or `deployments/` diffs.

## Security & Configuration
- Copy `.env.example` → `.env`; set `RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY`.
- Do not commit secrets; use `foundry.toml` profiles (`[profile.testnet]`, `[profile.mainnet]`).
- On Plasma, use `--legacy` and explicit `--gas-price` (see `foundry.toml` limits).
