---
title : "Ash"
summary : "Ash is a closed source UI library for MTA implemented in pure Lua. It provides its own window management system, own event system, own input system and own tweening system. It has a foreign interface so cool that it was forked as its own open source project called bakaGaijin."
tags: ["Lua", "MTA"]
date: 2016-10-10
mathjax : true
---

![ash.jpg](/img/ash/ash.jpg)

Ash is a framework/library for MTA that gives you the most flexible and most beautiful UI.
Ash does not only provide a beautiful GUI, it also aims to wrap over all other UI. For now that includes GUI, keyboard input and mouse input.

# The Problem

[Multitheft Auto](https://github.com/multitheftauto) is an open source modification of Rockstar's very successful (and old) game Grand Theft Auto: San Andreas. It adds support for multiplayer (GTA:SA is originally single player only), and lets the server hosting the game change every aspect of the game at run time through Lua scripts that interact with hooks provided by the engine.

This means we can add functionalities that did not originally exist in the game.

We can add a clan system that lets clan leaders set clan roles, kick members, maybe drop a "Message of the day". We can add our own chatbox to let different clients chat with each other. We can let them own particular vehicles, or houses, and provide them with a UI to buy/sell such assets. [The possibilities are endless](https://community.multitheftauto.com/index.php?p=resources).

To design the UI that would be required with such functionalities, MTA uses and provides [CEGUI](https://en.wikipedia.org/wiki/CEGUI). It provides Lua with functions that let it create CEGUI components and add listeners to them, and control their life cycle.

CEGUI components look something like this:  
![CEGUI](/img/ash/CEGUI1.png) ![CEGUI](/img/ash/CEGUI2.png)  

They do not look _bad_, but very often they do not match up with the theme of the rest of the UI. Imagine using that GUI while the bottom right of your screen looks like this:  
![Theme contrast](/img/ash/speedo.jpg)  
As a result, _user experience suffers_, and most importantly, my scripts don't look as beautiful as they can.

# History

CEGUI was made as a very flexible and skin-able GUI Library, but it is implemented in C++, Lua only gets the hooks that MTA exposes to it. MTA only ships with one theme of CEGUI, and as such there is no way for a server to change the theme on a client. An analogy would be MTA's CEGUI being a Chrome/Firefox/Edge native library, while the server can only send out Javascript (Lua in this case)

How would the JS community cope with this? They would use a canvas to draw their own GUI one primitive rectangle at a time, and implement the entire library in pure javascript.
That is the approach I decided to follow, and the result was Ash. MTA exposes some very primitive directX drawing functions, and Ash takes it from there.

Before I started work on Ash, the first question I asked was: "Has this been done already?". Reinventing the wheel is very educational, but I needed Ash for my production server so I could not afford to waste time.
The answer is yes, There exists a library called [dxGUI](https://forum.mtasa.com/topic/27664-rel-dxgui/) which aimed to replace CEGUI. I forked it and inspected its source code. While the code itself was written beautifully, the project did not dream big. It simply emulated CEGUI along with (what I perceive as) its pitfalls.
It succeeded at being a pure Lua implementation, but the only new features it added were themes.
These themes were actually static images. The renderer would take parts of these static images to construct its components. As a result, different "themes" were just reskins of the exact same shape using different textures.

# The Solution

 ![CEGUI](/img/ash/CEGUI3.jpg)  ![Ash](/img/ash/ash1.jpg)  

<small>CEGUI (left) vs Ash (right), don't mind the typo</small> 

Ash is very flexible and skin-able. I insist that it's even more flexible and skinable than CEGUI.
Right now it has Panes, Input boxes, Labels, ImageBoxes, Tabs, and some other components. It's missing some basic components like check boxes, radio boxes, scroll bars etc. But the beauty is that _they can be implemented by just dragging component files into a particular folder_. Adding new themes is _also as simple as adding files to a directory_. How big would such files be? Just 50-100 lines of code. Ash already provides all the window management, the components just have to maintain their own state, add event listeners, and conform to specification.

Ash was not just designed just to succeed CEGUI, it was designed to give all the power possible to the Lua programmer.

Ash is different. Ash themes are not images, they are lua files. They provide a function that is called whenever the view is to be updated, and provide hooks to let the theme have very fine control over _exactly_ how it is rendered. It even lets the theme have it's own state information so that it can implement animations and the likes independent of whether or not the component itself is aware of it.

# Crowd-sourcing, Logical Independence, and Decoupling

Another thing Ash does better is that it decouples components from their renderers.
If you were to add an implementation of radio boxes to Ash, then you would create one file to define the component (state information and events about the radio box itself, such as it's coordinates, visibility, alpha, onClick, checked etc), and then add a separate function to the theme which would deal with how it is rendered (As a square, or as a circle, or perhaps even some sort of slider).

In effect, person A can make a component called RadioBox, and add the functions for it to the default theme. Person B could decide to change what a RadioBox looks like, and create some other theme with some other functions that implement the rendering differently.

I expect Ash to have a lot of community created content when it gets its public release.

One problem with this approach is that a component may not be implemented in the particular theme that is being used. I have good news: Ash themes use prototype inheritance and if the current theme does not have functions to render a component, it falls back to a theme higher up in the prototype chain. The default theme is usually on top of the prototype chain (I expect the person who made the component to have made a vanilla version of the renderer and added it to the default theme at least.)

Ash assumes that all renderers and themes are untrusted, and as such the global environment is sanitized and read-only, so that renderers do not have access to anything they can use to aid the forces of evil.

# Stateful Renderers

I use the word "Theme". The system is best explained through code. This is what a theme looks like in Ash.

```lua
	--A theme called "Foobar"
    local Foobar = {}
	do
		local thistheme = Foobar;
		local name = "Foobar"
		AshTheme.addTheme(thistheme, name)
		thistheme.ashName = "AshTheme: "..name
		thistheme.meta = {__index = thistheme, __tostring = gettype}
		setmetatable(thistheme, AshTheme.Default.meta)

		--At this point we have set up the prototype chain, this theme looks up to Default

		--Now some easy to edit parameters regarding font, colours and the like
		
		thistheme.bgcolor = tocolor( 58, 69, 77 )
		thistheme.fgcolor = tocolor(194,94,78)
		thistheme.fgcolor2 = tocolor(194,94,78)
		thistheme.fgcolor3 = tocolor(94,94,178)
		thistheme.color_danger = tocolor(200,100,100)
		thistheme.color_go = tocolor(94,134,78)
		thistheme.textcolor = tocolor( 200, 200, 100 )
		thistheme.textcolorhead = tocolor( 230, 120, 100 )
		thistheme.font1 = "default"
		thistheme.font1b = "default-bold"
		thistheme.font2 = dxCreateFont("themes/Foobar/light.otf", 12)
		thistheme.font2b = dxCreateFont("themes/Foobar/bold.otf", 12)

		--init contains functions that (if existent) should be called when a component is first rendered
		thistheme.init = {}
		local init = thistheme.init

		--clear contains functions that should be called (if they exist) when component's theme is changed or it is removed
		thistheme.clear = {}
		local clear = thistheme.clear

		--This function is called by Ash before a component named Test is rendered for the first time
		function init.Test(self, themecontext)
			--self is a READ ONLY version of the Test component, themes are for representing the data, not changing the data
			--themecontext is an empty table that is available to the renderer as long as the component is to be rendered. It is discarded if the theme is changed or component is destroyed.
			
			--This function is only visited once, so we can do heavy tasks like creating a texture
			themecontext.myTexture = Texture.new("bla.jpg");
			themecontext.height = 0
		end

		function thistheme.Test(self, themecontext)
			--This function is called every time the component needs to be redrawn
			if themecontext.height < self.height then
				--Increase themecontext.height every frame until it reaches self.height
				themecontext.height = math.min(themecontext.height*1.01, self.height)
			end
			--Draw a rectangle who's height is taken from themecontext.height
			dxDrawRectangle( 0, 0, self.width, themecontext.height, self.fgcolor or thistheme.fgcolor)
			dxDrawText("Hello", 0, 0, 100, 100, 0, themecontext.myFont)
		end

		function thistheme.Test2(self, themecontext)
			--Do nothing
		end
	end
```

In the following lines, "renderer" refers to `thistheme.Test`, `init.Test` and `clear.Test`

The code above declares a Theme called Foobar, which implements renderers for components called Test and Test2. The renderer can maintain state information in a table called `themecontext` which is maintained and passed as a parameter to the renderer. A read-only version of the component is also passed to the renderer as "self" to let it poll data (like text or checked status) from it.

This particular theme draws Test as an **animated** box with hello written on the top left. The box is animated because it starts as a thin line and then turns into a rectangle over time. Its height increases over time. This behavior is **not** defined by the component, but by the theme. The theme maintains its own state and functions to implement the animation.
Such a thing is not possible in CEGUI or dxGUI.

Note that I _may not_ have implemented all the things that I have mentioned here. Notably, the `clear` function for renderers is not called (Because there is no theme yet that uses it).

Also note that `thistheme.Test` increases `themecontext.height` by a factor of 1.01 _every render_.
In the current implementation, every render *is* every frame, but the actual rate at which the renderer is called is unspecified. I am working on a system to cache the last drawn image and keep it until an update is propagated by any children, and in that case the renderer would be called less often. The correct way to implement a "height increasing window" as shown here would rely on polling the system time every render. Perhaps the time elapsed since last call can also be provided as a parameter in future versions.

`thistheme.Test2` explicitly has a renderer that does nothing. If such a component is using this theme, it would not show up on the screen at all.

If this theme is used to render `thistheme.Test3`, which is not implemented, it would fall back to the Default theme, which this theme inherits from.
Another theme can further inherit from this Foobar theme, that's the usual way prototype inheritance works.

# Theme is not a global property

Every component has a "theme" property which is either null, or points to a theme.
If it's theme is null, then the theme is inherited from the parent, or grandparent, or somewhere up the prototype chain. (Just as themes inherit from themes, component instances inherit themes from their parents in the display tree)

Thus, you can mix and match themes. You can have a window using ThemeXYZ, with 3 input boxes each of which employs a different theme. It would not look good, probably, but it's possible.
Moreover, themes _automatically and dynamically change_ (unless they are explicitly specified) if the display tree is changed, with components inheriting themes from their new parents.

# Components use OOP

I have used the word "component", let's see what implementing a component looks like.

```lua
	--Defines a component called Label
	Components.Label = {}
	local Label = Components.Label
	do
		local thisclass = Label;
		--Making the component inherit from AshElement gives it useful functions like addEventHandler etc.
		--bakaKill was used by bakaGaijin, another library I made.
		thisclass.meta = {__index = thisclass, __tostring = gettype, __bakaKill = AshElement.destroy};
		thisclass.type = "Label"

		--Constructor
		function thisclass.new(x, y, width, height, text, color, font)
			--Making the instance a subclass from AshElement gives it basic properties like
			--x, y, id etc
			local self = AshElement.new(x, y, width, height);
			setmetatable(self, thisclass.meta);
			
			self.text = text;
			self.theme.textcolor = color;
			self.theme.font = font;
			return self;
		end
	end
```

And _that's it_. We now have a label. Want to give it an event handler for clicking? Here is some code from the Button component

```lua
	Button.mouse_move_listener = function(self, eventname, eventargs)
		--snip snip
	end
	function Button.new(x, y, width, height)
		local self = AshElement.new(x, y, width, height);
		setmetatable(self, Button.meta);
		self:addEventListener("mouse_move", Button.mouse_move_listener)	
		self:addEventListener("mouse_click", Button.mouse_move_listener)
		return self;
	end
```

# Ash's own Event System

Who is dispatching these events? Ash is. Ash has it's own event system.
MTA does provide it's own event system, but it is not flexible about the order in which the events are bubbled up or down by the listeners, or even if they are bubbled up first or bubbled down first.
Ash implements its own event system in pure Lua without relying on MTA. Ash's event system lets us _give it an iterator_ that would select which children should be bubbled to, and which should not.

It gets better. On every step of the bubble, a component can choose to edit/terminate the event from bubbling further. A window may get an "Z was pressed" event from its parent. It could then look up if Z is set as a hotkey for "close" (suppose it was). It could then EDIT the event to carry the data "Window was closed" instead of "Z was pressed". This provides a layer of abstraction to the children that are listening for events 

# Not just GUI

I mentioned that "Z was pressed" could come as an event to a component.
Indeed, Ash is not a GUI replacement, it is a UI replacement.
It detects every keypress, and no keypress filters through it without its consent.

MTA's input boxes had a problem long ago: You may have "Z" bound to "Throw grenade", and in such a situation if you type Z into a textbox, you may throw a grenade when you didn't mean to.
Basically, instead of propagating input through a tree, components instead listened for input events directly and as equals.
They released some hack to fix it, and now typing in a textbox disables ingame input, but the flaw still remains in principle.

Ash uses a tree to propagate keyboard events, just like any other events. Moreover, the actual game itself (input to GTA San Andreas) is abstracted as an Ash component, which is a child of root.

Keyboard events are propagated only to the "active" child of the node ("active" is an iterator that is provided to Ash's event dispatcher, another use case of Ash's extra flexible event system).
So, when you have a window open, "GTA" (the Ash component) is not the active child anymore, and it has no reason to ever be aware of the keyboard input.

Also note that MTA binds only bind one function to one key. In the future, Ash aims to make possible binds to key combinations or sequences rather than just keys. "X then Z then X" could be fed as a single bind rather than the poor coder manually implementing a state machine to monitor key sequences.
That is a goal for the future.


# Best Foreign Interface

Ash is a resource that runs in parallel to the ones that plan to use it. It needs a foreign interface that allows it to communicate with other resources. MTA has a VM common event system, and exported functions, that allow this.

Observe the code to declare a window with "Click me!" button (that changes to "Clicked") in CEGUI:

```lua
	local window = guiCreateWindow(X, Y, Width, Height, "Title", true)
	local btn = guiCreateButton(X, Y, Width, Height, "Click me!", true, window)
	--Change the position of the button for whatever reason
	guiSetPosition(btn, 200, 200, false)
	addEventHandler("onClick", btn, function() guiSetText(btn, "Clicked") end)
```

Here is the same functionality in dxGUI:

```lua
	local window = dxGUI:dxCreateWindow(X, Y, Width, Height, "Title", true)
	local btn = dxGUI:guiCreateButton(X, Y, Width, Height, "Click me!", true, window)
	dxGUI:guiSetPosition(btn, 200, 200, false)
	addEventHandler("onClick", btn, function() dxGUI:guiSetText(btn, "Clicked") end)
```

Here is the code in Ash:

```lua
	--Ash "Panes" do not have titles, a Window is a Pane with a Label
	local window = Ash.Pane(X, Y, Width, Height)
	local btn = Ash.Button(X, Y, Width, Height, "Click me!")
	window:addChild(btn)
	btn.x = 200; btn.y = 200;
	btn.onClick = function() btn.text = "Clicked" end
	--Or, btn:addEventListener("onClick, function) if you have multiple listeners
```

Ash elements behave like tables instead of opaque alien objects from another VM.

Here is something that is not possible in CEGUI and dxGUI at all:
```lua
	window:tween({x=100, y=100, alpha=0.2}, 300, null, callback)
```

`tween` is a function of AshElement that "tweens" properties of an AshElement (Very useful for animations, or fading effects, etc). I am also working on forking Ash's tweening functionality into an independent open source project.
The code shown here would linearly interpolate the window's X,Y to 100,100 over 300 milliseconds, while slowly making it transparent.
Once the animation is complete, the function "callback" (if provided) will be called.

>Wait, how can you can provide a callback function?

`window` is an object that "actually" exists in another VM.
MTA does not support (and indeed, it would seem it would not even be possible) passing of functions from one VM to another. Tables are also copied by value not reference, and the syntax I described here seems impossible.
Yet, here in the client VM, we are calling window.tween and window.addChild as functions, or assigning a function to btn.onClick, and even passing functions as parameters to these functions.

This magic is accomplished by leveraging Lua metatables and MTA's export system.
MTA's export system only allows us to declare a function as exported when a resource is first started. But these functions being passed around are created at runtime!
Ash assigns a number to every function/table it sends out to other VMs, and maintains a table of these functions/tables. What the other resource gets is just this unique number. It then creates an object that has its metatables set to call a static exported function (with the unique id as one of the parameters) every time it's properties are changed. Any function calls or assignment operations that use functions or tables do this exact same procedure recursively to wrap those values. Ash also makes sure it deletes any references when the only resource still using them is shut down.

This magic was so useful for cross-VM communication in general that I forked it into a separate, independent open source project called [bakaGaijin](bakagaijin.html). Ash uses bakaGaijin to provide a seamless foreign interface.

# Shaders, affine transforms, 3D GUI, and more

Ash's rendering process is basically a DFS of every component instance in the display tree, and each of their "render" method being called. (I am working on caching the display so that render is only called if a child bubbles up the need for an update). DFS happens because the "render" function of a component usually recursively calls the "render" function of all it's children.

If a component doesn't implement its own render method, then Theme.ComponentName is considered to be the rendering function.
Yes, you heard that right. The entire theme system that I am so proud of can be entirely ignored by the implementation of a component if it chooses to do so.
Not just that, the implementation may also choose not to recursively call "render" for all its children, so the rendering process may NOT be a DFS. A component chooses how the render-call-subtree below it looks.

In fact, this "custom rendering function" is how Tabbed menus are implemented in Ash. Instead of rendering all its children, a TabMenu only calls the render function of the currently active window.

This also means, that Ash's "GUI" is not constrained to 2D, or displaying at all. You could decide that a label should be represented as 3d textures being rendered in game. This means we can even reuse Ash's system for some sort of UI where the player is required to walk up to buttons to select them, etc. I will have to add a safety net here so that untrusted components can be run, but it looks promising.

The rendering function of a component also gets INHERITED CONTEXT as a parameter, which it must pass to its children after modifications.
Inherited context means that the rendering of the children depends on the parents. Alphas are multiplied by parent alphas (as you would expect), X and Y coordinates are added up (So all coordinates are relative).
Why stop at alpha? It also inherits all other color transformations. You can tint elements, and all their children would get tinted. Color transformations are accomplished by keeping 9x9 matrices, and multiplying them to perform affine transformations.

[ rrf, grf, brf,   0, 0, 0, 0, 0, 0]
[ rgf, ggf, bgf,   0, 0, 0, 0, 0, 0]
[ rbf, gbf, bbf,   0, 0, 0, 0, 0, 0]
[   0,   0,   0, aaf, 0, 0, 0, 0, 0]
[ rcf,   0,   0,   0, 1, 0, 0, 0, 0]
[   0, gcf,   0,   0, 0, 1, 0, 0, 0]
[   0,   0, bcf,   0, 0, 0, 1, 0, 0]
[   0,   0,   0, acf, 0, 0, 0, 1, 0]
[ rtf, gtf, btf, atf, 0, 0, 0, 0, 1]

Of course, the actual matrices are sparse so we store 18 values per component, not 81.

MTA also exposes methods to use SDL shaders with directX. I did not understand shaders when I made most of Ash, so I did not implement them as inherited context. Over the summer I have studied shaders and future versions of Ash will keep shaders as inherited context, making these color transformations obsolete.

Ash also keeps "scale" as an inherited context which is multiplied like alpha. This means entire windows can be "minimized" by literally making them smaller. Scaling like this is not available in other frameworks.

# Samples

 All videos on this page are without audio.

Here is a video contrasting CEGUI with Ash. It shows off how Ash benefits from having stateful renderers, and some neat Ash features such as tweening. The buttons get animated when the mouse is over them.

<iframe width="560" height="315" src="https://www.youtube.com/embed/qGYF3OFbGy8" frameborder="0" allowfullscreen></iframe>

Here we can see that TextBoxes and keyboard input are fully functional in Ash. Note that the keyboard input would not get into the TextBox were it not selected. We can also see what the Default Theme's TabbedPane implementation looks like. Unlike CEGUI, tabs can take a fixed width, or take up as much space as possible. The default theme allots space based on how long the title of the tab is (Similar to Google Chrome when its full)

<iframe width="560" height="315" src="https://www.youtube.com/embed/pVPMER9JTiI" frameborder="0" allowfullscreen></iframe>

Here we see how the `scale` parameter may be used. We see more tweening, this time of position, scale and even alpha. We observe the effects of the "inherited context" an element gets as scaling, alpha and translation are propagated down to the children.

<iframe width="560" height="315" src="https://www.youtube.com/embed/Hm0xIc35BfA" frameborder="0" allowfullscreen></iframe>

Ash is closed source (and not at all mature) at this time, but I will make it open source eventually. You're going to have to wait.