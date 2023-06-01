#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_hook cleanup 00 "/usr/lib/dracut/modules.d/01mymodule/test.sh"
}