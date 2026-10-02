################################################################################
#
# uv
#
################################################################################

UV_VERSION = 0.12.22
UV_SITE = https://github.com/astral-sh/uv/releases/download/$(UV_VERSION)
UV_SOURCE = uv-armv7-unknown-linux-gnueabihf.tar.gz
# Release tarball ships no license files; see the repository for the
# dual MIT/Apache-2.0 licensing.
UV_LICENSE = MIT or Apache-2.0

define UV_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/uv $(TARGET_DIR)/usr/bin/uv
	$(INSTALL) -D -m 0755 $(@D)/uvx $(TARGET_DIR)/usr/bin/uvx
endef

$(eval $(generic-package))
