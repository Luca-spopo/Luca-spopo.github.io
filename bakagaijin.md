#TOC("Table of Contents")

$(fromMD( [==[

 #bakaGaijin

bakaGaijin is an [open source](https://github.com/Luca-spopo/bakaGaijin/tree/master/bakaGaijin) (MIT License) project that emerged from the (larger and closed source) [Ash](ash.html) project.

It aims to provide seamless cross resource communication accross Lua virtual machines in MTA.

 #Some Background

If you are already familiar with MTA's resource architecture, then [skip this part](#the_problem).

>[Multitheft Auto](https://github.com/multitheftauto) is an open source modification of Rockstar's very successful (and old) game Grand Theft Auto: San Andreas. It adds support for multiplayer (GTA:SA is originally single player only), and lets the server hosting the game change every aspect of the game at run time through Lua scripts that interact with hooks provided by the engine.

For modularity, it encourages developers to split and decouple their scripts as "resources". A resource has one or more script files that run in sequence on one Lua Virtual Machine. There is exactly one VM per resource, and as such resource A does not suffer from memory leaks or crashes occurring in a resource B.

As two different resources sit on different VMs, the only way for them to communicate is through MTA (i.e. the C interface exposed by MTA). MTA provides few approaches for any resources to communicate with each other.

 #Before bakaGaijin

1. MTA has an element tree that is synched for every VM. Any event that is triggered on an element in one VM is also triggered in all other VMs. Elements are objects that are implemented by the C code, and can thus be transferred accross VMs as [opaque objects](https://en.wikipedia.org/wiki/Opaque_data_type).

  * Elements can also contain properties (called "element data"). These are string keys mapped to tables or primitive data types. Tables stored in this way are stripped of any non-storable keys/values.
  * Functions/Threads cannot be stored as element data, and the keys cannot be anything other than strings.
  * There have also been some bugs in the past where element data was not behaving properly.
  * As such, elements and their behavior are coded in C and do not benefit from Lua's principles or from Lua's well known reliability.
  * Tables "fetched" from element data are copied by value when sent to the VM, and thus any changes made to them do not reflect on the element data until they are manually copied back. This leads to thread safety issues that need to be stepped around.
  * MTA has an event system for these elements, and these elements form a tree that the event is propogated through.  

  Thus, element data and event handlers on elements are one way of communicating with other resources.

2. MTA offers the concept of "exported" functions. A resource may declare (in its configuration files) that it is exporting certain global functions. Other resources are then allowed to call such exported functions through the syntax of `exports.remoteResourceName.functionName(exports.remoteResourceName, ...)`.
  * This changes the signature of the originally exported function, as it has an additional self parameter now.
  * The function must be declared as exported statically before the resource is loaded.
  * The function must be global and named. Lambas and local functions arn't allowed.
  * The configuration is stored in an XML file. Nobody wants to touch the XML files.
  * The parameters and return values are still stripped of any values the C interface cannot comprehend (functions, threads, tables values/keys that are functions/threads)
  * Any tables that are returned or passed as parameters are still copied by value.

3. The third option is file or database operations. Not a feasible solution.  


 #The Problem

While _usually_ this decoupling of resources is not a problem as resources rarely talk to each other, but there are many valid use cases where two resources need to be coupled more tightly (e.g. [dxGUI](https://wiki.multitheftauto.com/wiki/Resource:DxGUI), [Ash](ash.html), [DataBase management](https://community.multitheftauto.com/index.php?p=resources&s=details&id=546), [Debugging systems](https://forum.mtasa.com/topic/84461-closed-beta-debug-console-join-now/)).

MTA's inability to pass abstract/contextual datatypes means that the developers of such resources need to sidestep these problems, usually through opaque handles and a bunch of functions to change their state.

 #The Solution

bakaGaijin is a framework where your resource can expose any value it wants during runtime. These
values do not have to be global, or even currently referenced. This can be done in one simple line of code
as `bakaGaijin.SomeLabel = value`

bakaGaijin also provides a way to get such exposed values from other resources. This is also done
easily as `foreignValue = bakaGaijin("RemoteResourceName").SomeLabel`

This may not seem complicated, but consider a case like this:  

	--At resource1
	bakaGaijin.ABC = {x=0}

	--Then, at resource2
	local ABC = bakaGaijin("resource1").ABC
	
	--Then, at resource3
	local ABC = bakaGaijin("resource1").ABC
	
	--Then at resource1
	bakaGaijin.ABC = nil
	--The table is now not referenced anywhere in resource1, but it is still alive and will not be deleted.

	--Then, at resource2
	ABC.x = ABC.x+1;

	--Then, at resource3
	print("ABC.x is "..ABC.x) --ABC.x is 1
	ABC = nil
	--Only resource2 has a reference to ABC at this point

	--Then, at resource2
	ABC = nil
	--ABC is now a candidate for deletion, and resource1 will delete it eventually.

Also, let me tell you how easy it is to set up bakaGaijin. It only uses one exported function, and this function is a multiplexer for all communications. All you need to declare is one statically exported function called `bakaGaijin_export`

ABC in resource3 and resource2 is also obviously not actual references to the table in resource1 (The C interface is incapable of that). The behavior of the handler is emulated using clever metaprogramming. Lua uses metatables for this, which is similar to "object prototypes" in other languages.

So bakaGaijin has been a leaning experience in the topics of API design, metaprogramming, memory management, multithreading, and design in general.

If the data exchanged in these operations is immutable and serializable, then they are sent as they are without any subsequent performance loss.
However, if they are tables, closures, or such mutable types then they are automatically "prepared" so that they can be sent accross safely. This preparation is done by:  

  * Storing them in an internal table on the host resource (The one that sent them)
  * Sending a handle of this object to the client resource (The one that requested it)
  * Generating a pseudo-object client side that behaves just like the actual object that was sent. This object would communicate with the host resource whenever a get/set/call is performed on it.
  
Exported functions are the most performant way of introducing the concept of callback functions (but this requires preparation). The event system is a little slower, but does not require any preparation before runtime. bakaGaijin uses an exported function to communicate with other resources, but most of the code is agnostic of this and it can be easily changed to use the event system instead.

bakaGaijin also has it's own "meta garbage collector" (I don't know what else to call it) that manages the deallocation of values exposed to other resources via bakaGaijin. So you do not need to worry about any memory leaks.

If you just want to use bakaGaijin for your own project, then check out "Test1" and "Test2" (to be run in parallel) on [GitHub](https://github.com/Luca-spopo/bakaGaijin). The source code is heavily commented and reading it cursively should be enough to understand how to use it.

The rest of this page explains how it works.

 #How it works

 ##Some Vocabulary

* bakaGaijin

Either the script itself, or an instance of the script running on a particular VM. An instance of bakaGaijin.lua (or its minified version) must be running on every VM that is using bakaGaijin to communicate.

* original object

If a resource exposes a value (string, function, table, number etc) using bakaGaijin, that value is the original object. In `bakaGaijin.label = x`, `x` is the original object. Only really makes sense when x is a <em>candidate for tokenization</em>.

*  candidate, candidate for tokenization

A value that has a type that cannot be transferred accross resources without information loss.
A value is NOT a canditate for tokenization if it is immutable and serializable.

A candidate is of type `table` or `function`. Threads are also candidates, but not supported by bakaGaijin at the time of writing.
All values of type `function` or `table` are candidates UNLESS they are an <em>AT</em>

>My apologies, but "token" or "tokenization" in bakaGaijin has nothing to do with tokenization in compilers.
>"Serialization" would be a better term, but "tokenization" stuck somehow

* host, host resource

Resource that contains the original object.

* client, client resource

Resouce that wishes to use an original object that it does not contain.

* primative

Any value of type `boolean`, `number`, `string`, `nil` or `userdata`

* AT, Active Token

A value present on the client resource. Client resource uses an AT as a handler/controller to interact with original object on the host resource. An AT is always <em>interned</em>

* Interned, Interning

A term borrowed from Lua's [string interner](https://en.wikipedia.org/wiki/String_interning). May be a misnomer.

It basically means that active tokens are cached and reused, and there is a gaurentee that one original object will only correspong to one or zero AT in a given resource.

Active tokens are interned, which means that if a a resource receives the same <em>passive token</em> again, it reuses 

* PT

Can be transferred accross resources without information loss. Is technically also a candidate.
--Used to pass a candidate to another resource. AT is constructed from a PT at the client resource.
--candidate = table or function, but not AT
--elem = primative, AT or candidate

* Omitted

If I have omitted something from code samples, then it was noise that doesn't help in explaining the current subject, or pertains to a topic that will be explained later.

* bakaGaijin_export, exported function, export  

bakaGaijin_export is a global constant of type function, which is exposed to other resources via MTA's export system. This function is the only way for bakaGaijin to gets information from another resource. It can perform various duties depending on the first argument it gets, and is essentially a multiplexer.

bakaGaijin_export is called by OTHER RESOURCES, not the host resource that defined it.

	function bakaGaijin_export(typ, tokenid, stamp, ...)
		local sourceResource = getResourceName( sourceResource )
		--sourceResource is the remote resource that called bakaGaijin_export
		
		--Performs various operations depending on the first parameter,
		--which is an opcode of sorts.
		if typ=="s2t" then
			return getPTokenFromElem(--[[Omitted]])
		elseif typ=="free" then
			return bakaGC()
		end

		--Asserts some checks to ensure integrity
		if not gaijinPool[tokenid] or stamp ~= stampLookup[tokenid] then
			return nil
		end

		--Operations for opcodes that required the checks above
		if typ=="get" then
			return getProp(sourceResource, tokenid, ...)
		elseif typ=="set" then
			return setProp(sourceResource, tokenid, ...)
		--Omitted: Long ifelse ladder.
		else
			error("bakaGaijin_export called incorrectly by "..sourceResource)
		end
	end

>UNDER CONSTRUCTION

]==]))