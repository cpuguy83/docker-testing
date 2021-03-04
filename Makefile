OUTPUT ?= bin
export OUTPUT

PROJECTS := engine

DOCKERFILES := $(foreach project,$(PROJECTS),$(wildcard $(project)/*/Dockerfile.*))

# Creates a target for building our Dockerfile.
define build_dockerfile_rule
$1: output := $(OUTPUT)/$(dir $1)$(subst Dockerfile.,,$(notdir $1))
$1: $(dir $1)
	docker buildx build -f $(1) --output $$(OUTPUT)/$(dir $1)$(subst Dockerfile.,,$(notdir $1)) $(dir $1)

# These rules are just convenience
.PHONY: $(OUTPUT)/$(dir $1)$(subst Dockerfile.,,$(notdir $1))
$$(OUTPUT)/$(dir $1)$(subst Dockerfile.,,$(notdir $1)): $1

.PHONY: $(dir $1)$(subst Dockerfile.,,$(notdir $1))
$(dir $1)$(subst Dockerfile.,,$(notdir $1)): $1
endef

# Generate rules for each dockerfile
$(foreach f,$(DOCKERFILES),$(eval $(call build_dockerfile_rule,$(f))))
.PHONY: $(DOCKERFILES)

 all: $(DOCKERFILES)