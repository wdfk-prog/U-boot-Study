OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
SECTIONS
{
 . = 0x00000000;
 . = ALIGN(4);
 __image_copy_start = ADDR(.text);
 .text :
 {
  *(.vectors)
  arch/arm/cpu/armv7m/start.o (.text*)
 }
 .efi_runtime : {
  __efi_runtime_start = .;
  *(.text.efi_runtime*)
  *(.rodata.efi_runtime*)
  *(.data.efi_runtime*)
  __efi_runtime_stop = .;
 }
 .text_rest :
 {
  *(.text*)
 }
 . = ALIGN(4);
 .rodata : { *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.rodata*))) }
 . = ALIGN(4);
 .data : {
  *(.data*)
 }
 . = ALIGN(4);
 . = .;
 . = ALIGN(4);
 __u_boot_list : {
  KEEP(*(SORT(__u_boot_list*)));
 }
 .efi_runtime_rel : {
  __efi_runtime_rel_start = .;
  *(.rel*.efi_runtime)
  *(.rel*.efi_runtime.*)
  __efi_runtime_rel_stop = .;
 }
 . = ALIGN(4);
 __image_copy_end = .;
 .rel.dyn ALIGN(4) : {
  __rel_dyn_start = .;
  *(.rel*)
  __rel_dyn_end = .;
 }
 _end = .;
 _image_binary_end = .;
 . = ALIGN(4096);
 .mmutable : {
  *(.mmutable)
 }
 .bss ADDR(.rel.dyn) (OVERLAY): {
  __bss_start = .;
  *(.bss*)
  . = ALIGN(4);
  __bss_end = .;
 }
 .dynsym _image_binary_end : { *(.dynsym) }
 .dynbss : { *(.dynbss) }
 .dynstr : { *(.dynstr*) }
 .dynamic : { *(.dynamic*) }
 .plt : { *(.plt*) }
 .interp : { *(.interp*) }
 .gnu.hash : { *(.gnu.hash) }
 .gnu : { *(.gnu*) }
 .ARM.exidx : { *(.ARM.exidx*) }
 .gnu.linkonce.armexidx : { *(.gnu.linkonce.armexidx.*) }
}
