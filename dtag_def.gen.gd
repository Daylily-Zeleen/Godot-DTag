# NOTE: This file is generated, any modify maybe discard.
class_name DTagDef


## Tag without domain
const TagWithoutDomain = &"TagWithoutDomain"

## Tag without domain1
const TagWithoutDomain1 = &"TagWithoutDomain1"

## Desc
@abstract class MainDomain extends Object:
	## StringName of this domain.
	const DOMAIN_NAME = &"MainDomain"
	## Desc
	const Tag1 = &"RedirectTo.New.Tag"

	## Desc
	@abstract class Domain extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"RedirectTo.New.Domain"
		## Will be redirected to "RedirectTo.New.Domain.Tag2"
		const Tag2 = &"RedirectTo.New.Domain.Tag2"
		## Will be redirected to "RedirectTo.New.Domain.Tag3"
		const Tag3 = &"RedirectTo.New.Domain.Tag3"


## Sample redirect domain.
@abstract class RedirectTo extends Object:
	## StringName of this domain.
	const DOMAIN_NAME = &"RedirectTo"

	@abstract class New extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"RedirectTo.New"
		const Tag = &"RedirectTo.New.Tag"

		@abstract class Domain extends Object:
			## StringName of this domain.
			const DOMAIN_NAME = &"RedirectTo.New.Domain"
			const Tag1 = &"RedirectTo.New.Domain.Tag1"
			const Tag2 = &"RedirectTo.New.Domain.Tag2"
			const Tag3 = &"RedirectTo.New.Domain.Tag3"


# ===== Redirect map. =====
const _REDIRECT_NAP: Dictionary[StringName, StringName] = {
	&"MainDomain.Tag1" : &"RedirectTo.New.Tag",
	&"MainDomain.Domain" : &"RedirectTo.New.Domain",
	&"MainDomain.Domain.Tag2" : &"RedirectTo.New.Domain.Tag2",
	&"MainDomain.Domain.Tag3" : &"RedirectTo.New.Domain.Tag3",
}
