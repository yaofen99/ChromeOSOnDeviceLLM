# Copyright 2026 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cmake flag-o-matic

DESCRIPTION="Offline LLM inference service with llama.cpp and Qwen2.5"
HOMEPAGE="https://github.com/ggerganov/llama.cpp"

# llama.cpp version and model
LLAMA_CPP_VERSION="b8279"
MODEL_NAME="qwen2.5-1.5b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/${MODEL_NAME}"

SRC_URI="
	https://github.com/ggml-org/llama.cpp/archive/refs/tags/${LLAMA_CPP_VERSION}.tar.gz -> llama.cpp-${LLAMA_CPP_VERSION}.tar.gz
	${MODEL_URL}
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="*"

# Don't use ChromiumOS mirrors - download directly from source
RESTRICT="mirror"

# Build dependencies
DEPEND="
	sys-devel/gcc
	dev-util/cmake
"

# Runtime dependencies
RDEPEND="
	sys-libs/glibc
	chromeos-base/minijail
"

S="${WORKDIR}/llama.cpp-${LLAMA_CPP_VERSION}"

# All files install to /opt/llm-service; when in virtual/target-os-dev this
# lands on the dev image partition (mounted at /usr/local on device).
INSTALL_DIR="/opt/llm-service"

src_configure() {
	# llama.cpp requires exceptions - remove ChromiumOS's exception-disabling flags
	filter-flags -fno-exceptions -fno-unwind-tables -fno-asynchronous-unwind-tables
	append-cxxflags -fexceptions
	append-ldflags -fexceptions

	# Configure llama.cpp with CMake (CPU-only for now)
	local mycmakeargs=(
		-DGGML_CUDA=OFF
		-DGGML_METAL=OFF
		-DGGML_VULKAN=OFF
		-DBUILD_SHARED_LIBS=OFF
		-DLLAMA_BUILD_SERVER=ON
		-DLLAMA_BUILD_TESTS=OFF
		-DLLAMA_BUILD_EXAMPLES=OFF
	)
	cmake_src_configure
}

src_compile() {
	# Build llama-server
	cmake_src_compile llama-server
}

src_install() {
	# Install binary from CMake build directory
	exeinto "${INSTALL_DIR}/bin"
	doexe "${BUILD_DIR}/bin/llama-server"

	# Install model — goes to /usr/local/opt/llm-service/models/ on device
	insinto "${INSTALL_DIR}/models"
	doins "${DISTDIR}/${MODEL_NAME}"

	# Install upstart service
	insinto /etc/init
	doins "${FILESDIR}/llm-service.conf"

	# Install minijail config
	insinto /usr/share/minijail
	doins "${FILESDIR}/llm-service.minijail.conf"

	# Install tmpfiles.d config for /var/log directory creation
	insinto /usr/lib/tmpfiles.d
	newins "${FILESDIR}/llm-service-tmpfiles.conf" llm-service.conf
}

pkg_postinst() {
	einfo "LLM service installed successfully!"
	einfo "Installation: ${INSTALL_DIR}"
	einfo "Model: Qwen2.5-1.5B-Instruct (Q4_K_M, ~1.1GB)"
	einfo "Location: /usr/local${INSTALL_DIR}/models/${MODEL_NAME}"
	einfo ""
	einfo "The service will start automatically on boot."
	einfo "API endpoint: http://localhost:8080"
	einfo ""
	einfo "Test with:"
	einfo "  curl http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \\"
	einfo "    -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
}
