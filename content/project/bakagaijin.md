---
title : bakaGaijin
comment: true
date : 2016-05-01
mermaid: true
summary : bakaGaijin is an open source (MIT License) library that allows seamless cross resource communication across Lua virtual machines in MTA. It allows you to pass functions, tables (by reference), and such complex types that the C interface is not actually capable of sending. It is implemented in pure Lua.
---

bakaGaijin is an [open source](https://github.com/Luca-spopo/bakaGaijin/tree/master/bakaGaijin) (MIT License) project that emerged from the (larger and closed source) [Ash](/project/ash) project.

It aims to provide seamless cross resource communication across Lua virtual machines in MTA.

<!--more-->

# Some Background

>[Multitheft Auto (MTA)](https://github.com/multitheftauto) is an open source modification of Rockstar's very successful (and old) game Grand Theft Auto: San Andreas. It adds support for multiplayer (GTA:SA is originally single player only), and lets the server hosting the game change every aspect of the game at run time through Lua scripts that interact with hooks provided by the engine.

For modularity, it encourages developers to split and decouple their scripts as "resources". A resource has one or more script files that run in sequence on one Lua Virtual Machine. There is exactly one VM per resource, and as such resource A does not suffer from memory leaks or crashes occurring in a resource B.

As two different resources sit on different VMs, the only way for them to communicate is through MTA (i.e. the C interface exposed by MTA). MTA provides few approaches for any resources to communicate with each other.

# Before bakaGaijin

1. MTA has an element tree that is synched for every VM. Any event that is triggered on an element in one VM is also triggered in all other VMs. Elements are objects that are implemented by the C code, and can thus be transferred across VMs as [opaque objects](https://en.wikipedia.org/wiki/Opaque_data_type).

  * Elements can also contain properties (called "element data"). These are string keys mapped to tables or primitive data types. Tables stored in this way are stripped of any non-storable keys/values.
  * Functions/Threads cannot be stored as element data, and the keys cannot be anything other than strings.
  * There have also been some bugs in the past where element data was not behaving properly.
  * As such, elements and their behavior are coded in C and do not benefit from Lua's principles or from Lua's well known reliability.
  * Tables "fetched" from element data are copied by value when sent to the VM, and thus any changes made to them do not reflect on the element data until they are manually copied back. This leads to thread safety issues that need to be stepped around.
  * MTA has an event system for these elements, and these elements form a tree that the event is propagated through.  

    Thus, element data and event handlers on elements are one way of communicating with other resources.

2. MTA offers the concept of "exported" functions. A resource may declare (in its configuration files) that it is exporting certain global functions. Other resources are then allowed to call such exported functions through the syntax of `exports.remoteResourceName.functionName(exports.remoteResourceName, ...)`.
  * This changes the signature of the originally exported function, as it has an additional self parameter now.
  * The function must be declared as exported statically before the resource is loaded.
  * The function must be global and named. Anonymous functions and local functions aren't allowed.
  * The configuration is stored in an XML file. Nobody wants to touch the XML files.
  * The parameters and return values are still stripped of any values the C interface cannot comprehend (functions, threads, tables values/keys that are functions/threads)
  * Any tables that are returned or passed as parameters are still copied by value.

3. The third option is file or database operations. Not a feasible solution.  


# The Problem

While _usually_ this decoupling of resources is not a problem as resources rarely talk to each other, but there are many valid use cases where two resources need to be coupled more tightly (e.g. [dxGUI](https://wiki.multitheftauto.com/wiki/Resource:DxGUI), [Ash](/project/ash/), [DataBase management](https://community.multitheftauto.com/index.php?p=resources&s=details&id=546), [Debugging systems](https://forum.mtasa.com/topic/84461-closed-beta-debug-console-join-now/)).

MTA's inability to pass abstract/contextual datatypes means that the developers of such resources need to sidestep these problems, usually through opaque handles and a bunch of functions to change their state.

# The Solution

bakaGaijin is a framework where your resource can expose any value it wants during runtime. These
values do not have to be global, or even currently referenced. This can be done in one simple line of code
as `bakaGaijin.SomeLabel = value`

bakaGaijin also provides a way to get such exposed values from other resources. This is also done
easily as `foreignValue = bakaGaijin("RemoteResourceName").SomeLabel`

This may not seem complicated, but consider a case like this:  

```lua
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
```

Also, let me tell you how easy it is to set up bakaGaijin. It only uses one exported function, and this function is a multiplexer for all communications. All you need to declare is one statically exported function called `bakaGaijin_export`

ABC in resource3 and resource2 is also obviously not actual references to the table in resource1 (The C interface is incapable of that). The behavior of the handler is emulated using clever metaprogramming. Lua uses metatables for this, which is similar to "object prototypes" in other languages.

So bakaGaijin has been a leaning experience in the topics of API design, metaprogramming, memory management, multi-threading, and design in general.

If the data exchanged in these operations is immutable and serializable, then they are sent as they are without any subsequent performance loss.
However, if they are tables, closures, or such mutable types then they are automatically "prepared" so that they can be sent across safely. This preparation is done by:  

  * Storing them in an internal table on the host resource (The one that sent them)
  * Sending a handle of this object to the client resource (The one that requested it)
  * Generating a pseudo-object client side that behaves just like the actual object that was sent. This object would communicate with the host resource whenever a get/set/call is performed on it.
  
Exported functions are the most performant way of introducing the concept of callback functions (but this requires preparation). The event system is a little slower, but does not require any preparation before runtime. bakaGaijin uses an exported function to communicate with other resources, but most of the code is agnostic of this and it can be easily changed to use the event system instead.

bakaGaijin also has it's own "meta garbage collector" (I don't know what else to call it) that manages the deallocation of values no longer accessible to other resources via bakaGaijin. So you do not need to worry about any memory leaks.

If you just want to use bakaGaijin for your own project, then check out "Test1" and "Test2" (to be run in parallel) on [GitHub](https://github.com/Luca-spopo/bakaGaijin). The source code is heavily commented and reading it cursively should be enough to understand how to use it.

The rest of this page explains how it works.

# How it works

Let's see how bakaGaijin does its magic.

# Some Vocabulary

* bakaGaijin

Either the script itself, or an instance of the script running on a particular VM. An instance of bakaGaijin.lua (or its minified version) must be running on every VM that is using bakaGaijin to communicate.

* expose
* access

I will make a distinction between the term "exposed" and "accessible".

Consider this:
```lua
	--//resource1
	local x = {y=true}
	bakaGaijin.x = x

	--//then at resource2
	local x = bakaGaijin("resource1").x

	--//then at resource1
	bakaGaijin.x = nil
	--//x is not longer EXPOSED (A resource cannot use bakaGaijin("resource1").x to access x)

	--//then at resource2
	--//x from resource1 is still ACCESSIBLE to resource2, as it already got a reference earlier.
	print x.y --//true
	x.y = false

	--//but it is not EXPOSED
	print bakaGaijin("resource1").x --//nil
```
Accessible is when a resource *can* read/write an original object exposed earlier.  
Exposed is when a resource can get the reference to the original object from the host resource using bakaGaijin.

* original object

If a resource exposes a value (string, function, table, number etc) using bakaGaijin, that value is the original object.  
In `bakaGaijin.label = x`, `x` is the original object. Only really makes sense when x is a <em>candidate for tokenization</em>.

* token_id

Each original object is allotted a token_id when a <em>PT</em> is constructed for it for the first time. There is a guarantee that no two original objects will have the same token_id at the same time. The token_id of an original object does not change as long as bakaGaijin is keeping it accessible.

* candidate, candidate for tokenization

A value that has a type that cannot be transferred across resources without information loss.  
A value is NOT a candidate for tokenization if it is immutable and serializable.

A candidate is of type `table` or `function`. Threads are also candidates, but not supported by bakaGaijin at the time of writing.
All values of type `function` or `table` are candidates UNLESS they are an <em>AT</em>

>My apologies, but "token" or "tokenization" in bakaGaijin has nothing to do with tokenization in compilers.
>"Serialization" would be a better term, but "tokenization" stuck somehow

* host, host resource

Resource that contains the original object.

* client, client resource

Resource that wishes to use an original object that it does not contain.

* primitive

Any value of type `boolean`, `number`, `string`, `nil` or `userdata`

* GC

Garbage collector. "GCed" means garbage collected.  

Here is a joke:
>If Java had true garbage collection it would collect itself.

* AT, Active Token

A value present on the client resource. Client resource uses an AT as a handler/controller to interact with original object on the host resource. An AT is always <em>interned</em>

* interned, interning

A term borrowed from Lua's [string interner](https://en.wikipedia.org/wiki/String_interning). May be a misnomer.

It basically means that active tokens are cached and reused, and there is a guarantee that one original object will only corresponding to one or zero AT in a given resource.

Active tokens are interned, which means that if a a resource receives the same <em>passive token</em> again, it reuses the active token already made for it.

* PT, passive token

 * Can be transferred across resources without information loss.
 * Used to represent an original object
 * Used as an intermediate representation of an original object when two resources are communicating via bakaGaijin.
 * AT is constructed from a PT at the client resource.
 * Contains the token_id of the original object it represents, and a non-guessable stamp. Even though token_id can be used to uniquely identify an original object in a host resource, stamp must also match to ensure data integrity.
 * A table is considered to be a PT if it has `"__gaijin_res"` as a key to a truthy value.
 * PTs are also interned like AT, and there is a guarantee that there cannot be more than one PT for the same original object in the host resource.  


* elem, element

primitive, AT or candidate

* gaijin

![assets/gaijin.jpg](/img/gaijin.jpg)

# Some bakaGaijin concepts

* bakaGaijin_export 

bakaGaijin_export is a global constant of type function, which is exposed to other resources via MTA's export system. This function is the only way for bakaGaijin to gets information from another resource. It can perform various duties depending on the first argument it gets, and is essentially a multiplexer.

bakaGaijin_export is usually called by OTHER RESOURCES, not the host resource that defined it.
```lua
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
		--Omitted: Long if-else ladder.
		else
			error("bakaGaijin_export called incorrectly by "..sourceResource)
		end
	end
```
* Multimap

I will not explain how it does it, but multimap.new(N) creates a table that maps N keys to a value.
It mainly just provides syntactical sugar, and the same functionality can be accomplished using trees.

The implementation is flawed and will cause memory leaks, so do not reuse it. However, the way bakaGaijin uses it ensures that no memory leaks occur.

The main (and only) reason its used is because the resulting table is null safe and the syntax is convenient. (So we can pretend that Lua has `?.` operator like Groovy)

Also, it stores the values in a weak table, so they fall off if not referenced elsewhere.
```lua
	local mm = multimap.new(2)
	mm[1][2] = "Value" --Does not complain about mm[1] being null
	assert(mm["I don't exist"][1] == nil) --no error
	assert(mm[1][2] == "Value") --no error
```
If you want to know how it works, it uses recursion and metatables. Just search for the this definition in the source code:
```lua
	local multimap = {}
```
* gaijinPool

A table at the host resource that maps token_id to original object.

* stampLookup

A table at the host resource that maps token_id to a stamp value. This stamp value is set when a PT is constructed for the original object.  

Not necessarily a time stamp, but used to ensure that a newly exposed original object with the same token_id as an older expired one is not misinterpreted as the older one by a different resource.  
Also acts as a "password" as other resources can't fake the stamp unless they actually got the PT from somewhere. (token_id may be guessable, but stamp is not)

* tokenLookup  
  This table serves two purposes.  
  * At the client resource, maps an AT to the PT used to construct it.
  * At the host resource, maps a candidate to the PT constructed for it (if any).

 This is a key-weak table and values fall off if the AT/candidate is no longer referenced anywhere.

* ATinterner

This is a multimap used to ensure that ATs are interned.
It maps (hostResourceName, token_id) to an AT

The AT is stored weakly, and does not prevent it from being GCed.

* ATmeta

A metatable that lets ATs representing a table behave as if they *are* the table.
Implementation is in the source code. Search for the string below to find its definition.
```lua
	`--Generate metatable for an AToken being made form a PToken`
```
* getPTokenFromElem

  A function that takes a value as argument, and returns something that is guaranteed to be transferable across resources without information loss.  
  The returned value is also guaranteed to be able to uniquely identify the argument value.

  Acts as a filter for all values going from a host resource to a client resource.

  If argument is not a candidate, returns it as it is.  
  If it's an active token, then returns the passive token associated with it (from tokenLookup).  
  If it is a candidate, then returns a PT representing it.

  * If a PT for the candidate exists in tokenLookup, then returns that cached value
  * If the PT doesn't exist, then constructs one, adds it to tokenLookup, and returns it.

Look at appendix below for implementation details.

* getElemFromPToken

  Acts as a filter for all values coming from a host resource to a client resource.

  Takes one argument.  
  If it received a valid passive token:  

  * fetches and returns associated object (if this resource is the host for the PT)
  * or reuses an AT if it exists in ATinterner (if this resource is a client for the PT)
  * or constructs an AT (and updates ATinterner and <em>ATcache</em>) (if this resource is a client for the PT)

Active tokens and non-candidates are returned without any changes.

Look at appendix below for implementation details.

* getProp(client, token_id, key)
* setProp(client, tokenid, key, value)
* callFun(client, tokenid, ...)

Functions that are called on the host when a client attempts to get/set a value on an AT (or call an AT) that represents an original object in the host resource.

These are actually called by bakaGaijin_export, which multiplexes these (and other functions) using opcodes.

* pairs, ipairs

ipairs and pairs are iterators used in Lua to enumerate the keys and values of a table.

In Lua 5.2, the `__pairs` and `__ipairs` metamethods were added, allowing us to define how pairs and ipairs should behave over a table.

We are working in Lua 5.1 and do not have this luxury.

`ipairs` and `pairs` do not work properly over an AT.
To make ATs behave more like tables, `ipairs` and `pairs` as global functions have been overridden (decorated) with versions that can deal with ATs.

Specifically, when the new ipairs or pairs encounters an AT, instead of iterating over it, it calls bakaGaijin_export on the host resource with the opcode `pairs` or `ipairs`. The host resource then constructs a table of PTs and returns that, which is what pairs/ipairs iterates over.

The original versions of pairs and ipairs are still available as raw_pairs and raw_ipairs.

This can be observed in the source code if you search for the string  
```lua
	----OVERRIDES-----
```
The functions called by bakaGaijin_export when it receives `pairs` or `ipairs` as an opcode are `local function pairsByID(tokenid)` and `local function ipairsByID(tokenid)`, which can be searched for in the source.

* Exposed variables

bakaGaijin uses metatables to provide its syntax of `bakaGaijin.label` and `bakaGaijin("resource").label`

`bakaGaijin` itself has its metatable set to bakaGijin_meta
```lua
	local bakaGaijin_meta = {
		__call = function(t, rec)
			local proxy = {res_name = rec}
			setmetatable(proxy, recmeta)
			return proxy
		end
	}
```
So, `val = bakaGaijin.label` and `bakaGaijin.label = val` actually do use bakaGaijin as a raw table. `label` must not be a candidate value, care must be taken regarding this by the user. I recommend using only string or number keys, and future versions may only allow string/number keys.

In the source code you will find a table named `nameCache`. This is actually `bakaGaijin`.  

Later in the code:
	`bakaGaijin = nameCache`

Calling bakaGaijin as a function with argument `rec` returns an object with its key `res_name` set to `rec` and its metatable set to `recmeta`
```lua
	local recmeta = {
		__index = function(t, index)
			return getElemFromPToken(exports[t.res_name]:bakaGaijin_export("s2t", index))
		end,
		__newindex = function()
			error("You cannot set data for another resource.", 2)
		end
	}
```
Thus, if this object returned by bakaGaijin("someResource") is indexed, then it actually calls bakaGaijin_export on the host resource with the opcode `s2t` and the label key as an argument. The value returned by bakaGaijin_export is filtered using getElemFromPToken and returned to the user.

Snippet from bakaGaijin_export:
```lua
	function bakaGaijin_export(typ, tokenid, stamp, ...)
		--IN THIS CASE, TOKENID IS NOT ACTUALLY TOKENID, IT IS THE KEY THAT WAS REQUESTED
		local sourceResource = getResourceName( sourceResource )
		if typ=="s2t" then
			return getPTokenFromElem(nameCache[tokenid])
		--omitted: elseif ladder
		end
	--omitted: rest of the function
	end
```
`s2t` stands for "String to token", which resolves a string to a passive token.


# Finally an explanation

Ok, don't worry if you didn't understand all those terms, just keep visiting the definitions as you hear them in places.

I expect you to know how [MTA exported functions](https://wiki.multitheftauto.com/wiki/Call) are called, how garbage collection works, and basic Lua. Knowing metatables in Lua also helps.

Know that bakaGaijin("remoteResourceName") returns a "special" table (a table with something called a metatable) that, when indexed calls `exports["remoteResourceName"]:bakaGaijin_export("get")` and returns the value it gets after running <em>getElemFromPT</em> on it.

>getElemFromPT?

getElemFromPT is a function that acts as a "filter" of sorts. Everything that is coming to this resource from another resource goes through this filter first. Most items go through unaffected, but PTs are converted into ATs or their respective original objects.

>PT? AT? original objects?

Original object is what the other resource "tried" to send to you, but could not possibly have (functions, for example)

So we convert it into a PT instead, and the PT gets sent without any problems.

Once we get the PT, we convert it into an AT, which is another "special table" (or sometimes a function) that updates the values of the original object whenever its own values are changed, or asks the other resource to call its own function when the AT is called.

We also have a getPTfromElem function that filters everything that goes out, converting it into a PT if needed.

EDIT: <a href="https://en.wikipedia.org/wiki/Marshalling_(computer_science)">Here</a> is a wikipedia article discussing the topic (Vocabulary is different from mine)

Here is a diagram I made that attempts to explain PTs and ATs

{{<sequenceDiagram>}}
participant Host
participant getPTfromElem
participant MTA
participant getElemFromPT
participant Client
note over Host, getPTfromElem: Host and getPTfromElem are\nin the virtual machine to\nwhich the object is native.
note over Client, getElemFromPT: Client and getElemFromPT are\nin the virtual machine which\nwants to access the object.
note over MTA: MTA has the C interface\nthat connects the\ntwo virtual machines.
note over Host, Client: Values that are immutable and serializable (e.g numbers and strings) are sent across as they are
Host-getPTfromElem: "Hello" : string
getPTfromElem-MTA: "Hello" : string
MTA-getElemFromPT: "Hello" : string
getElemFromPT-Client: "Hello" : string
note over Host, Client: But non-immutable or non-serializable data is sent through a stub.
Host-getPTfromElem: f : function
getPTfromElem-MTA: PT(f) : {hostid, obj_id}
MTA-getElemFromPT: PT(f) : {hostid, obj_id}
getElemFromPT-Client: AT(f) : function
{{</sequenceDiagram>}}

`<function> f` is the original object.

The green star is the process of converting an original object to a PT.
The blue star is the process of converting a PT to an AT.

PT(f) is implemented as this:
```lua
	{
		__gaijin_id = XYZ, --//Some number to uniquely identify function f
		__gaijin_res = Host_Resource_Name,
		--// (__gaijin_res, _gaijin_id) can together be used to uniquely identify an original object.
		__gaijin_stamp = PQR, --//Some number to ensure integrity
		__gaijin_fun = true --//Tells the client resource that the original object is a function
	}
```
AT(f) is implemented as this:
```lua
	function(...)
		return getElemFromPT(
			exports[PT.__gaijin_res]:bakaGaijin_export(
				"call", PT.__gaijin_id, PT.__gaijin_stamp, ...)
			);
	end
```
An AT for a table is a bit more complicated as it uses metatables to fire callbacks for get and set operations.

bakaGaijin_export is the only exported function and can do a lot of tasks for us depending on the first argument it gets. For example, in this case, `"call"` told it to call a function and return the value. Needless to say, the function parameters and return values also pass through getElemFromPT and getPTfromElem

Also note that resources can send ATs to each other. The AT would get converted to the original PT it was calculated from, and then sent to other resources. The other resources will convert it into ATs again in their own VMs. Unless the original object belonged to one of the resources... in that case the resource would realize that the PT represents an object in its own machine and `getElemFromPT(PT(f))` would be the original object itself.

# Meta Garbage Collection, Virtual Virtual Machine Networks and Hacks

* Subscriptions

I have already highlighted before, the need for a "meta garbage collector" in bakaGaijin.

Since references are still alive and may be accessible when they are no longer exposed, we need to have a mechanism to delete them when no resource at all has access to them, and keep them alive otherwise.

...ok, I can't type anymore. This is very tiring.

Less reference manual, more short story now.

Short story:

bakaGaijin has a "sub" opcode that a remote resource calls when it has subscribed to a particular original object.  
This subscription is stored in an internal table called `ownLookup`  
`ownLookup` is a multitable that maps (remoteResourceName, tokenID) to TRUE or NIL.
TRUE meaning that remoteResource has access to original object represented by tokenID, and NIL meaning otherwise.  
The subscription call is fired by the remote resource whenever getElemFromPT gets a valid PT it didn't already have an AT for.
Similarly, there is an "unsub" opcode that unsubscribes a resource to an original object. This is called whenever the remote resource cannot access an AT anymore.

Whenever the host resource gets an unsub for an original object, it checks if there are still any subscribers left.

If there are no more subscribers after an unsub call (no more resources that can access the original object), then the original object is removed from gaijinPool, tokenLookup, stampLookup and ownLookup. The PT is no more, and the original object will get GCed unless the host resource itself is using it.

Lua 5.2 has `__on_garbage_collect` metamethod that works as a destructor, and would have been used to fire unsub calls when an AT is GCed.

However, we are on Lua 5.1, and do not have such a luxury. There is a lot more to explain.

>How do you fire unsub calls?

This is hacky, do not try this at home.

You already know ATinterner, it maps a token_id to an AT weakly. If the AT is GCed, then this table will not contain it anymore.

We also have a table called ATcache (I neglected to mention it before) that maps token_id to a TRUTHY value or NIL. This table is not weak.

ATcache is a "shadow" of ATinterner. For every AT that is put in ATinterner, a truthy value is also put in ATcache.

We also have a timer that calls a function `updateATC` every `ATC_WAIT` milliseconds (Every minute by default).

This function... wait for it....  
<em>CHECKS FOR KEYS THAT ARE TRUTHY ON `ATcache` AND FALSY ON `ATinterner`.</em>

Now before you throw tomatoes at me, let me tell you that this was the only way to do it. Lua 5.1 does not have any callbacks that we can fire on garbage collection (implemented in pure Lua).
It is not very inefficient, don't worry.

Anyway, if ATcache has a value that's truthy, and ATinterner has it as nil, then ATinterner dropped the value, which means it was garbage collected. This results in an unsub call.

Now, here emerges a new problem:

The Lua garbage collector only kicks in if the Virtual Machine is actually low on memory.  
Now that we have created this... large "<em>Virtual</em> Virtual Machine" Network where references are shared among virtual machines... the garbage collector should not be selfish and only kick in when its own Virtual Machine is starving.

If the client resource is under no stress, it will not fire unsub signals regardless of whether or not the host resource is under stress.

bakaGaijin has two strategies to handle this.

One is the most obvious: For every `COLLECTOR_WAITS` calls to updateATC, collect_garbage is called once forcing the client resource to clean up its mess. (Every 10 minutes by default)
```lua
	local LOAD_GAIN_TOLERANCE = 1.4
	--If a resource keeps locking lots of objects and actually uses them, it's allowance is increased.
	--LOAD_GAIN_TOLERANCE tells bakaGaijin how much to increase the allowance each time it's exceeded.
	--A value of 1.4 means allowance will increase by 40%. This makes the GC elastic and dynamic.
	local LOAD_MIN = 100 --The minimum number of items a resource is allowed to lock before it's asked to check it's actual usage and send unsub messages
	local COLLECTOR_WAITS = 10 --Number of bakaGaijin's GC's sweeps before the Lua GC is invoked
	local ATC_TIME = 60000 --Milliseconds between each "sweep" of bakaGaijin's GC
```
The second solution is much more elegant, and makes the first one unneeded (but we keep it anyway).

There is also a table called `loads` which maps a client resource to the number of original objects (belonging to the host resource) it is subscribed to.  
There is another table called `loadsShadow` which maps a client resource to the "last known number of objects actually used" by the client resource.

There is a LOAD_MIN threshold the host has. Clients are not bothered until they cross this threshold.

Once they cross this threshold, bakaGaijin_export is called on the client with the opcode `free`.
This forces the client to call its garbage collector, and then call updateATC.
updateATC then fires unsub messages.

These unsub messages reach the host, which gladly accepts them.
It then REEVALUATES the client resource's usage (Any objects not being used have been unsubbed at this point, so all subbed objects are being used).
Since at this point all the objects are actually being used, loadsShadow's value is set to load's value
`loadsShadow[res] = loads[res]`
If there are lots of subbed objects, then the host realizes the client's need for more memory and a new threshold is set.
New threshold is set as loadsShadow[res] * LOAD_GAIN_TOLERANCE(1.4 by default)

If there are too few subs, and the allowance the client previously had is not justified anymore, then the tolerance is set to a lower level.
Again, using the same formula loadsShadow[res] * LOAD_GAIN_TOLERANCE

The threshold can never be lower than LOAD_MIN (100 by default), which means a client will never be bothered if it keeps less than 100 subscriptions.

That's all folks... I don't know if you understood any of this stuff but I had a duty to document this project.

If you still insist on understanding its workings and this page didn't answer all your questions, then shoot me a mail. :-]