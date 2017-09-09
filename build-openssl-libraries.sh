#! /usr/bin/env bash
git submodule update --init
(cd external/openssl;

    if [ ! ${ANDROID_NDK_ROOT} ]; then
        echo "ANDROID_NDK_ROOT environment variable not set, set and rerun"
        exit 1
    fi

    ANDROID_LIB_ROOT=../android-libs
    ANDROID_TOOLCHAIN_DIR=/tmp/openssl-android-toolchain
    OPENSSL_OPTIONS="\
        no-afalgeng \
        no-bf \
        no-blake2 \
        no-camellia \
        no-capieng \
        no-cast \
        no-chacha \
        no-cmac \
        no-cms \
        no-comp \
        no-ct \
        no-des \
        no-dgram \
        no-dh \
        no-dsa \
        no-dso \
        no-dtls \
        no-dynamic-engine \
        no-ec \
        no-ec2m \
        no-ecdh \
        no-ecdsa \
        no-engine \
        no-gost \
        no-hw \
        no-idea \
        no-md4 \
        no-mdc2 \
        no-nextprotoneg \
        no-ocb \
        no-ocsp \
        no-poly1305 \
        no-rc2 \
        no-rc4 \
        no-rfc3779 \
        no-rmd160 \
        no-shared \
        no-sock \
        no-srp \
        no-srtp \
        no-sse2 \
        no-ssl \
        no-static-engine \
        no-tls \
        no-ts \
        no-ui \
        no-whirlpool"

    DEFAULT_FLAGS=" \
        -ffunction-sections \
        -funwind-tables \
        -fstack-protector-strong \
        -g \
        -O2 \
        -no-canonical-prefixes"

    DEFAULT_ARM_FLAGS="-mthumb -fpic"
    
    HOST_INFO=`uname -a`
    case ${HOST_INFO} in
        Darwin*)
            TOOLCHAIN_SYSTEM=darwin-x86
            ;;
        Linux*)
            if [[ "${HOST_INFO}" == *i686* ]]
            then
                TOOLCHAIN_SYSTEM=linux-x86
            else
                TOOLCHAIN_SYSTEM=linux-x86_64
            fi
            ;;
        *)
            echo "Toolchain unknown for host system"
            exit 1
            ;;
    esac

    rm -rf ${ANDROID_LIB_ROOT}
    #git clean -dfx && git checkout -f

    for TARGET_PLATFORM in armeabi armeabi-v7a x86
    do
        echo "Building for libcrypto.a for ${TARGET_PLATFORM}"
        case "${TARGET_PLATFORM}" in
            armeabi)
                TOOLCHAIN_ARCH=arm
                TOOLCHAIN_PREFIX=arm-linux-androideabi
                OPENSSL_TARGET="android-armeabi -D__ARM_MAX_ARCH__=8"
                OPENSSL_FLAGS="$DEFAULT_FLAGS $DEFAULT_ARM_FLAGS -march=armv5te -mtune=xscale -msoft-float"
                PLATFORM_OUTPUT_DIR=armeabi
                ANDROID_API=15
                ;;
            armeabi-v7a)
                TOOLCHAIN_ARCH=arm
                TOOLCHAIN_PREFIX=arm-linux-androideabi
                OPENSSL_TARGET="android-armeabi -D__ARM_MAX_ARCH__=8"
                OPENSSL_FLAGS="$DEFAULT_FLAGS $DEFAULT_ARM_FLAGS -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -Wl,--fix-cortex-a8"
                PLATFORM_OUTPUT_DIR=armeabi-v7a
                ANDROID_API=15
                ;;
            x86)
                TOOLCHAIN_ARCH=x86
                TOOLCHAIN_PREFIX=i686-linux-android
                OPENSSL_TARGET=android-x86
                OPENSSL_FLAGS=$DEFAULT_FLAGS
                PLATFORM_OUTPUT_DIR=x86
                ANDROID_API=15
                ;;        
            *)
                echo "Unsupported build platform:${TARGET_PLATFORM}"
                exit 1
        esac

        rm -rf ${ANDROID_TOOLCHAIN_DIR}
        
        ${ANDROID_NDK_ROOT}/build/tools/make_standalone_toolchain.py \
            --arch ${TOOLCHAIN_ARCH} \
            --api ${ANDROID_API} \
            --install-dir "${ANDROID_TOOLCHAIN_DIR}"
        
        export PATH=${ANDROID_TOOLCHAIN_DIR}/bin:$PATH
        export CROSS_SYSROOT=${ANDROID_TOOLCHAIN_DIR}/sysroot

        make clean

        RANLIB=${TOOLCHAIN_PREFIX}-ranlib \
            AR=${TOOLCHAIN_PREFIX}-ar \
            CC="${TOOLCHAIN_PREFIX}-gcc -D__ANDROID_API__=${ANDROID_API}" \
            ./Configure $OPENSSL_TARGET $OPENSSL_OPTIONS ${DEFAULT_FLAGS} 

        if [ $? -ne 0 ]; then
            echo "Error executing:./Configure ${OPENSSL_TARGET} ${OPENSSL_FLAGS} ${OPENSSL_OPTIONS}"
            exit 1
        fi
        
        make build_libs

        if [ $? -ne 0 ]; then
            echo "Error executing make for platform:${TARGET_PLATFORM}"
            exit 1
        fi
        
        mkdir -p "${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}/include"
        mv libcrypto.a ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}
        cp -r include/openssl "${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}/include"
    done

)