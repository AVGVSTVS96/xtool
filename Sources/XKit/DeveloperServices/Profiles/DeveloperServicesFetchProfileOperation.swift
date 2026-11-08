//
//  DeveloperServicesFetchProfileOperation.swift
//  XKit
//
//  Created by Kabir Oberai on 13/10/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation
import Superutils
import DeveloperAPI

public struct DeveloperServicesFetchProfileOperation: DeveloperServicesOperation {

    public enum Errors: Error {
        case bundleIDNotFound
        case tooManyMatchingBundleIDs
        case invalidProfileData
    }

    public let context: SigningContext
    public let bundleID: String
    public let signingInfo: SigningInfo
    public init(context: SigningContext, bundleID: String, signingInfo: SigningInfo) {
        self.context = context
        self.bundleID = bundleID
        self.signingInfo = signingInfo
    }

    public func perform() async throws -> Mobileprovision {
        let bundleIDs = try await context.developerAPIClient
            .bundleIdsGetCollection(query: .init(
                filter_lbrack_identifier_rbrack_: [bundleID]
            ))
            .ok.body.json

        // filter[identifier] is a prefix filter so we need to manually upgrade to equality
        let filtered = bundleIDs.data.filter { $0.attributes?.identifier == self.bundleID }

        let bundleID: Components.Schemas.BundleId
        switch filtered.count {
        case 0:
            throw Errors.bundleIDNotFound
        case 1:
            bundleID = filtered[0]
        default:
            throw Errors.tooManyMatchingBundleIDs
        }

        // Apple refuses a second profile with a name (409), and the bundle ID's own list of profiles
        // can leave out one that went invalid, so the name is looked up and cleared directly.
        let name = "XTL profile \(bundleID.id)"
        let taken = try await context.developerAPIClient
            .profilesGetCollection(query: .init(filter_lbrack_name_rbrack_: [name], fields_lbrack_profiles_rbrack_: [.name]))
            .ok.body.json.data
        for profile in taken where profile.attributes?.name == name {
            _ = try await context.developerAPIClient.profilesDeleteInstance(path: .init(id: profile.id)).noContent
        }

        // Match locally rather than with filter[serialNumber]: the API lists serials with a
        // leading zero nibble ("0E41…") but its filter only matches them without it ("E41…").
        let certs = try await DeveloperAPIPages {
            try await context.developerAPIClient.certificatesGetCollection().ok.body.json
        } next: {
            $0.links.next
        }
        .map(\.data)
        .reduce(into: [], +=)
        .filter { $0.attributes?.serialNumber.map(signingInfo.certificate.hasSerialNumber) == true }

        let allDevices = try await context.developerAPIClient.devicesGetCollection()
            .ok.body.json.data
            .filter { $0.attributes?.deviceClass?.value1?.supportsIOSApps == true }

        let response = try await context.developerAPIClient.profilesCreateInstance(
            body: .json(
                .init(
                    data: .init(
                        _type: .profiles,
                        attributes: .init(
                            name: name,
                            profileType: .init(.iosAppDevelopment)
                        ),
                        relationships: .init(
                            bundleId: .init(
                                data: .init(_type: .bundleIds, id: bundleID.id)
                            ),
                            devices: .init(data: allDevices.map {
                                .init(_type: .devices, id: $0.id)
                            }),
                            certificates: .init(data: certs.map {
                                .init(_type: .certificates, id: $0.id)
                            })
                        )
                    )
                )
            )
        )
        .created.body.json.data

        guard let contentString = response.attributes?.profileContent,
              let contentData = Data(base64Encoded: contentString)
              else { throw Errors.invalidProfileData }

        return try Mobileprovision(data: contentData)
    }

}

extension Components.Schemas.Device.AttributesPayload.DeviceClassPayload.Value1Payload {
    fileprivate var supportsIOSApps: Bool {
        switch self {
        case .ipad, .iphone, .ipod: true
        default: false
        }
    }
}
