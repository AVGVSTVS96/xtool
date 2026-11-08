Clear the profile name xtool is about to use before making its profile, so signing never stops on a 409.

xtool names every development profile `XTL profile <bundle ID's id>`, and Apple refuses a second profile with a name. Upstream deletes the bundle ID's profile only when it lists exactly one, but that list can leave out a profile that went invalid (as profiles do when the team's certificates or distribution setup change), so the new profile clashed with it: "Multiple profiles found with the name 'XTL profile …'". Now the name itself is looked up and every profile holding it is deleted first.

Once upstream clears the name it's about to use, this patch is done.
