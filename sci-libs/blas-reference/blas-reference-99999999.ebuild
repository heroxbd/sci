# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

NUMERIC_MODULE_NAME="refblas"

#inherit fortran-2 cmake-utils alternatives-2 multibuild multilib-build toolchain-funcs fortran-int64
inherit alternatives-2 fortran-2 numeric-int64-multibuild toolchain-funcs cmake-multilib

LPN=lapack
LPV=3.5.0

if [[ ${PV} == "99999999" ]] ; then
	ESVN_REPO_URI="https://icl.cs.utk.edu/svn/lapack-dev/${LPN}/trunk"
	inherit subversion
	KEYWORDS=""
else
	SRC_URI="http://www.netlib.org/${LPN}/${LPN}-${LPV}.tgz"
	KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
fi

DESCRIPTION="Reference implementation of BLAS"
HOMEPAGE="http://www.netlib.org/lapack/"

LICENSE="BSD"
SLOT="0"
IUSE="static-libs test"

RDEPEND=""
DEPEND="${RDEPEND}
	virtual/pkgconfig"
PDEPEND=">=virtual/blas-2.1-r3[int64?]"

S="${WORKDIR}/${LPN}-${LPV}"

src_prepare() {
	# rename library to avoid collision with other blas implementations
	# ${LIBNAME} and ${PROFNAME} are not defined here, they are in single
	# quotes in the following seds.  They are later set by defining cmake
	# variables with -DPROFNAME etc in src_configure
	sed -i \
		-e 's:\([^xc]\)blas:\1${LIBNAME}:g' \
		CMakeLists.txt \
		BLAS/SRC/CMakeLists.txt || die
	sed -i \
		-e '/Name: /s:blas:${PROFNAME}:' \
		-e 's:-lblas:-l${LIBNAME}:g' \
		 BLAS/blas.pc.in || die
	sed -i \
		-e 's:blas):${LIBNAME}):' \
		BLAS/TESTING/CMakeLists.txt || die
	sed -i \
		-e 's:BINARY_DIR}/blas:BINARY_DIR}/${PROFNAME}:' \
		BLAS/CMakeLists.txt || die

	# MULTIBUILD_VARIANTS=$( numeric-int64_get_multibuild_variants )
}

src_configure() {
	blas_configure() {
		local FCFLAGS="${FCFLAGS}"
		append-fflags $($(tc-getPKG_CONFIG) --cflags ${blas_profname})
		append-fflags $(get_abi_CFLAGS)
		append-fflags $(numeric-int64_get_fortran_int64_abi_fflags)

		local profname=$(numeric-int64_get_profname)
		local libname="${profname//-/_}"

		local mycmakeargs=(
			-Wno-dev
			-DPROFNAME="${profname}"
			-DLIBNAME="${libname}"
			-DUSE_OPTIMIZED_BLAS=OFF
			-DCMAKE_Fortran_FLAGS="${FCFLAGS}"
			-DLAPACK_PKGCONFIG_FFLAGS="$(numeric-int64_get_fortran_int64_abi_fflags)"
			$(cmake-utils_use_build test TESTING)
		)
		if $(numeric-int64_is_static_build); then
			mycmakeargs+=(
				-DBUILD_SHARED_LIBS=OFF
				-DBUILD_STATIC_LIBS=ON
			)
		else
			mycmakeargs+=(
				-DBUILD_SHARED_LIBS=ON
				-DBUILD_STATIC_LIBS=OFF
			)
		fi
		cmake-utils_src_configure
		#einfo ${MULTIBUILD_ID}
		#einfo ${FCFLAGS}
		#einfo ${mycmakeargs[@]}
	}
#	numeric-int64_multibuild_foreach_variant blas_configure
	numeric-int64_multibuild_foreach_abi_variant blas_configure
}

src_compile() {
	numeric-int64_multibuild_foreach_abi_variant cmake-utils_src_compile -C BLAS
}

src_test() {
	blas_test() {
		_check_build_dir
		pushd "${BUILD_DIR}/BLAS" > /dev/null
		local ctestargs
		[[ -n ${TEST_VERBOSE} ]] && ctestargs="--extra-verbose --output-on-failure"
		ctest ${ctestargs} || die
		popd > /dev/null
	}
	numeric-int64_multibuild_foreach_abi_variant blas_test
}

src_install() {
	numeric-int64_multibuild_foreach_abi_variant cmake-utils_src_install -C BLAS
	blas_alternative()  {
		if ! $(fortran-int64_is_static_build); then
			local profname=$(fortran-int64_get_profname)
			local provider=$(fortran-int64_get_blas_provider)
			alternatives_for ${provider} $(fortran-int64_get_profname "reference") 0 \
				/usr/$(get_libdir)/pkgconfig/${provider}.pc ${profname}.pc
		fi
	}
	numeric-int64_multibuild_foreach_abi_variant blas_alternative
}

_src_install() {
	local MULTIBUILD_VARIANTS=( $(fortran-int64_multilib_get_enabled_abis) )
	multibuild_foreach_variant fortran-int64_multilib_multibuild_wrapper my_src_install
}
