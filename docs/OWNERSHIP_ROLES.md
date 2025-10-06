# Ownership & Control Roles

This document lists the privileged roles and upgrade authorities for every contract in `src/contracts/`. Line references point to the Solidity sources in this repository.

## Upgradeable Contracts

Certain contracts use OpenZeppelin upgradeable patterns. On-chain upgrades are executed by the proxy admin for each deployment. The `owner` recorded in the contract controls runtime functionality but cannot upgrade unless they also control the proxy.

### VoterV3 (`src/contracts/VoterV3.sol`)
- Initializes with `OwnableUpgradeable`, but day-to-day governance routes through `permissionRegistry` roles loaded during `_init` (`:94`, `:136`-`:145`).
- `VOTER_ADMIN` role manages configuration: factories, bribe registry, minter, and permission registry pointer (`:123`-`:210`).
- `GOVERNANCE` role can whitelist/blacklist tokens and kill or revive gauges (`:128`, `:210`-`:244`).
- `minter` set on deployment can run `_init`; post-initialization, minter address is controlled via `VOTER_ADMIN`.

### MinterUpgradeable (`src/contracts/MinterUpgradeable.sol`)
- Initializer assigns deployer as both `owner` and `team` (`:49`-`:53`).
- `_initializer` flag gates a one-off `_initialize` for genesis locks (`:70`-`:86`).
- Ongoing parameters (emission rate, rebase, voter, team rate) are guarded by the `team` key (`:88`-`:119`). Team ownership can be handed off via `setTeam`/`acceptTeam` (`:88`-`:96`).

### PairFactoryUpgradeable (`src/contracts/factories/PairFactoryUpgradeable.sol`)
- Deploy-time initializer sets `owner` and `feeManager` to the deployer (`:40`-`:48`).
- `owner` can pause/unpause pair creation (`:58`-`:61`).
- `feeManager` (with pending/accept flow) configures trading fees and fee recipients (`:63`-`:99`).

### BribeFactoryV3 (`src/contracts/factories/BribeFactoryV3.sol`)
- `owner` may update the linked voter, permissions registry, and default reward token list (`:74`-`:107`).
- `owner` also orchestrates bulk bribe maintenance and ERC20 recoveries (`:150`-`:200`).
- Runtime operations are shared with addresses holding the `BRIBE_ADMIN` role in `PermissionsRegistry` via `onlyAllowed` (`:27`-`:29`, `:117`-`:148`).

### GaugeFactoryV2 (`src/contracts/factories/GaugeFactoryV2.sol`)
- `owner` manages the pointer to `permissionsRegistry` (`:32`-`:35`).
- Addresses with `GAUGE_ADMIN` (configured in `PermissionsRegistry`) can retarget distribution addresses, rewarders, and internal bribes (`:60`-`:116`).
- `EmergencyCouncil` (also resolved via the registry) can toggle emergency mode on gauges (`:68`-`:84`).

### VeArtProxyUpgradeable (`src/contracts/VeArtProxyUpgradeable.sol`)
- Minimal upgradeable proxy. `owner` is set at initialization (`:12`-`:14`) and can be transferred using inherited Ownable functions. No additional privileged setters are defined.

## Non-Upgradeable Contracts

### Bribe (`src/contracts/Bribes.sol`)
- Constructor hard-codes `owner`, `voter`, and `bribeFactory` (`:46`-`:55`).
- Administrative actions (adding rewards, recovering ERC20, rotating voter/minter/owner) require `owner` or `bribeFactory` via `onlyAllowed` (`:338`-`:405`).
- Only the linked `voter` may call vote deposit/withdraw helpers (`:212`-`:300`).

### GaugeV2 (`src/contracts/GaugeV2.sol`)
- Factory deployer becomes `owner` (`:73`-`:94`).
- `owner` controls distribution endpoint, rewarder integrations, bribe pointers, and emergency mode switches (`:104`-`:133`).
- Reward streaming functions remain restricted to the `DISTRIBUTION` address (the voter) via `onlyDistribution` (`:63`-`:71`).

### PermissionsRegistry (`src/contracts/PermissionsRegistry.sol`)
- Central registry records three governance keys set to the deployer by default (`:36`-`:39`):
  - `lithosMultisig`: may add/remove roles and assign them (`:71`-`:149`).
  - `lithosTeamMultisig`: can rotate the team multisig address (`:213`-`:222`).
  - `emergencyCouncil`: can rotate its own key (shared with `lithosMultisig`) and is referenced by other contracts for emergency powers (`:202`-`:212`).
- `hasRole` lookups are consumed by Voter, Gauge Factory, and Bribe Factory for fine-grained access control.

### RewardsDistributor (`src/contracts/RewardsDistributor.sol`)
- Stores deployer as both `owner` and `depositor` (`:39`-`:49`).
- Only the `depositor` can checkpoint new rewards (`:89`-`:92`).
- `owner` can rotate depositor/ownership or sweep arbitrary ERC20 balances (`:331`-`:345`).

### Lithos (`src/contracts/Lithos.sol`)
- Maintains a single `minter` key (`:21`-`:36`).
- `minter` executes the one-time initial mint and controls any subsequent minting or minter rotation (`:26`-`:78`).

### VotingEscrow (`src/contracts/VotingEscrow.sol`)
- `team` and `voter` default to the deployer (`:62`).
- `team` can set a new team address or art proxy, and is the only caller allowed to pick a new `voter` (`:135`-`:142`, `:1026`-`:1029`).
- `voter` (usually `VoterV3`) manages vote attachment and abstain state (`:1031`-`:1048`).

### PairFactory (`src/contracts/factories/PairFactory.sol`)
- `pauser` may toggle pool creation and can hand off the role (`:50`-`:63`).
- `feeManager` manages all fee and referral settings with its own pending/accept flow (`:65`-`:107`).

### Pair (`src/contracts/Pair.sol`)
- No dedicated owner. All configurable parameters are pulled from the associated factory (`:152`, `:173`). Governance flows entirely through `PairFactory` roles.

### PairFees (`src/contracts/PairFees.sol`)
- Only the bound `Pair` contract can move funds (`:18`-`:45`); there is no human-controlled privileged key.

### GlobalRouter (`src/contracts/GlobalRouter.sol`), RouterV2 (`src/contracts/RouterV2.sol`), TradeHelper (`src/contracts/TradeHelper.sol`)
- Stateless helper/router contracts; they expose no access-controlled or owner-only functions.

## Upgrade Authority Reminder
For every upgradeable contract above, ensure deployment records include the proxy admin address. Controlling the proxy admin is mandatory to ship new implementations, regardless of the `owner` stored in the logic contract.
