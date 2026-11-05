import Foundation
import XKit
import ArgumentParser

struct SignCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "Provision an app for your team and sign it in place, without installing it",
        discussion: """
        Embeds the team's provisioning profiles, and signs with the stored certificate, or ad hoc when that \
        certificate is stored without its key, so whoever holds the key can sign for real. It never revokes \
        a certificate to make its own.
        """
    )

    @Argument(
        help: "The path to a built .app, whose entitlements are the ones it was signed with"
    ) var path: String

    func run() async throws {
        let token = try AuthToken.saved()
        let installer = IntegratedInstaller(
            auth: token.authData(),
            delegate: XToolInstallerDelegate(revokesCertificates: false)
        )
        do {
            defer { print() }
            try await installer.signInPlace(app: URL(fileURLWithPath: path))
        } catch let error as CancellationError {
            throw error
        } catch {
            print("Error: \(error)")
            throw ExitCode.failure
        }
    }
}
