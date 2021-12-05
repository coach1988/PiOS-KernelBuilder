#!/bin/bash

##########################################################################################
# Auxiliary functions
##########################################################################################
log_divider () {
    echo \|-------------------------------------------------------------------------------
}

log_stage () {
    echo \| $@
}

log_env () {
    echo \|--- $@
}

log_step () {
    echo \|-- $@
}

log_result () {
    echo \| Done $@
}

log_header () {
    log_divider
    log_stage $(date): Entering $@ stage
    log_divider
}

log_info () {
    echo \| Info: $@
}

log_error () {
    echo \| Error: $@
}

get_env () {
    log_env REPOSITORY=$REPOSITORY
    log_env GITCOMMITHASH=$GITCOMMITHASH
    log_env CROSS_COMPILE=$CROSS_COMPILE
    log_env MODEL=$MODEL
    log_env ARCH=$ARCH
    log_env KERNEL=$KERNEL
    log_env KCONFIG=$KCONFIG
    log_env DEFCONFIG=$DEFCONFIG
    log_env MAKE_CLEAN=$MAKE_CLEAN
    log_env MAKE_DEFCONFIG=$MAKE_DEFCONFIG
    log_env MAKE_IMAGE=$MAKE_IMAGE
    log_env MAKE_MODULES=$MAKE_MODULES
    log_env MAKE_DTBS=$MAKE_DTBS
    log_env MAKE_MODULES_INSTALL=$MAKE_MODULES_INSTALL
    log_env MAKEJOBS=$MAKEJOBS
    log_env MAKEOPTS=$MAKEOPTS
    log_env BUILDARGS=$BUILDARGS
    log_env INSTALLARGS=$INSTALLARGS
}

update_env () {
    # Required as $GITCOMMITHASH will be available only later on
    # Customize me
    export INSTALLARGS="ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=/app/output-$GITCOMMITHASH/ext4"
    export REPOSITORY="https://github.com/raspberrypi/linux"
    export BUILDARGS="-j$MAKEJOBS $MAKEOPTS ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE"
}

##########################################################################################
# Set make variables according to $MODEL
##########################################################################################
case $MODEL in
    "pi4x64")
        export ARCH="arm64"
        export KERNEL="kernel8"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export IMAGE="Image"
        export DEFCONFIG="bcm2711_defconfig"
    ;;
    
    "pi4x86")
        export ARCH="arm"
        export KERNEL="kernel7l"
        export CROSS_COMPILE="arm-linux-gnueabihf-"
        export IMAGE="zImage"
        export DEFCONFIG="bcm2711_defconfig"
    ;;    

    "pi3x64")
        export ARCH="arm64"
        export KERNEL="kernel8"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export IMAGE="Image"
        export DEFCONFIG="bcmrpi3_defconfig"
    ;;
    
    "pi3x86")
        export ARCH="arm"
        export KERNEL="kernel7"
        export CROSS_COMPILE="arm-linux-gnueabihf-"
        export IMAGE="zImage"
        export DEFCONFIG="bcm2709_defconfig"
    ;;    
    
    "pi2")
        export ARCH="arm"
        export KERNEL="kernel7"
        export CROSS_COMPILE="arm-linux-gnueabihf-"
        export IMAGE="zImage"
        export DEFCONFIG="bcm2709_defconfig"
    ;;
    
    "pi1zero")
        export ARCH="arm"
        export KERNEL="kernel"
        export CROSS_COMPILE="arm-linux-gnueabihf-"
        export IMAGE="zImage"
        export DEFCONFIG="bcmrpi_defconfig"
    ;;
esac

##########################################################################################
# Finalize environment
##########################################################################################
log_header Environment
update_env
get_env | tee /app/env.log

##########################################################################################
# Prepare source
##########################################################################################
log_header Sources
cd /app

# Git clone / pull
if [ ! -d "linux" ]
then
    log_step Cloning kernel repository...
    git clone --depth=1 $REPOSITORY linux > /app/sources.log || (log_error git clone failed! && exit -1)
    log_result
    cd linux
else
    log_step Pulling latest changes...
    cd linux && \
    git pull --rebase > /app/sources.log || (log_error git pull failed! && exit -1)
    log_result
fi

# Git reset if commit was specified
if [ -n "$GITCOMMITHASH" ]
then
    log_step Setting commit...
    git reset --hard $GITCOMMITHASH >> /app/sources.log || (log_error git reset failed! && exit -1)
    log_result
else
    export GITCOMMITHASH=$(git rev-parse --short HEAD)
fi
log_step Using commit $GITCOMMITHASH...

update_env
log_info Updated INSTALLARGS to:
log_info $INSTALLARGS

##########################################################################################
# Prepare environment
##########################################################################################
log_header Directories

# Customize me
# Create output dirs
log_step Creating output directory structure...
mkdir -p /app/output-$GITCOMMITHASH/fat32/overlays && \
mkdir -p /app/output-$GITCOMMITHASH/ext4 || (log_error Creating directories failed! && exit -1)
log_result

##########################################################################################
# Makes
##########################################################################################
log_header Build

# make clean
if [ $MAKE_CLEAN = "true" ]
then
    log_step make clean
    make $BUILDARGS clean > /app/make_01-clean.log || (log_error make clean failed! && exit -1)
    log_result
fi

# make defconfig
if [ $MAKE_DEFCONFIG = "true" ]
then
    log_step make defconfig
    make $BUILDARGS $DEFCONFIG > /app/make_02defconfig.log || (log_error make defconfig failed! && exit -1)
    log_result
fi

# Use mounted /config as .config
if [ -f /config ]
then
    log_step Found kconfig to use, copying...
    cp /config /app/linux/.config || (log_error Copying kconfig failed! && exit -1)
    log_result
fi

# make $IMAGE
if [ $MAKE_IMAGE = "true" ]
then
    log_step make $IMAGE
    make $BUILDARGS $IMAGE > /app/make_03image.log || (log_error make image failed! && exit -1)
    log_result
fi

# make modules
if [ $MAKE_MODULES = "true" ]
then
    log_step make modules
    make $BUILDARGS modules > /app/make_04modules.log || (log_error make modules failed! && exit -1)
    log_result
fi

# make dtbs
if [ $MAKE_DTBS = "true" ]
then
    log_step make dtbs
    make $BUILDARGS dtbs > /app/make_05dtbs.log || (log_error make dtbs failed! && exit -1)
    log_result
fi

##########################################################################################
# make modules_install & copy compiled files
##########################################################################################
log_header Copying

# make modules_install
if [ $MAKE_MODULES_INSTALL = "true" ]
then
    log_step make modules_install
    make $MAKEOPTS $INSTALLARGS modules_install > /app/make_06modules_install.log || (log_error make modules_install failed! && exit -1)
    log_result
fi

# Customize me
# Copy kernel and dtb's
log_step Copying compiled files to /app/output-$GITCOMMITHASH...
cp -v arch/$ARCH/boot/$IMAGE /app/output-$GITCOMMITHASH/fat32/$KERNEL.img > /app/copying.log && \
cp -v arch/$ARCH/boot/dts/overlays/*.dtb* /app/output-$GITCOMMITHASH/fat32/overlays/ >> /app/copying.log && \
cp -v arch/$ARCH/boot/dts/overlays/README /app/output-$GITCOMMITHASH/fat32/overlays/ >> /app/copying.log && \
if [ $ARCH = "arm64" ]
then
    cp -v arch/$ARCH/boot/dts/broadcom/*.dtb /app/output-$GITCOMMITHASH/fat32/ >> /app/copying.log
else
    cp -v arch/$ARCH/boot/dts/*.dtb /app/output-$GITCOMMITHASH/fat32/ >> /app/copying.log
fi || (log_error Copying compiled files failed! && exit -1)
log_result

log_header Finished
