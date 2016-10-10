;(function(){
	var example_logo =
	'<div style="display:inline-block;float:left;"><img style="height:20px; margin-right: 5px;" src="logo.png"></div>';
	var tbar_html = document.getElementById("topbar").innerHTML;
	document.getElementById("topbar").innerHTML = example_logo + tbar_html;
	})();