# Adding a Typed CLI Command

Every registered AppDabKit action must have a first class `dab <resource> <verb>` command. Start by following the shared [AppDabKit action guide](https://github.com/AppDab/AppDabKit/blob/main/Documentation/AddingAutomationAction.md).

## Add the command

1. Add a leaf command under `Sources/AppDabCLIKit/Commands` that conforms to `TypedAutomationCLICommand`.
2. Set `actionID` to the shared action ID and `actionPath` to the flat command path. Use named Swift Argument Parser options and construct the action's typed input.
3. Invoke only the shared action through `CLIInvocation.read`, `write`, or `directWrite`. Do not call AppDab services directly from a command.
4. Supply a curated text renderer and retain the shared JSON response envelope. Add or extend the resource group and `RootCommand` registration when needed.
5. Add the command type to `AutomationCLIActionCatalog.all` in the same order as `AutomationRegistry.standard`.

## Verify

Add parser tests for the command path, typed input, and validation failure. Add runner tests for text and JSON output. For guarded writes, cover preview, confirmation, commit, and recovery.

Run:

```sh
swift test
```

The catalog test parses one valid invocation for every registered action and fails when a typed command is missing.
