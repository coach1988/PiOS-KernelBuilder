#!/bin/bash

if [ $EXIT_ON_ERROR = "true" ]
then
    set -e
fi

##########################################################################################
# Auxiliary functions
##########################################################################################
log_divider () {
    echo \|-------------------------------------------------------------------------------
}

log_stage () {
    echo \| $@
}

log_header () {
    log_divider
    log_stage $(date): Entering $@ stage
    log_divider
}

log_env () {
    echo \|--- $@
}

log_step () {
    echo \|-- $@
}

log_info () {
    echo \| Info: $@
}

log_error () {
    echo \| Error $?: $@
    if [ $EXIT_ON_ERROR = "true" ]
    then
        exit -1
    fi
}

log_done () {
    echo \| Done
}

get_env () {
    for envvar in $(echo \
        REPOSITORY=$REPOSITORY \
        GITCOMMITHASH=$GITCOMMITHASH \
        CROSS_COMPILE=$CROSS_COMPILE \
        MODEL=$MODEL \
        ARCH=$ARCH \
        KERNEL=$KERNEL \
        REPOSITORY=$REPOSITORY \
        BRANCH=$BRANCH \
        KCONFIG=$KCONFIG \
        DEFCONFIG=$DEFCONFIG \
        MAKE_CLEAN=$MAKE_CLEAN \
        MAKE_DEFCONFIG=$MAKE_DEFCONFIG \
        MAKE_IMAGE=$MAKE_IMAGE \
        MAKE_MODULES=$MAKE_MODULES \
        MAKE_DTBS=$MAKE_DTBS \
        MAKE_MODULES_INSTALL=$MAKE_MODULES_INSTALL \
        MAKEJOBS=$MAKEJOBS \
        MAKEOPTS=$MAKEOPTS \
        BUILDARGS=$BUILDARGS \
        INSTALLARGS=$INSTALLARGS \
        EXIT_ON_ERROR=$EXIT_ON_ERROR
    )
    do
        log_env $envvar
    done
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

# Customize me
export INSTALLARGS="ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4"
export BUILDARGS="-j$MAKEJOBS $MAKEOPTS ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE"

get_env | tee /app/$MODEL-env-$BRANCH.log

##########################################################################################
# Prepare source
##########################################################################################
log_header Sources
cd /app

# Git clone / pull
if [ ! -d "$MODEL-linux-$BRANCH" ]
then
    log_step Cloning kernel repository...
    git clone --depth=1 --branch $BRANCH $REPOSITORY $MODEL-linux-$BRANCH > /app/$MODEL-sources-$BRANCH-$GITCOMMITHASH.log || (log_error git clone failed!)
    cd $MODEL-linux-$BRANCH && \
    git checkout $BRANCH >> /app/$MODEL-sources-$BRANCH-$GITCOMMITHASH.log || (log_error git checkout failed!)
    log_done
else
    log_step Pulling latest changes...
    cd $MODEL-linux-$BRANCH && \
    git checkout $BRANCH >> /app/$MODEL-sources-$BRANCH-$GITCOMMITHASH.log || (log_error git checkout failed!)
    git pull --rebase >> /app/$MODEL-sources-$BRANCH-$GITCOMMITHASH.log || (log_error git pull failed!)
    log_done
fi

# Git reset if commit was specified
if [ -n "$GITCOMMITHASH" ]
then
    log_step Setting commit...
    git reset --hard $GITCOMMITHASH >> /app/$MODEL-sources-$BRANCH-$GITCOMMITHASH.log || (log_error git reset failed!)
    log_done
else
    export GITCOMMITHASH=$(git rev-parse --short HEAD)  
fi
log_step Using commit $GITCOMMITHASH...

# Re-set $INSTALLARGS as we have $GITCOMMITHASH now
export INSTALLARGS="ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4"
log_info Updated INSTALLARGS to:
log_info $INSTALLARGS

##########################################################################################
# Makes
##########################################################################################
log_header Build

# make clean
if [ $MAKE_CLEAN = "true" ]
then
    log_step make clean
    make $BUILDARGS clean > /app/$MODEL-make_clean-$BRANCH-$GITCOMMITHASH.log || (log_error make clean failed!)
    log_done
fi

# make defconfig
if [ $MAKE_DEFCONFIG = "true" ]
then
    log_step make defconfig
    make $BUILDARGS $DEFCONFIG > /app/$MODEL-make_defconfig-$BRANCH-$GITCOMMITHASH.log || (log_error make defconfig failed!)
    log_done
fi

# Use mounted /config as .config
if [ -f /config ]
then
    log_step Found kconfig to use, copying...
    cp /config /app/linux/.config > /app/$MODEL-copy_kconfig-$BRANCH-$GITCOMMITHASH.log || (log_error Copying kconfig failed!)
    log_done
fi

# make $IMAGE
if [ $MAKE_IMAGE = "true" ]
then
    log_step make $IMAGE
    make $BUILDARGS $IMAGE > /app/$MODEL-make_image-$BRANCH-$GITCOMMITHASH.log || (log_error make image failed!)
    log_done
fi

# make modules
if [ $MAKE_MODULES = "true" ]
then
    log_step make modules
    make $BUILDARGS modules > /app/$MODEL-make_modules-$BRANCH-$GITCOMMITHASH.log || (log_error make modules failed!)
    log_done
fi

# make dtbs
if [ $MAKE_DTBS = "true" ]
then
    log_step make dtbs
    make $BUILDARGS dtbs > /app/$MODEL-make_dtbs-$BRANCH-$GITCOMMITHASH.log || (log_error make dtbs failed!)
    log_done
fi

##########################################################################################
# Prepare environment
##########################################################################################
log_header Directories

# Create output dirs
# Customize me
log_step Creating output directory structure...
if [ ! -d /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays ]
then
    mkdir -p /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays && \
    log_step Directory "/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays" created...
else
    log_step Directory "/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays" already exists, skipping...
fi && \
if [ ! -d /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4 ]
then
    mkdir -p /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4 > /app/$MODEL-directories-$BRANCH-$GITCOMMITHASH.log
    log_step Directory "/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4" created...
else
    log_step Directory "/app/$MODEL-output-$BRANCH-$GITCOMMITHASH/ext4" already exists, skipping...
fi || (log_error Creating directories failed!)
log_done

##########################################################################################
# make modules_install & copy compiled files
##########################################################################################
log_header Copying

# make modules_install
if [ $MAKE_MODULES_INSTALL = "true" ]
then
    log_step make modules_install
    make $MAKEOPTS $INSTALLARGS modules_install > /app/$MODEL-make_modules_install-$BRANCH-$GITCOMMITHASH.log || (log_error make modules_install failed!)
    log_done
fi

# Copy kernel and dtb's
# Customize me
log_step Copying compiled files to /app/$MODEL-output-$BRANCH-$GITCOMMITHASH...
cp -v arch/$ARCH/boot/$IMAGE /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/$KERNEL.img > /app/$MODEL-copy-$BRANCH-$GITCOMMITHASH.log && \
cp -v arch/$ARCH/boot/dts/overlays/*.dtb* /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays/ >> /app/$MODEL-copy-$BRANCH-$GITCOMMITHASH.log && \
cp -v arch/$ARCH/boot/dts/overlays/README /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/overlays/ >> /app/$MODEL-copy-$BRANCH-$GITCOMMITHASH.log && \
if [ $ARCH = "arm64" ]
then
    cp -v arch/$ARCH/boot/dts/broadcom/*.dtb /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/ >> /app/$MODEL-copy-$BRANCH-$GITCOMMITHASH.log
else
    cp -v arch/$ARCH/boot/dts/*.dtb /app/$MODEL-output-$BRANCH-$GITCOMMITHASH/fat32/ >> /app/$MODEL-copy-$BRANCH-$GITCOMMITHASH.log
fi || (log_error Copying compiled files failed!)
log_done

log_header Finished
