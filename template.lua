--[[
PP cleaner
Removes dangerous global variables and adds useful global functions for luapp to use
returns the table that should be used as _G
]]

local G = {}
do
	local function clean(t, ...)
		local allowed = {}
		local args = {...}
		for i=1, #args do
			allowed[args[i]] = true
		end
		for k, v in pairs(_G) do
			if allowed[v] then
				t[k] = v
			end
		end
	end
	clean(G, assert, pairs, ipairs, math, print, tostring, table, select, type, tonumber, next, unpack, string)
	--clean(G, pcall, io, getmetatable, setmetatable, assert, loadstring, pcall, setfenv, require, os, pairs, ipairs, math, print, tostring, table, _G, select, type, tonumber, next, unpack, string)
end
G._G = G
G.os = {date = os.date}

setmetatable(_G, {__newindex = function(t, k, v)
	G[k] = v
end,
__index = function(t, k)
	return G[k]
end
})

TOCtext = "Kek la kek"
THEME = "simplex"

function TOC(param)
	if param then
		TOCtext = [[
<item></item>
<item></item>
<toc>
]].."Table of Contents"..[[
</toc>]]
	end
end

fromMD = function(text)
	return [==[
<!doctype html5>
<html lang="en">
<head>
	<meta author="Luca"></meta>
	<!-- 
	Made by Anirudh Katoch
	2016, All rights reserved.
	-->
	<link rel="shortcut icon" type="image/x-icon" href="favicon.png">
	<title>Luca's Trove</title>
</head>
<body>
<topbar>
    <item><a href="index.html">About asdf me</a></item>
    <item><a href="portfolio.html">Portfolio</a></item>
    <item><a href="projects.html">Projects</a></item>
    <!-- Hack: Menu not proper on mobile
    <menu name="Projects">
        <item><a href="ash.html">Ash</a></item>
        <item><a href="bakagaijin.html">BakaGaijin</a></item>
        <item><a href="projects.html">FOSSEE</a></item>
        <item></item>
        <item><a href="projects.html">Show all</a></item>
    </menu>
    -->
<!--     <item><a href="rants.html">Banter</a></item> -->
    <item><a href="contact.html">Contact</a></item>
    ]==]
    ..TOCtext
    ..[==[
</topbar>
<textarea theme="]==]..THEME..[==[">]==]
	..text
	..[==[
</textarea>
`<item><font style="font-size: 10; font-family : Verdana; float : right; margin-right : 10px">Made by Anirudh Katoch, all rights reserved<br/>(Powered by <a href="http://strapdownjs.com/">StrapDown.js</a> + <a href="https://github.com/joedf/strapdown-topbar">topbar</a> + <a href="http://lua-users.org/wiki/SlightlyLessSimpleLuaPreprocessor">Lua</a>)</font></item>`
</body>
<script src="strapdown-gh-pages/v/0.2/strapdown.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/strapdown-topbar/1.6.4/strapdown-topbar.min.js"></script>
<script src="post.js"></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-85618530-1', 'auto');
  ga('send', 'pageview');
</script>
</html>
	]==]
end

return _G