<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
<title>[% BOARD.TITLE %]</title>
<style type="text/css">
<!--

A {
text-decoration: none;
font-weight: bold;
}

A:hover {
color: [% COLOR.ALINK %];
}

BODY, TD {
font-family: [% BOARD.FONT %];
}

.main_table {
background-color: [% COLOR.BORDER %];
}

.row_head {
background-color: #000000;
color: #FFFFFF;
}

.row_cat {
background-color:  #FFFFFF;
color: #000000;
}

.col_1, .col_3, .col_5 {
background-color: #FFFFFF;
}

.col_2, .col_4 {
background-color:  #FFFFFF;
}

//-->
</style>
<meta http-equiv=expires content=0>
</head>

<body bgcolor=[% COLOR.BG %] text=[% COLOR.TEXT %] link=[% COLOR.LINK %] vlink=[% COLOR.VLINK %] alink=[% COLOR.ALINK %]>

<div align=center>

<table border=0 width="[% BOARD.WIDTH %]" cellpadding=0 cellspacing=0><tr><td width="90%">

<!-- BEGIN SHOW_LOGO_IMAGE -->
<a href="[% URL.CGI %]index.cgi"><img src="[% URL.IMAGES %][% IMAGE.LOGO %]" border=0><br></a>
<!-- END SHOW_LOGO_IMAGE -->

</td><td>

<table border=0 cellspacing=0 cellpadding=6><tr><td align=center>
<div class=main_menu><nobr><a href="[% URL.CGI %]index.cgi?action=register">[% LANG.REGISTER %]</a> | <a href="[% URL.CGI %]index.cgi?action=profile">[% LANG.PROFILE %]</a> | <a href="[% URL.CGI %]index.cgi?action=prefs">[% LANG.PREFERENCES %]</a> | <a href="[% URL.CGI %]index.cgi?action=search">[% LANG.SEARCH %]</a></nobr><br><nobr><a href="[% URL.CGI %]index.cgi?action=msgs">[% LANG.PRIVATE_MSGS %]</a> | <a href="[% URL.CGI %]index.cgi?action=members">[% LANG.MEMBERS %]</a> | <a href="[% URL.CGI %]index.cgi?action=help">[% LANG.HELP %]</a></nobr></div>
</td></tr></table>

</td></table>


<table border=0 width="[% BOARD.WIDTH %]" cellpadding=0 cellspacing=0><tr><td>

<!-- BEGIN LOGGED_IN -->
<div class=bb_info>[% LANG.LOGGED_IN %] [% USERNAME %] &raquo; <a href="[% URL.CGI %]index.cgi?action=logout">[% LANG.LOGOUT %]</a></div>
<!-- END LOGGED_IN -->

<!-- BEGIN LOGGED_OUT -->
<div class=bb_info>[% LANG.LOGGED_OUT %] &raquo; <a href="[% URL.CGI %]index.cgi?action=login">[% LANG.LOGIN %]</a></div>
<!-- END LOGGED_OUT -->

</td></tr><tr><td height=3></td></tr></table>

<table width="[% BOARD.WIDTH %]" border=0 cellpadding=4 cellspacing=1 class=main_table>

<tr class=row_head>
<td width="1%">&nbsp;</td>
<td width="82%">[% LANG.FORUM %]</td>
<td width="1%">&nbsp;[% LANG.TOPICS %]&nbsp;</td>
<td width="1%">&nbsp;[% LANG.POSTS %]&nbsp;</td>
<td width="15%" align=center><nobr>&nbsp;[% LANG.LAST_POST %]&nbsp;</nobr></td>
</tr>

<!-- BEGIN CATROW -->

<tr><td colspan=[% COLSPAN %] class=row_cat>[% NAME %]</td></tr>

<!-- BEGIN FORUMROW -->

<tr>

<!-- BEGIN IMAGE_ON -->
<td class=col_1 align=center><img src="[% URL.IMAGES %][% IMAGE.ON %]" border=0 hspace=6 vspace=6></td>
<!-- END IMAGE_ON -->

<!-- BEGIN IMAGE_OFF -->
<td class=col_1 align=center><img src="[% URL.IMAGES %][% IMAGE.OFF %]" border=0 hspace=6 vspace=6></td>
<!-- END IMAGE_OFF -->

<td class=col_2><div class=forum_title><a href="viewforum.php?forum=[% ID %]">[% NAME %]</a></div>

<!-- BEGIN DESCRIPTION -->
<div class=forum_desc>[% DESCRIPTION %]</div>
<!-- END DESCRIBTION -->

</td>
<td class=col_3 align=center><div class=forum_topics>[% TOPICS %]</div></td>
<td class=col_4 align=center><div class=forum_posts>[% POSTS %]</div></td>
<td class=col_5 align=center><div class=forum_lpost>[% LAST_POST %]</div></td>

</tr>

<!-- END FORUMROW -->

<!-- END CATROW -->

</table>

<table border=0 cellpadding=3 cellspacing=0 align=center>
<tr><td colspan=5 height=1></td></tr>
<tr>
<td><img src="[% URL.IMAGES %][% IMAGE.ON %]"></td>
<td><div class=img_info>[% LANG.NEW_POSTS %]</div></td>
<td width=10></td>
<td><img src="[% URL.IMAGES %][% IMAGE.OFF %]"></td>
<td><div class=img_info>[% LANG.NO_NEW_POSTS %]</div></td>
</tr></table>

</div>

<!-- INCLUDE templates/loops.tpl -->

</body>
</html>

