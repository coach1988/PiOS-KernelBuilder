# PiOS-KernelBuilder
## About the project
- This is a simple container with a heavily parameterized, yet simple build script to cross-compile a default or *custom kernel for 32- and 64-bit PiOS installations*
- Based on *Jeff Geerling's* work and inspiration :bulb: (e.g. https://www.jeffgeerling.com/blog/2020/cross-compiling-raspberry-pi-os-linux-kernel-on-macos)
  - Thank you Jeff for your entertaining and informative way of presenting your test results and project. This is for people like you, to help people like us achieving other wild things for our Pis
- I'm no developer, this is my first attempt to create a (useful) image and I'm still a docker novice, so please bear with me;-) If there are things I should change or add regarding e.g. the git handling (or if you have feedback in general), let me know and I'll do my best to improve it
- Unintended bonus feature: If you set the restart option inside the `docker-compose.yaml` to "unless-stopped", you will basically have always up-to-date kernels or some kind of CD ("*Continuous Delivery*"), but you should add some delay in that case. Only very few touches are required to change the repository and/or to run "*make*" with the parameters of your choice


## Usage
> **Important**: Always state the service (`buildenv` or `buildenv_kconfig`) when starting containers via the file, as starting both containers at once could lead to race conditions

- Compile a default kernel (`pi4x64`) with `docker-compose up buildenv`; This uses an `.env` file if it exists (examples included) or defaults to values included in the `docker-compose.yaml`)
- Compile the default `pi4x64` kernel with `docker-compose --env-file environments/pi4x64.env up buildenv`
- Compile the default `pi4x86` kernel with `docker-compose --env-file environments/pi4x86.env up buildenv`
- Compile the default `pi3x64` kernel with `docker-compose --env-file environments/pi3x64.env up buildenv`
- Compile the default `pi3x86` kernel with `docker-compose --env-file environments/pi3x86.env up buildenv`
- Compile the default `pi2` kernel with `docker-compose --env-file environments/pi2.env up buildenv`
- Compile the default `pi1zero` kernel with `docker-compose --env-file environments/pi1zero.env up buildenv`
- To compile the state at a specific commit, set `GITCOMMITHASH` via the `.env` file/environment variable
  - To compile a kernel with an **additional** kconfig, save the config next to the other files and run `docker-compose --env-file <yourEnvFile> buildenv_kconfig up` instead; This defaults to `pi4x64` if no `.env` file is found/variables are given


## Tips & Tricks
- If you change `OUTPUTDIR` or `SCRIPT` from defaults: Add the volume's directory/script file to the `.dockerignore` file (if it is in the same folder as the docker-compose; This avoids sending big build contexts to the daemon) and the `.gitignore` file
- The default volume bind folders are `./app64` and `./app32`
  - Compiled files will be saved under `<volume>/<model>-output-<branch>-<gitcommithash>/{fat32|ext4}`
  - Kernel sources will be cloned to `<volume>/<model>-linux-<branch>`
  - Each stage will log the output to `<volume>/*.log`
- The default amount of maximum parallel Makejobs (`-jN`) defaults to `4`. It can be adjusted via the `.env` file/environment variable `MAKEJOBS`
- You can run a regular `make menuconfig` in the `<volume>/<model>-linux-<branch>` folder to create a custom config


## How it works & what it does
This is a simple *Debian Bullseye (Slim)* based docker container with added packages required to cross-compile *32- and 64-bit PiOS kernels*. It starts a simple script (`entryPoint.sh`), which calls an externally mounted main script (to avoid rebuilds for every change to the script). This main script parses variables from `.env` files or environment and executes:
  - `git clone / pull`
  - `git reset --hard` (if commit hash was given)
  - `make clean`
  - `make defconfig`
  - `copy kconfig` (if configured/found)
  - `make Image/zImage`
  - `make modules`
  - `make dtbs`
  - `make modules_install`

Eventually, the script will copy the compiled files to `<volumes>/<model>-output-<branch>-<gitcommithash>/{fat32|ext4}`

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `EXIT_ON_ERROR` | `true` | Exit `$SCRIPT` on errors |
| `GITCOMMITHASH` | `empty` | Git commit state to build (uses the latest if not specified) |
| `REPOSITORY` | `https://github.com/raspberrypi/linux` | Git repository to use |
| `BRANCH` | `rpi-5.10.y` | Git branch to use |
| `MODEL` | `pi4x64` | Raspberry Pi model to build for (allowed values are `pi4x64`, `pi4x86`, `pi3x64`, `pi3x86`, `pi2`, `pi1zero`) |
| `KCONFIG` | `empty` | KCONFIG file to use in combination with the `buildenv_kconfig` service |
| `OUTPUTDIR` | `app64` | Volume / output directory |
| `MAKE_CLEAN` | `false` | Run `make clean` step |
| `MAKE_DEFCONFIG` | `true` | Run `make defconfig` step |
| `MAKE_IMAGE` | `true` | Run `make (z)Image` step |
| `MAKE_MODULES` | `true` | Run `make modules` step |
| `MAKE_DTBS` | `true` | Run `make dtbs` step |
| `MAKE_MODULES_INSTALL` | `true` | Run `make modules_install` step |
| `MAKEOPTS` | `empty` | Additional flags and parameters for `make` |
| `MAKEJOBS` | `4` | Amount of parallel make jobs |
| `SCRIPT` | `scripts/compile.sh` | Script to call after starting the container |

## Links:
- :arrow_right: Jeff Geerling's Blog: https://www.jeffgeerling.com
- :penguin: Official Raspberry Pi cross-compiling documentation: https://www.raspberrypi.com/documentation/computers/linux_kernel.html
