;(function(){
	var example_logo =
	'<div style="display:inline-block;float:left;"><img style="height:20px; margin-right: 5px;" src="logo.png"></div>';
	var tbar_html = document.getElementById("topbar").innerHTML;
	document.getElementById("topbar").innerHTML = example_logo + tbar_html +
	`<item><font style="font-size: 10; font-family : Verdana; float : right; margin-top : 20">Made by Anirudh Katoch, all rights reserved</font></item>`;
	})();