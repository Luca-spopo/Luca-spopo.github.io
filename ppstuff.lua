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

--[[
Sample page:

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
    <item><a href="index.html">About me</a></item>
    <item><a href="portfolio.html">Portfolio</a></item>
    <menu name="Projects">
        <item><a href="#">Ash</a></item>
        <item><a href="#">BakaGaijin</a></item>
        <item><a href="#">FOSSEE</a></item>
    </menu>
<!--     <item><a href="rants.html">Banter</a></item> -->
    <item><a href="contact.html">Contact</a></item>
    <item><small>(Powered by <a href="http://strapdownjs.com/">StrapDown.js</a> + <a href="https://github.com/joedf/strapdown-topbar">topbar</a>)</small></item>
</topbar>
<xmp theme="cyborg">
MARKDOWN
</xmp>
</body>
<script src="http://strapdownjs.com/v/0.2/strapdown.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/strapdown-topbar/1.6.4/strapdown-topbar.min.js"></script>
<script src="logo.js"></script>
</html>
]]

G.fromMD = function(text)
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
    <item><a href="index.html">About me</a></item>
    <item><a href="portfolio.html">Portfolio</a></item>
    <menu name="Projects">
        <item><a href="#">Ash</a></item>
        <item><a href="#">BakaGaijin</a></item>
        <item><a href="#">FOSSEE</a></item>
    </menu>
<!--     <item><a href="rants.html">Banter</a></item> -->
    <item><a href="contact.html">Contact</a></item>
    <item><small>(Powered by <a href="http://strapdownjs.com/">StrapDown.js</a> + <a href="https://github.com/joedf/strapdown-topbar">topbar</a>)</small></item>
</topbar>
<xmp theme="cyborg">]==]
	..text
	..[==[
</xmp>
</body>
<script src="http://strapdownjs.com/v/0.2/strapdown.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/strapdown-topbar/1.6.4/strapdown-topbar.min.js"></script>
<script src="logo.js"></script>
</html>
	]==]
end

return _G