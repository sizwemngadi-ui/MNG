# AGENTS.md

## Project overview

This repository is an **MQL5 / MetaTrader 5 (MT5) algorithmic-trading project** targeting
Deriv's synthetic **Crash 300 Index** and **Crash 500 Index** instruments. It contains two
kinds of products:

1. **ATR-level alert scripts/indicators** — pop up MT5 alerts (and optional push
   notifications) when ATR(14) reaches a configured level.
2. **"Sell" Expert Advisors (EAs)** — automated trading bots that open SELL positions on
   Crash 300/500.

### Where the code lives

The default branch (`main`) contains **only `.gitignore`** — there is no application code on
`main`. All `.mq5` source files live on feature branches:

| Branch | File(s) | Type |
|---|---|---|
| `cursor/mt5-atr-alert-d98b` | `ATR_Level_Alert_Crash300_500.mq5` | Alert script |
| `cursor/mt5-atr-alert-e0ba` | `Crash300_ATR_Alert.mq5` | Alert script |
| `cursor/mt5-sell-ea-crash-472c` | `CrashSellPerBarEA.mq5`, `CrashSellEveryCandle_Modified.mq5` | Expert Advisors |

To work on the product code, check out the relevant feature branch.

## Tech stack & toolchain

- **Language:** MQL5 (MetaQuotes Language 5, a C/C++-like language proprietary to MT5).
- **Compiler / IDE:** **MetaEditor** (`metaeditor64.exe`), which ships bundled with the
  MetaTrader 5 terminal. There is no standalone MQL5 compiler.
- **Runtime:** the **MetaTrader 5 terminal** connected to a broker (e.g. Deriv) that offers
  the Crash 300/500 symbols.
- **No conventional dev tooling exists**: there is no package manager, no `package.json` /
  `requirements.txt` / `Makefile`, no automated test suite, no linter, and no Linux build
  pipeline. (The committed `.gitignore` is a leftover Node/GitBook template and is unrelated
  to the actual product.)

### Build / lint / test / run (these are GUI/Windows operations)

- **Build (compile):** open a `.mq5` file in MetaEditor and press **F7**, or use the CLI
  `metaeditor64.exe /compile:"<file>.mq5" /log`. Output is a `.ex5` binary. The standard
  library include `<Trade/Trade.mqh>` used by the EAs ships with the terminal under
  `MQL5/Include`.
- **Lint:** there is no separate linter; MetaEditor's compiler warnings/errors (files use
  `#property strict`) are the only static checks.
- **Run / test:** attach the compiled script/EA to a Crash 300/500 chart in the MT5 terminal
  (enable **AlgoTrading** for EAs), or use the **MT5 Strategy Tester** to backtest against
  historical data. A **Deriv demo account** is sufficient and avoids real financial loss.

## Cursor Cloud specific instructions

These notes are for future cloud agents running on the Linux Cloud Agent VM.

- **There are no dependencies to install for this repo.** `main` is empty apart from
  `.gitignore`, and the product has no package manifest. The startup update script is
  intentionally a no-op. Do not add language/package-manager installs.
- **The MetaTrader 5 toolchain cannot run on this Linux VM.** MetaEditor and the MT5 terminal
  are Windows GUI applications. Installing them via **Wine fails**: the MT5 installer
  (`mt5setup.exe`) has anti-debugger protection (`IsDebuggerPresent`) that falsely triggers
  under Wine and shows *"A debugger has been found running in your system"*, then exits.
  This was reproduced with Wine 11.0 (stable) using silent install, GUI install, a fresh
  prefix, disabling the `AeDebug` handler, `WINEDEBUG=-all`, and DLL overrides — none worked.
  Do **not** sink time into a Wine-based MT5 setup here; it is a known dead end in this
  environment.
- **Consequently, compiling (`.mq5` → `.ex5`), linting, and running the EAs/alerts cannot be
  done on this VM.** These must be done on a real Windows machine (or a Wine configuration
  that defeats MT5's anti-debug, which is not available here) with MetaTrader 5 installed.
- **Running the product end-to-end additionally requires a broker connection.** A Deriv (or
  equivalent) account that offers the Crash 300/500 Index symbols is needed for live data and
  for the Strategy Tester history. Credentials would need to be supplied as secrets.
- ⚠️ The Expert Advisors place **live SELL trades**. Only ever test them on a **demo
  account**.
