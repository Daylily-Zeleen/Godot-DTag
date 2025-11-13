# NOTE: This file is generated, any modify maybe discard.
class_name DTagDef


@abstract class TopLevelDomain extends Object:
	## StringName of this domain.
	const DOMAIN_NAME = &"TopLevelDomain"

	@abstract class SubDomain1 extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"TopLevelDomain.SubDomain1"
		const Tag1 = &"TopLevelDomain.SubDomain1.Tag1"
		const Tag2 = &"TopLevelDomain.SubDomain1.Tag2"

	@abstract class Subdomain2 extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"TopLevelDomain.Subdomain2"
		const Tag1 = &"TopLevelDomain.Subdomain2.Tag1"
		const Tag2 = &"TopLevelDomain.Subdomain2.Tag2"


# ===== Redirect map. =====
const _REDIRECT_NAP: Dictionary[StringName, StringName] = {}