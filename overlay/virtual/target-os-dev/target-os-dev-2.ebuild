# Copyright 2026 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="List of additional packages for the amd64-generic dev image"
HOMEPAGE="http://dev.chromium.org/"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="*"

RDEPEND="
	virtual/target-chromium-os-dev
	chromeos-base/llm-service
"
