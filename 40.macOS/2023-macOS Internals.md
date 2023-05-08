# macOS Internals

Understand your Mac and iPhone more deeply by tracing the evolution of Mac OS X from prelease to Swift. John Siracusa delivers the details.

## Starting Points

### How to use this gist

You've got two main options:

1. Under Highlights, read all the links you're interested in, or
2. Use "OS X Reviewed" as an index and just read all the reviews end to end. (This is not the fast option, but it inspired me to gather all these highlights.)

In either case, to get the greatest benefits of context and intuition, I recommend that you read in chronological order.

### [OS X Reviewed](https://hypercritical.co/2015/04/15/os-x-reviewed)

> Nearly 15 years ago, I wrote my first review of Mac OS X for a nascent “PC enthusiast’s" website called Ars Technica. Last fall, I wrote my last.

## Highlights

These chronologically-ordered highlights jump into the middle of long, paginated articles. Topics often span a few pages, so look for the "Next Page" links.

### [Quartz 2D: PDF-based drawing](https://arstechnica.com/gadgets/2000/01/macos-x-gui/2/)

> I've chosen to define the three generations of display layer technology in order to illustrate the most important changes over the years.

### [Packaged Applications and Frameworks](https://arstechnica.com/gadgets/2000/05/mac-os-x-dp4/2/)

> The three main "subspecies" of Bundles are Application Packages, Frameworks, and Loadable Bundles.

### [The Window Server](https://arstechnica.com/gadgets/2000/05/mac-os-x-dp4/4/)

> It has two main responsibilities: Event routing, and composing and displaying on-screen elements.

### [Project Builder, better known as Xcode](https://arstechnica.com/gadgets/2000/05/mac-os-x-dp4/9/)

> What may not be so obvious is that Project Builder is built on top of popular open source development tools: everything from gcc, gdb, and cvs to smaller tools like diff.

### [Memory on macOS](https://arstechnica.com/gadgets/2001/10/macosx-10-1/7/)

> Mac OS X manages memory very differently than classic Mac OS. The first key to understanding memory usage in Mac OS X is to be understand how a modern virtual memory system works.

### [Rendezvous, now known as Bonjour and Zeroconf](https://arstechnica.com/gadgets/2002/09/macosx-10-2/7/)

> Rendezvous enables a local network of devices to configure themselves without the aid of any centralized servers.

### [GPU-accelerated display compositing](https://arstechnica.com/gadgets/2002/09/macosx-10-2/8/)

> It's slightly confusing to think about the window server as an OpenGL application, but that's what it is.

### ["Sherlocking"](https://arstechnica.com/gadgets/2002/09/macosx-10-2/13/)

> As the Watson FAQ explains, although Apple's new version of Sherlock is a dead-ringer for Watson, there is no formal relationship between the two applications.

### [Spatial window management and Exposé](https://arstechnica.com/gadgets/2003/11/macosx-10-3/7/)

> Panther includes a new window management feature that effectively increases the size of your screen by shrinking all of your windows temporarily. Following Apple's recent Gallic naming trend, it's called Exposé.

### [launchd](https://arstechnica.com/gadgets/2005/04/macosx-10-4/5/)

> One launch daemon to rule them all.

### [Extended file attributes](https://arstechnica.com/gadgets/2005/04/macosx-10-4/6/)

> Mac OS X now includes support for arbitrarily extensible file system metadata.

### [Spotlight](https://arstechnica.com/gadgets/2005/04/macosx-10-4/9/)

> Spotlight is a system service that accepts a query and returns all file system objects (files and folders) that match the query.

### [GPU-accelerated window drawing](https://arstechnica.com/gadgets/2005/04/macosx-10-4/13/)

> The only thing left for the CPU to do is to send (relatively tiny) drawing commands to the video card through the driver.

### [DTrace and Instruments](https://arstechnica.com/gadgets/2007/10/mac-os-x-10-5/5/)

> This application was called Xray for most of its development life, which explains the icon. It's now called Instruments for reasons that surely involve lawyers.

### [FSEvents](https://arstechnica.com/gadgets/2007/10/mac-os-x-10-5/7/)

> To be aware of all relevant file system changes, the notification mechanism must exist at the choke point for all local i/o: the kernel. But the kernel is a harsh mistress, filled with draconian latency and memory restrictions.

### [Core Animation](https://arstechnica.com/gadgets/2007/10/mac-os-x-10-5/8/)

> Core Animation's original name, Layer Kit, reveals a lot about its design. At its heart, Core Animation manages a collection of 2D layers.

### [Time Machine](https://arstechnica.com/gadgets/2007/10/mac-os-x-10-5/14/)

> "I know I should back up, but I never do. I wouldn't even know how to do something like that anyway." Well, enough of that.

### [LLVM, Clang, and Objective-C Blocks](https://arstechnica.com/gadgets/2009/08/mac-os-x-10-6/9/)

> By committing to a Clang/LLVM-powered future, Apple has finally taken complete control of its development platform.

### [GCD: Grand Central Dispatch](https://arstechnica.com/gadgets/2009/08/mac-os-x-10-6/11/)

> The bottom line is that the optimal number of threads to put in flight at any given time is best determined by a single, globally aware entity.

### [The Recovery Partition](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/2/)

> The new partition is actually considered a different type: Apple_Boot. The Recovery HD volume won't be automatically mounted upon boot and therefore won't appear in the Finder.

### [Hidden scroll bars and natural scroll direction](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/3/)

> Lion further cements the dominance of touch by making all touch-based scrolling work like it does on a touchscreen.

### [Modernized Document Model](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/7/)

> At this point, a little bit of "geek panic" might be setting in.

### [Automatic Termination](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/8/)

> Whereas Sudden Termination lets an application tell the system when it's okay to terminate it with extreme prejudice, Automatic Termination lets an application tell the system that it's okay to politely ask the program to exit.

### [App Sandboxing and Entitlements](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/9/)

> A sandboxed application must now include a list of "entitlements" describing exactly what resources it needs in order to do its job.

### [ARC: Automatic Reference Counting](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/10/)

> There is no process that scans the memory image of a running application looking for memory to deallocate. Everything ARC does happens at compile time.

### [FileVault whole disk encryption](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/13/)

> This encryption is completely transparent to all software (including the implementation of HFS+ itself) because it takes place at a layer above the volume format.

### [Document revision storage](https://arstechnica.com/gadgets/2011/07/mac-os-x-10-7/14/)

> Unlike earlier incarnations of autosave, you won't see auto-generated files appearing and disappearing alongside the original document. But the data obviously has to be stored somewhere, so where is it?

### [iCloud](https://arstechnica.com/gadgets/2012/07/os-x-10-8/10/)

> Apple provides three different kinds of iCloud data storage APIs, with very little overlap between them in terms of functionality and intended purpose.

### [Gatekeeper, code signing, and quarantine](https://arstechnica.com/gadgets/2012/07/os-x-10-8/14/)

> Gatekeeper is the latest stop in Apple's long, ongoing journey toward a more secure, worry-free computing experience on the Mac. Once again, iOS is the model.

### [Objective-C 2.0 syntax](https://arstechnica.com/gadgets/2012/07/os-x-10-8/17/)

> Even if you have no idea what any of that means, I believe you may still find the table below compelling.

### [Power Nap](https://arstechnica.com/gadgets/2012/07/os-x-10-8/18/)

> In this mode, the audio and graphics systems remain powered down, but the disk, CPU, and networking hardware are all active.

### [Finder Tags](https://arstechnica.com/gadgets/2013/10/os-x-10-9/9/)

> Labels were introduced way back in System 6 in 1988. Since Apple made both the Finder and the file system, it reserved a place in the file system metadata for what it called “Finder Info.”

### [App Nap and Background Tasks](https://arstechnica.com/gadgets/2013/10/os-x-10-9/12/)

> By coalescing the work into a contiguous burst of high activity, transitional waste has been cut to a bare minimum, and the amount of idle time has been maximized.

### [Compressed Memory](https://arstechnica.com/gadgets/2013/10/os-x-10-9/17/)

> Like the HFS+ compression feature introduced in Snow Leopard, compressed memory trades relatively abundant CPU cycles for decreased disk I/O.

### [iCloud Drive](https://arstechnica.com/gadgets/2014/10/os-x-10-10/15/)

> Replacing the existing iCloud document storage is the new iCloud Drive—and I do mean replacing.

### [App Extensions](https://arstechnica.com/gadgets/2014/10/os-x-10-10/16/)

> Though they are distributed inside an application’s bundle, Extensions are not just applications launched in a special mode. They are separate, purpose-built binaries, with their own containers, code signatures, and entitlements.

### [Handoff](https://arstechnica.com/gadgets/2014/10/os-x-10-10/18/)

> When all the dots connect, it really is a neat experience. Now let’s talk about those dots.

### [Swift](https://arstechnica.com/gadgets/2014/10/os-x-10-10/21/)

> Perhaps this mission statement is so grandiose—so preposterous, even—that readers are inclined to gloss over it or dismiss it. But it’s the key to understanding the design of Swift.
