# Adding a Typed CLI Command

Add a first class `dab <resource> <verb>` command when an AppDabKit action should be available from the CLI. Start by following the shared [AppDabKit action guide](https://github.com/AppDab/AppDabKit/blob/main/Documentation/AddingAutomationAction.md).

## Add the command

1. Add a leaf command under `Sources/AppDabCLIKit/Commands` using named Swift Argument Parser options and the action's typed input.
2. Invoke only the shared action through `CLIInvocation.read`, `write`, or `directWrite`. Do not call AppDab services directly from a command.
3. Supply a curated text renderer and retain the shared JSON response envelope. Add or extend the resource group and `RootCommand` registration when needed.

## Verify

Add parser tests for the command path, typed input, and validation failure. Add runner tests for text and JSON output. For guarded writes, cover preview, confirmation, commit, and recovery.

Run:

```sh
swift test
```
