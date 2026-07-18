#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Build and install SELinux policy modules"

TE_DIR="/usr/share/selinux/packages"
PP_DIR="/usr/share/selinux/packages"

for te_file in "${TE_DIR}"/*.te; do
	if [[ ! -f "${te_file}" ]]; then
		echo "No SELinux policy source files found."
		echo "::endgroup::"
		exit 0
	fi

	module_name="$(basename "${te_file}" .te)"
	mod_file="${PP_DIR}/${module_name}.mod"
	pp_file="${PP_DIR}/${module_name}.pp"

	echo "Compiling ${module_name}..."

	checkmodule \
		-M \
		-m \
		-o "${mod_file}" \
		"${te_file}"

	semodule_package \
		-o "${pp_file}" \
		-m "${mod_file}"

	semodule \
		--priority=300 \
		--install "${pp_file}"

	echo "Installed ${module_name} at priority 300."
done

semodule -l | grep -E '^300 ' || true

echo "::endgroup::"
