ENTRY(_start)
SECTIONS {
 . = 0x41942c; .recorder : { *(.recorder) }
 . = 0x43c5c8; .clock : { *(.clock) }
 . = 0x638898; .systemtotal : { *(.systemtotal) }
 . = 0x642134; .game : { *(.game) }
 . = 0x6476a0; .systemframe : { *(.systemframe) }
 . = 0x652c04; .raw : { *(.raw) }
 . = 0x700000; .text : { *(.text) }
 . = 0x710000; .bss : { *(.bss) }
 /DISCARD/ : { *(.note.GNU-stack) }
}
