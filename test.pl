#!/usr/bin/perl
use strict;
use Test;

BEGIN { plan tests => 11 }

use HTML::KTemplate;
my ($tpl, $output);



# test variables

$tpl = HTML::KTemplate->new();

$tpl->assign(  'VARIABLE_NAME' => 'Everything okay ...'  );
$tpl->assign({ 'VARIABLE-NAME' => 'Everything okay ...' });
$tpl->assign(

    SUBROUTINE => sub {
        return 'Everything okay ...';
    },
	
	SOMETHING => { SOMEWHERE => 'Everything okay ...' },
	ABC => { DEF => { GHI => { JKL => { MNO => 'Everything okay ...' }}}},

);

$tpl->process('templates/variables.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*(?:Everything okay ...\s*){5}\s*$/ );



# test loops

$tpl = HTML::KTemplate->new();

$tpl->assign({

	SOME_TEXT => 'Global variable ...',
	OUTER_LOOP => [
		{ VAR => { INNER_LOOP => [0, 'a'] } },
		{ SOME_TEXT => 'Loop variable (outer)...', 
		  VAR => { INNER_LOOP => [[], {}] } },
		{ SOME_TEXT => 'Loop variable (outer)...', 
		  VAR => { INNER_LOOP => [{ SOME_TEXT => 'Loop variable (inner)...' }, {}] } },
	],
});

$tpl->process('templates/loops.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*(?:Global variable ...\s*){4}(?:Loop variable \(outer\)...\s*){4}(?:Loop variable \(inner\)...\s*){1}(?:Loop variable \(outer\)...\s*){1}\s*$/ );



# test if-blocks

$tpl = HTML::KTemplate->new();

$tpl->assign( ON => 1, OFF => 0, CHECK => 'a', VARIABLE => 'Everything okay ...');

$tpl->process('templates/if.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*(?:Everything okay ...\s*){5}\s*$/ );



# test block()

$tpl = HTML::KTemplate->new();

foreach (1..3) {
	$tpl->block('OUTER_LOOP');
	$tpl->assign( SOME_TEXT => 'Loop variable (outer)...' );
		
	foreach (1..2) {
		$tpl->block('OUTER_LOOP.VAR.INNER_LOOP');
		$tpl->assign( SOME_TEXT => 'Loop variable (inner)...' );
	}
}

$tpl->block();
$tpl->assign( SOME_TEXT => 'Global variable ...');

$tpl->process('templates/loops.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*(?:Global variable ...\s*){1}(?:(?:Loop variable \(outer\)...\s*){1}(?:Loop variable \(inner\)...\s*){2}){3}\s*$/ );



# test $HTML::KTemplate::ROOT = 'path/to/templates'

$HTML::KTemplate::ROOT = 'templates';
$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ );



# test new( 'path/to/templates' )

$HTML::KTemplate::ROOT = 'wrong/path';
$tpl = HTML::KTemplate->new('templates');

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ );



# test new( root => 'path/to/templates' )

$HTML::KTemplate::ROOT = 'wrong/path';
$tpl = HTML::KTemplate->new(root => 'templates');

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ );



# test clear_vars() clears variables

$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );
$tpl->clear_vars();

$tpl->process('templates/simple.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*$/ );



# test clear_vars() clears block reference

$tpl = HTML::KTemplate->new();

$tpl->block('BLOCK');
$tpl->assign( VARIABLE => 'Everything okay ...' );
$tpl->clear_vars();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('templates/block.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*$/ );



# test clear_out()

$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('templates/simple.tpl');
$tpl->clear_out();

$output = $tpl->fetch();

ok( $$output =~ /^$/ );



# test a complex template

$tpl = HTML::KTemplate->new();

$tpl->assign(

BOARD => {
	TITLE => 'KTemplate Test Forum',
	FONT => 'Verdana, Arial, Times New Roman',
	WIDTH => '100%',
},

COLOR => {
	BORDER => '#000000',
	BG => '#FFFFFF',
	TEXT => '#000000',
	LINK => '#000000',
	VLINK => '#000000',
	ALINK => '#000000',
},

URL => {
	CGI => 'http://www.domain.com/cgi-bin/',
	IMAGES => 'http://www.domain.com/images/',
},

IMAGE => {
	LOGO => 'logo.gif',
	ON => 'on.gif',
	OFF => 'off.gif',
},

LANG => {
	REGISTER => 'Register',
	PROFILE => 'Profile',
	PREFERENCES => 'Preferences',	
	SEARCH => 'Search',
	PRIVATE_MSGS => 'Private Messages',
	MEMBERS => 'Members',
	HELP => 'Help',
	LOGIN => 'Login',
	LOGOUT => 'Logout',
	LOGGED_IN => 'Logged in as',
	LOGGED_OUT => 'Logged out',
	FORUM => 'Forum',
	TOPICS => 'Topcis',
	POSTS => 'Posts',
	LAST_POST => 'Last Post',
	NEW_POSTS => 'New posts',
	NO_NEW_POSTS => 'No new posts'
},

);

$tpl->assign( 
	SHOW_LOGO_IMAGE => 1,
	LOGGED_IN => 1,
	LOGGED_OUT => 0,
);

$tpl->assign(
	COLSPAN => 5,
	USERNAME => 'Kasper',
);

foreach ('Category Row 1', 'Category Row 2', 'Category Row 3', 'Category Row 4') {
	$tpl->block('CATROW');
	$tpl->assign( NAME => $_ );
	
	foreach ('Forum Row 1', 'Forum Row 2', 'Forum Row 3', 'Forum Row 4') {
		$tpl->block('CATROW.FORUMROW');
		$tpl->assign( NAME => $_ );
		$tpl->assign(		
			IMAGE_ON => 0,
			IMAGE_OFF => 1,
			ID => '10',
			DESCRIPTION => 'Here comes some describtion text ... lalala lalala lalala ... ',
			TOPICS => 1423,
			POSTS => 3324,
			LAST_POST => 'Some time ago',
		);
	}
	
}

$tpl->process( 'templates/complex.tpl' );
$output = $tpl->fetch();

ok( $$output =~ /^.+?KTemplate Test Forum.+?Register.+?(?:|.+?){5}Help.+?Logged in as Kasper.+?(?:Category Row.+?(?:off\.gif.+?Forum Row.+?Here comes some describtion.+?){4}){4}/s );