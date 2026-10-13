//
//  DeveloperServicesAssignAppGroupsOperation.swift
//  XKit
//
//  Created by Kabir Oberai on 14/10/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation
import DeveloperAPI

public struct DeveloperServicesAssignAppGroupsOperation: DeveloperServicesOperation {

    public let context: SigningContext
    public let groupIDs: [DeveloperServicesAppGroup.GroupID]
    public let appID: Components.Schemas.BundleId
    public let xcodeAuthData: XcodeAuthData

    private let client: DeveloperServicesClient

    public init?(
        context: SigningContext,
        groupIDs: [DeveloperServicesAppGroup.GroupID],
        appID: Components.Schemas.BundleId
    ) {
        self.context = context
        self.groupIDs = groupIDs
        self.appID = appID

        guard case .xcode(let authData) = context.auth else { return nil }
        self.xcodeAuthData = authData

        self.client = DeveloperServicesClient(authData: authData)
    }

    private func upsertAppGroup(
        _ groupID: DeveloperServicesAppGroup.GroupID,
        existingGroups: [DeveloperServicesAppGroup]
    ) async throws -> DeveloperServicesAppGroup.GroupID {
        let sanitized = ProvisioningIdentifiers.sanitize(groupID: groupID)
        let ownID = ProvisioningIdentifiers.ownGroupID(fromSanitized: sanitized)
        let prefixedID = ProvisioningIdentifiers.groupID(fromSanitized: sanitized, context: context)
        let group: DeveloperServicesAppGroup
        if let existingGroup = existingGroups.first(where: { $0.groupID == ownID })
            ?? existingGroups.first(where: { $0.groupID == prefixedID }) {
            group = existingGroup
        } else {
            let name = ProvisioningIdentifiers.groupName(fromSanitized: sanitized)
            do {
                group = try await addAppGroup(ownID, name: name)
            } catch let error as DeveloperServicesAPIVersionLegacy.Error where error.code == 35 {
                // 35 is Apple's catch-all for an invalid group ID, including one another team owns
                group = try await addAppGroup(prefixedID, name: name)
            }
        }

        _ = try await client.send(
            DeveloperServicesAssignAppGroupRequest(
                platform: .iOS,
                teamID: xcodeAuthData.teamID,
                appIDID: appID.id,
                groupID: group.id
            )
        )

        return group.groupID
    }

    private func addAppGroup(
        _ groupID: DeveloperServicesAppGroup.GroupID,
        name: String
    ) async throws -> DeveloperServicesAppGroup {
        try await client.send(DeveloperServicesAddAppGroupRequest(
            platform: .iOS,
            teamID: xcodeAuthData.teamID,
            name: name,
            groupID: groupID
        ))
    }

    public func perform() async throws -> [DeveloperServicesAppGroup.GroupID] {
        let existing = try await client.send(DeveloperServicesListAppGroupsRequest(
            platform: .iOS, teamID: xcodeAuthData.teamID
        ))
        return try await withThrowingTaskGroup(of: DeveloperServicesAppGroup.GroupID.self) { group in
            for groupID in groupIDs {
                group.addTask {
                    try await upsertAppGroup(groupID, existingGroups: existing)
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }

}
