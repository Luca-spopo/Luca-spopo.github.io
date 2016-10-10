;(function(){
	var example_logo =
	'<div style="display:inline-block;float:left;"><img style="height:20px; margin-right: 5px;" src="logo.png"></div>';
	var tbar_html = document.getElementById("topbar").innerHTML;
	document.getElementById("topbar").innerHTML = example_logo + tbar_html +
	`<item><font style="font-size: 10; font-family : Verdana; float : right">Made by Anirudh Katoch, all rights reserved<br/>(Powered by <a href="http://strapdownjs.com/">StrapDown.js</a> + <a href="https://github.com/joedf/strapdown-topbar">topbar</a>)</font></item>`;
	})();