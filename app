#!/bin/bash

arg=$1

function initialize {
    meson setup build --prefix=/usr
    result=$?

    if [ $result -gt 0 ]; then
        echo "Unable to initialize, please review log"
        exit 1
    fi

    cd build

    ninja

    result=$?

    if [ $result -gt 0 ]; then
        echo "Unable to build project, please review log"
        exit 2
    fi
}

case $1 in
"clean")
    sudo rm -rf ./build
    ;;
"generate-i18n")
    grep -rc _\( * | grep ^src | grep -v :0 | cut -d : -f 1 | sort -o po/POTFILES
    echo "data/com.github.phase1geo.journaler.shortcuts.ui" >> po/POTFILES
    initialize
    ninja com.github.phase1geo.journaler-pot
    ninja com.github.phase1geo.journaler-update-po
    ninja extra-pot
    ninja extra-update-po
    cp data/* ../data
    ;;
"install")
    initialize
    sudo ninja install
    ;;
"install-deps")
    output=$((dpkg-checkbuilddeps ) 2>&1)
    result=$?

    if [ $result -eq 0 ]; then
        echo "All dependencies are installed"
        exit 0
    fi

    replace="sudo apt install"
    pattern="(\([>=<0-9. ]+\))+"
    sudo_replace=${output/dpkg-checkbuilddeps: error: Unmet build dependencies:/$replace}
    command=$(sed -r -e "s/$pattern//g" <<< "$sudo_replace")
    
    $command
    ;;
"run")
    initialize
    ./com.github.phase1geo.journaler "${@:2}"
    ;;
"debug")
    initialize
    # G_DEBUG=fatal-criticals gdb --args ./com.github.phase1geo.journaler "${@:2}"
    G_DEBUG=fatal-warnings gdb --args ./com.github.phase1geo.journaler "${@:2}"
    ;;
 "valgrind")
    initialize
    valgrind ./com.github.phase1geo.journaler "${@:2}"
    ;;
"uninstall")
    initialize
    sudo ninja uninstall
    ;;
"flatpak")
    sudo flatpak-builder --install --force-clean ../build-journaler com.github.phase1geo.journaler.yml
    ;;
"flat-run")
    flatpak run com.github.phase1geo.journaler
    ;;
"flat-debug")
    flatpak run --command=sh --devel com.github.phase1geo.journaler
    ;;
*)
    echo "Usage:"
    echo "  ./app [OPTION]"
    echo ""
    echo "Options:"
    echo "  clean             Removes build directories (can require sudo)"
    echo "  generate-i18n     Generates .pot and .po files for i18n (multi-language support)"
    echo "  install           Builds and installs application to the system (requires sudo)"
    echo "  install-deps      Installs missing build dependencies"
    echo "  run               Builds and runs the application"
    echo "  uninstall         Removes the application from the system (requires sudo)"
    echo "  flatpak           Builds and installs the Flatpak version of the application"
    ;;
esac
