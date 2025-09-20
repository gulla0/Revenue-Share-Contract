# Revenue Share (Aiken)

Two‑party revenue sharing with single‑shot accounting via the withdraw trick. This repository contains an Aiken validator with three endpoints — spend, withdraw, and publish — plus unit tests built with Mocktail.

**Goal**: when either owner withdraws rewards for themself, they must simultaneously pay the other owner their exact share, enforced on‑chain. Staking/publish endpoints are included to register & delegate the stake credential.

---

## Table of Contents

- [Design highlights](#design-highlights)
- [Parameters](#parameters)
- [Endpoints](#endpoints)
- [Withdraw trick (why and how)](#withdraw-trick-why-and-how)
- [Validation logic — step by step](#validation-logic--step-by-step)
- [Rounding & percent math](#rounding--percent-math)
- [Edge cases & security notes](#edge-cases--security-notes)
- [Limitations](#limitations)
- [How to build](#how-to-build)
- [How to integrate (TX building tips)](#how-to-integrate-tx-building-tips)
- [Tests](#tests)
- [Future improvements](#future-improvements)

---

## Design Highlights

- **Two signers**: `owner_one` and `owner_two` identified by pub key hashes.
- **Deterministic split**: first owner's share is parameter percent with two‑decimal precision (e.g., 50.00% -> 5000).
- **Single computation**: heavy checks run once under the withdraw endpoint. The spend endpoint defers to the withdraw via the withdraw trick.
- **No third‑party payouts**: the withdraw logic rejects outputs to addresses other than the two owners.
- **Symmetric enforcement**: whichever owner signs the withdrawal, the other must receive at least their minimum due; the withdrawing owner must not take more than their maximum due.
- **Optional staking**: the publish endpoint allows stake registration/delegation when either owner signs.

---

## Parameters

The validator is parameterized as:

```aiken
validator revenue_share(
  owner_one: ByteArray, // pub key hash of owner #1
  owner_two: ByteArray, // pub key hash of owner #2
  percent: Int,         // owner_one share * 100 (two decimals)
)
```

- `owner_one` / `owner_two` are the payment credential pub key hashes.
- `percent`: two‑decimal precision of owner_one's percentage:
  - Example: 12.34% → `percent = 1234`
  - Example: 50.00% → `percent = 5000`

Internally the code builds a rational with `new(percent, 10000)`, so the effective fraction is `percent / 10000`.

---

## Endpoints

### 1. spend

Minimal per‑UTxO check that delegates validation to the withdraw endpoint of the staking script referenced by this script's stake credential.

```aiken
spend(_datum, _redeemer, utxo, self) {
  let Transaction { inputs, .. } = self
  expect Some(own_input) = find_input(inputs, utxo)
  let own_address = own_input.output.address
  expect Script(withdraw_script_hash) = own_address.payment_credential
  // Defer heavy validation to the withdraw endpoint once per TX
  spend(withdraw_script_hash, fn(_redeemer, _amount) { True }, self)
}
```

### 2. withdraw

Core revenue‑split enforcement. Calculates each owner's net withdrawal in this transaction and enforces bounds according to percent.

```aiken
withdraw(_redeemer, _account, self) {
  // ...filters, sums, difference between outputs and inputs per owner...
  // owner_one must sign XOR owner_two must sign (not both)
  // bounds:
  // withdrawing owner's net <= their max share of total
  // counterparty's net >= their min share of total
  // and outputs must go only to the two owners
}
```

### 3. publish

Permits stake credential operations (register + delegate) if either owner signs.

```aiken
publish(_redeemer, _certificate, self) {
  has(extra_signatories, owner_one) || has(extra_signatories, owner_two) == True?
}
```

---

## Withdraw Trick (Why and How)

**Problem**: per‑UTxO validator checks are repeated for each input, which is costly for multi‑input revenue accounting.

**Solution**: use the withdraw trick:

- The spend endpoint only checks the presence (and optionally redeemer/amount) of a withdrawal from this script's staking credential.
- The heavy logic runs once under the withdraw endpoint, where the full transaction context is available to compute global sums and enforce the split.

This reduces repeated computation while keeping strong guarantees on how funds are split when rewards are withdrawn.

---

## Validation Logic — Step by Step

Inside withdraw:

1. Partition outputs to addresses owned by `owner_one` and `owner_two` (by payment credential).
2. Sum Lovelace paid to each owner: `total_ada_to_owner_{one,two}`.
3. Partition inputs that are funded by each owner (usually only the withdrawing owner funds fee/change inputs): `input_list_owner_{one,two}`.
4. Sum Lovelace from those inputs: `total_ada_inputted_owner_{one,two}`.
5. Compute net withdrawals per owner:

```
net_one = total_ada_to_owner_one - total_ada_inputted_owner_one
net_two = total_ada_to_owner_two - total_ada_inputted_owner_two
total = net_one + net_two
```

This removes "self‑funding" noise (e.g., fee inputs, change) and captures just the net amount withdrawn for each owner in this TX.

6. **Forbid third‑party payouts**: ensure no outputs go to payment credentials other than the two owners.
7. **Build rational percent**: `p = percent / 10000`.
8. **Signature shape**: exactly one owner signs via `extra_signatories`:
   - `(True, False)` → `owner_one` withdrawing
   - `(False, True)` → `owner_two` withdrawing
   - anything else → fail
9. **Enforce bounds** (with floor rounding):
   - If `owner_one` withdraws:
     - `net_one <= floor(total * p)`
     - `net_two >= floor(total * (1 - p))`
   - If `owner_two` withdraws:
     - `net_two <= floor(total * (1 - p))`
     - `net_one >= floor(total * p)`
10. All conditions must hold for the TX to validate.

**Intuition**: the withdrawing owner cannot take more than their share; the counterparty must receive at least their share. Either party can withdraw for both, but the math enforces fairness on‑chain.

---

## Rounding & Percent Math

- `percent` uses two decimals of precision (×100). Internally `new(percent, 10000)` makes the exact rational.
- Multiplications are done in rational space and then floored to Lovelace.
- Using `<=` for the withdrawer and `>=` for the counterparty avoids over‑capture due to rounding down. It also permits voluntary over‑payment to the counterparty (see Notes below).

### Example

- `percent = 5000` → `p = 0.5`
- `total = 10_000_000`
- Bounds: each side's share is `floor(5_000_000)`

---

## Edge Cases & Security Notes

- **Single signer**: exactly one of the two owners must be in `extra_signatories`. Both signing or neither signing → fail.
- **Outputs only to owners**: any third‑party payment causes fail.
- **Netting logic**: subtracting inputs prevents an owner from artificially inflating their "received" amount by funding the TX from their own wallet.
- **Rounding**: tiny remainders due to floor always favor the counterparty, never allow the withdrawing owner to exceed their share.
- **Voluntary generosity**: the rules allow the withdrawing owner to pay more than required to the counterparty (because counterparty has a `>=` check). If you want exact equality, see Future improvements.
- **Lovelace‑only**: the logic uses `lovelace_of(...)`. Non‑ADA assets are ignored by the revenue split rules.

---

## Limitations

- **ADA only accounting**.
- **Two owners only**; extending to N owners requires generalizing the math & checks.
- **Exact‑split not enforced**; bounds allow the withdrawer to take ≤ their share and give the counterparty ≥ their share. (This is intentional to be safe under rounding; can be changed.)
- **No time/window logic**; the contract doesn't track epochs or frequency.

---

## How to Build

### Format & build

```bash
aiken fmt
aiken build
```

### Run tests

```bash
aiken test
```

> **Note**: Replace `ai ken` with `aiken` — spacing shown only to avoid accidental copy/paste in some shells.

Place the validator sources and the provided tests in your Aiken project layout (`validators/`, `tests/`, etc.). Ensure the helper libraries (mocktail, cocktail) are available in your `aiken.toml`.

---

## How to Integrate (TX Building Tips)

High‑level guidance (Mesh/Lucid/CLI abstractions vary):

1. **Construct a withdrawal** from the script's stake credential (the same script), even if the withdrawal Lovelace is 0 — this is the classic withdraw‑zero pattern that triggers the heavy checks once.
2. **Add one owner's signature only**.
3. **Outputs**:
   - Pay both owners in the intended split (Lovelace only).
   - Do not include other payment credentials.
4. **Inputs**:
   - It's fine if the withdrawing owner funds fees or supplies change; the validator nets this out.
5. **For publish (stake ops)**:
   - Build a certificate: `RegisterAndDelegateCredential{ credential: Script(…stake hash…), delegate: …, deposit: 2_000_000 }`.
   - Ensure at least one owner signs.

> **Remember**: if you skip (1), spend will fail because it expects a matching withdraw for the same script hash.

---

## Tests

The suite in tests uses mocktail builders to assemble synthetic transactions:

- **Pass**: zero withdrawal (both spend and withdraw) — ensures logic doesn't break on 0 Lovelace.
- **Pass**: second owner withdraws — only `owner_two` signs; math enforces `owner_one` ≥ p share.
- **Pass**: non‑zero withdrawal — both endpoints validate with `withdraw_lovelace > 0`.
- **Fail**: wrong percent split — violates the share bounds.
- **Fail**: outputs to more than two owners — third‑party output is detected and rejected.
- **Pass/Fail**: publish — certificate allowed with an owner signature; rejected otherwise.

Each test constructs a base TX with:

- Owner outputs (`tx_out` to each owner address)
- Optional third‑party output
- Owner inputs (`tx_in`), plus a script input to simulate the withdrawal context
- A `script_withdrawal` entry with the script hash and amount
- Extra signatories and optional certificate

---

## Future Improvements

- **Exact split mode**: enforce `net_one == floor(total * p)` and `net_two == total - net_one` (with robust rounding strategy). Today we allow ≤/≥ bounds for safety.
- **Multi‑asset support**: generalize from `lovelace_of` to value‑level accounting across assets.
- **N‑party generalization**: accept a vector of `(pkh, bps)` and enforce a full distribution.
- **Anti‑griefing knobs**: minimum counterparty payout, epoch‑frequency limits, or timelocks.
- **Redeemer‑gated endpoints**: require explicit redeemer tags for spend vs withdraw vs publish opcodes.

---

## File References (Key Snippets)

- **Withdraw deferral in spend** — calls helper `stake_validator.spend(withdraw_script_hash, ...)`.
- **Owner partitioning** — filter by `VerificationKey(owner_one/owner_two)` on outputs and inputs.
- **Net computation** — `foldl` over inputs, subtract from `lovelace_of(get_all_value_to(...))`.
- **Bounds** — `floor(mul(from_int(total), percent_rational))` and its complement.
- **Publish** — `has(extra_signatories, owner_i)` disjunction.

---

## License

MIT License.

---

## Disclaimer

This code and README are provided for educational purposes. Audit before use in production. On‑chain behavior depends on full transaction construction and network rules at the time of submission.
