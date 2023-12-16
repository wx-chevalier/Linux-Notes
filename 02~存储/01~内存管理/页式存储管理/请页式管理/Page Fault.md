# Page Fault

上文中提及，当我们向操作系统申请内存时，操作系统并不是直接分配给我们物理内存，而是只标记当前进程拥有该段内存，当真正使用这段段内存时才会分配。这种延迟分配物理内存的方式就通过 page fault 机制来实现的。当我们访问一个内存地址时，如果该地址非法，或者我们对其没有访问权限，或者该地址对应的物理内存还未分配，cpu 都会生成一个 page fault，进而执行操作系统的 page fault handler。

这个 page fault handler 里会检查该 fault 产生的原因，如果是地址非法或没有权限，则会向当前进程发送一个 SIGSEGV signal，该 signal 默认会 kill 掉当前进程，并提示我们 segmentation fault 异常。如果是因为还未分配物理内存，操作系统会立即分配物理内存给当前进程，然后重试产生这个 page fault 的内存访问指令，一般情况下都可以正常向下执行。

下面我们来看下对应的内核源码：

```c
// arch/x86/mm/fault.c
dotraplinkage void notrace
do_page_fault(struct pt_regs *regs, unsigned long error_code)
{
        unsigned long address = read_cr2(); /* Get the faulting address */
        ...
        __do_page_fault(regs, error_code, address);
        ...
}
NOKPROBE_SYMBOL(do_page_fault);
```

该方法先从 cr2 寄存器中读出产生这个 page fault 的虚拟内存地址，然后再调用 `__do_page_fault` 方法。

```c
// arch/x86/mm/fault.c
static noinline void
__do_page_fault(struct pt_regs *regs, unsigned long hw_error_code,
                unsigned long address)
{
        ...
        /* Was the fault on kernel-controlled part of the address space? */
        if (unlikely(fault_in_kernel_space(address)))
                do_kern_addr_fault(regs, hw_error_code, address);
        else
                do_user_addr_fault(regs, hw_error_code, address);
}
NOKPROBE_SYMBOL(__do_page_fault);
```

该方法会检查该地址是属于 kernel space 还是 user space，如果是 user space，则会调用 do_user_addr_fault 方法。继续 do_user_addr_fault 方法：

```c
// arch/x86/mm/fault.c
static inline
void do_user_addr_fault(struct pt_regs *regs,
                        unsigned long hw_error_code,
                        unsigned long address)
{
        struct vm_area_struct *vma;
        struct task_struct *tsk;
        struct mm_struct *mm;
        ...
        tsk = current;
        mm = tsk->mm;
        ...
        vma = find_vma(mm, address);
        if (unlikely(!vma)) {
                bad_area(regs, hw_error_code, address);
                return;
        }
        if (likely(vma->vm_start <= address))
                goto good_area;
        ...
good_area:
        ...
        fault = handle_mm_fault(vma, address, flags);
        ...
}
NOKPROBE_SYMBOL(do_user_addr_fault);
```

该方法会先从 mm 中找包含 address 的内存段，如果没有，则说明我们访问了一个非法地址，该方法进而会调用 bad_area 方法，向当前进程发送一个 SIGSEGV signal。如果找到了对应的内存段，则会调用 handle_mm_fault 方法继续处理。

```c
// mm/memory.c
vm_fault_t handle_mm_fault(struct vm_area_struct *vma, unsigned long address,
                unsigned int flags)
{
        vm_fault_t ret;
        ...
        if (unlikely(is_vm_hugetlb_page(vma)))
                ...
        else
                ret = __handle_mm_fault(vma, address, flags);
        ...
        return ret;
}
EXPORT_SYMBOL_GPL(handle_mm_fault);
```

该方法又调用了 `__handle_mm_fault` 方法：

```c
// mm/memory.c
static vm_fault_t __handle_mm_fault(struct vm_area_struct *vma,
                unsigned long address, unsigned int flags)
{
        struct vm_fault vmf = {
                .vma = vma,
                .address = address & PAGE_MASK,
                ...
        };
        ...
        struct mm_struct *mm = vma->vm_mm;
        pgd_t *pgd;
        p4d_t *p4d;
        vm_fault_t ret;

        pgd = pgd_offset(mm, address);
        p4d = p4d_alloc(mm, pgd, address);
        ...
        vmf.pud = pud_alloc(mm, p4d, address);
        ...
        vmf.pmd = pmd_alloc(mm, vmf.pud, address);
        ...
        return handle_pte_fault(&vmf);
}
```

此时，vmf->pte 应该为 null。该方法通过 vma_is_anonymous 方法，判断 vmf->vma 对应的内存段是否是 anonymous 的，如果是，则调用 do_anonymous_page，如果不是，比如 mmap file 产生的 vma，则调用 do_fault。

```c
// mm/memory.c
static vm_fault_t do_anonymous_page(struct vm_fault *vmf)
{
        struct vm_area_struct *vma = vmf->vma;
        ...
        struct page *page;
        ...
        pte_t entry;
        ...
        page = alloc_zeroed_user_highpage_movable(vma, vmf->address);
        ...
        entry = mk_pte(page, vma->vm_page_prot);
        ...
        set_pte_at(vma->vm_mm, vmf->address, vmf->pte, entry);
        ...
        return ret;
        ...
}
```

该方法先调用 alloc_zeroed_user_highpage_movable 分配一个新的 page，这个就是物理内存了。然后调用 mk_pte 方法，把 page 的地址信息等记录到 entry 里。最后，把这个 entry 写入到 vmf->pte 指向的内存中。这样在下次再访问这个 page 对应的虚拟内存地址时，page walk 就可以在 pte 中找到这个 page 了。
