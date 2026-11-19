import Foundation

func testKeychainAuthorizationResponses() throws {
    // The response emitted by accounts list when SecItemCopyMatching returns errSecMissingEntitlement.
    let expected = Data(#"{"error":{"code":"upstream_error","message":"Could not read from Keychain (OSStatus: -34018)"}}"#.utf8)
    try requireKeychainAuthorizationFailure(Result(status: 1, terminationReason: .exit, output: Data(), error: expected))

    let invalidResults = [
        Result(status: 0, terminationReason: .exit, output: Data(), error: expected),
        Result(status: 2, terminationReason: .exit, output: Data(), error: expected),
        Result(status: 137, terminationReason: .exit, output: Data(), error: expected),
        Result(status: SIGKILL, terminationReason: .uncaughtSignal, output: Data(), error: expected),
        Result(status: SIGABRT, terminationReason: .uncaughtSignal, output: Data(), error: expected),
        Result(status: 1, terminationReason: .uncaughtSignal, output: Data(), error: expected),
        Result(status: 1, terminationReason: .exit, output: Data("unexpected output".utf8), error: expected),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data()),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data("unrelated CLI error".utf8)),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data("{}".utf8)),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data(#"{"error":{"code":"upstream_error","message":"Could not read from Keychain (OSStatus: -25293)"}}"#.utf8)),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data(#"{"error":{"code":"upstream_error","message":"Network request failed"}}"#.utf8)),
        Result(status: 1, terminationReason: .exit, output: Data(), error: Data(#"{"error":{"code":"authentication_failed","message":"Could not read from Keychain (OSStatus: -34018)"}}"#.utf8)),
    ]
    for (index, result) in invalidResults.enumerated() {
        do {
            try requireKeychainAuthorizationFailure(result)
        } catch is Failure {
            continue
        }
        throw Failure("Authorization verification accepted invalid response fixture \(index).")
    }
}

func testKeychainVerificationCrash() throws {
    // Even a process that emits the expected JSON before crashing must fail verification.
    let result = try run([
        "/bin/sh", "-c",
        #"printf '%s' '{"error":{"code":"upstream_error","message":"Could not read from Keychain (OSStatus: -34018)"}}' >&2; kill -KILL $$"#,
    ], capture: true, allowFailure: true, timeout: 5)
    guard result.terminationReason == .uncaughtSignal, result.status == SIGKILL else {
        throw Failure("The process runner did not preserve signal termination.")
    }
    do {
        try requireKeychainAuthorizationFailure(result)
    } catch is Failure {
        return
    }
    throw Failure("Authorization verification accepted a crashed process.")
}
