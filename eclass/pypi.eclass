# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: pypi.eclass
# @MAINTAINER:
# Michał Górny <mgorny@gentoo.org>
# @AUTHOR:
# Michał Górny <mgorny@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: A helper eclass to generate PyPI source URIs
# @DESCRIPTION:
# The pypi.eclass can be used to easily obtain URLs for artifacts
# uploaded to PyPI.org.  When inherited, the eclass defaults SRC_URI
# to fetch ${P}.tar.gz sdist.
#
# If necessary, SRC_URI can be overriden by the ebuild.  Two helper
# functions, pypi_sdist_url and pypi_wheel_url are provided to generate
# URLs to artifacts of specified type, with customizable project name.
# Additionally, pypi_wheel_name can be used to generate wheel filename.
#
# @EXAMPLE:
# @CODE@
# inherit pypi
#
# SRC_URI="$(pypi_sdist_url "${PN^}" "${PV}")"
# S=${WORKDIR}/${P^}
# @CODE@

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ ! ${_PYPI_ECLASS} ]]; then
_PYPI_ECLASS=1

# @FUNCTION: pypi_normalize_name
# @USAGE: <name>
# @DESCRIPTION:
# Normalize the project name according to sdist/wheel normalization
# rules.  That is, convert to lowercase and replace runs of [._-]
# with a single underscore.
#
# Based on the spec, as of 2023-02-10:
# https://packaging.python.org/en/latest/specifications/#package-distribution-file-formats
pypi_normalize_name() {
	[[ ${#} -ne 1 ]] && die "Usage: ${FUNCNAME} <name>"

	local name=${1}
	local shopt_save=$(shopt -p extglob)
	shopt -s extglob
	name=${name//+([._-])/_}
	${shopt_save}
	echo "${name,,}"
}

# @FUNCTION: pypi_sdist_url
# @USAGE: [--no-normalize] [<project> [<version> [<suffix>]]]
# @DESCRIPTION:
# Output the URL to PyPI sdist for specified project/version tuple.
#
# The `--no-normalize` option disables project name normalization
# for sdist filename.  This may be necessary when dealing with distfiles
# generated using build systems that did not follow PEP 625
# (i.e. the sdist name contains uppercase letters, hyphens or dots).
#
# If <package> is unspecified, it defaults to ${PN}.  The package name
# is normalized according to the specification unless `--no-normalize`
# is passed.
#
# If <version> is unspecified, it defaults to ${PV}.
#
# If <format> is unspecified, it defaults to ".tar.gz".  Another valid
# value is ".zip" (please remember to add a BDEPEND on app-arch/unzip).
pypi_sdist_url() {
	local normalize=1
	if [[ ${1} == --no-normalize ]]; then
		normalize=
		shift
	fi

	if [[ ${#} -gt 3 ]]; then
		die "Usage: ${FUNCNAME} [--no-normalize] <project> [<version> [<suffix>]]"
	fi

	local project=${1-"${PN}"}
	local version=${2-"${PV}"}
	local suffix=${3-.tar.gz}
	local fn_project=${project}
	[[ ${normalize} ]] && fn_project=$(pypi_normalize_name "${project}")
	printf "https://files.pythonhosted.org/packages/source/%s" \
		"${project::1}/${project}/${fn_project}-${version}${suffix}"
}

# @FUNCTION: pypi_wheel_name
# @USAGE: [<project> [<version> [<python-tag> [<abi-platform-tag>]]]]
# @DESCRIPTION:
# Output the wheel filename for the specified project/version tuple.
#
# If <package> is unspecified, it defaults to ${PN}.  The package name
# is normalized according to the wheel specification.
#
# If <version> is unspecified, it defaults to ${PV}.
#
# If <python-tag> is unspecified, it defaults to "py3".  It can also be
# "py2.py3", or a specific version in case of non-pure wheels.
#
# If <abi-platform-tag> is unspecified, it defaults to "none-any".
# You need to specify the correct value for non-pure wheels,
# e.g. "abi3-linux_x86_64".
pypi_wheel_name() {
	if [[ ${#} -gt 4 ]]; then
		die "Usage: ${FUNCNAME} <project> [<version> [<python-tag> [<abi-platform-tag>]]]"
	fi

	local project=$(pypi_normalize_name "${1-"${PN}"}")
	local version=${2-"${PV}"}
	local pytag=${3-py3}
	local abitag=${4-none-any}
	echo "${project}-${version}-${pytag}-${abitag}.whl"
}

# @FUNCTION: pypi_wheel_url
# @USAGE: [--unpack] [<project> [<version> [<python-tag> [<abi-platform-tag>]]]]
# @DESCRIPTION:
# Output the URL to PyPI wheel for specified project/version tuple.
#
# The `--unpack` option causes a SRC_URI with an arrow operator to
# be generated, that adds a .zip suffix to the fetched distfile,
# so that it is unpacked in default src_unpack().  Note that
# the wheel contents will be unpacked straight into ${WORKDIR}.
# You need to add a BDEPEND on app-arch/unzip.
#
# If <package> is unspecified, it defaults to ${PN}.
#
# If <version> is unspecified, it defaults to ${PV}.
#
# If <python-tag> is unspecified, it defaults to "py3".  It can also be
# "py2.py3", or a specific version in case of non-pure wheels.
#
# If <abi-platform-tag> is unspecified, it defaults to "none-any".
# You need to specify the correct value for non-pure wheels,
# e.g. "abi3-linux_x86_64".
pypi_wheel_url() {
	local unpack=
	if [[ ${1} == --unpack ]]; then
		unpack=1
		shift
	fi

	if [[ ${#} -gt 4 ]]; then
		die "Usage: ${FUNCNAME} [--unpack] <project> [<version> [<python-tag> [<abi-platform-tag>]]]"
	fi

	local filename=$(pypi_wheel_name "${@}")
	local project=${1-"${PN}"}
	local version=${2-"${PV}"}
	local pytag=${3-py3}
	printf "https://files.pythonhosted.org/packages/%s" \
		"${pytag}/${project::1}/${project}/${filename}"

	if [[ ${unpack} ]]; then
		echo " -> ${filename}.zip"
	fi
}

SRC_URI="$(pypi_sdist_url)"

fi
