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
