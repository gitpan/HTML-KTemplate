#!/usr/bin/perl
use strict;
use Test;

BEGIN { plan tests => 10 }

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

ok( $$output =~ /^\s*(?:Everything okay ...\s*){5}\s*$/ && !defined $tpl->error );



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

ok( $$output =~ /^\s*(?:Global variable ...\s*){4}(?:Loop variable \(outer\)...\s*){4}(?:Loop variable \(inner\)...\s*){1}(?:Loop variable \(outer\)...\s*){1}\s*$/ && !defined $tpl->error );



# test if-blocks

$tpl = HTML::KTemplate->new();

$tpl->assign( ON => 1, OFF => 0, CHECK => 'a', VARIABLE => 'Everything okay ...');

$tpl->process('templates/if.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*(?:Everything okay ...\s*){5}\s*$/ && !defined $tpl->error );



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

ok( $$output =~ /^\s*(?:Global variable ...\s*){1}(?:(?:Loop variable \(outer\)...\s*){1}(?:Loop variable \(inner\)...\s*){2}){3}\s*$/ && !defined $tpl->error );



# test $HTML::KTemplate::ROOT = 'path/to/templates'

$HTML::KTemplate::ROOT = 'templates';
$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ && !defined $tpl->error );



# test new( 'path/to/templates' )

$HTML::KTemplate::ROOT = 'wrong/path';
$tpl = HTML::KTemplate->new('templates');

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ && !defined $tpl->error );



# test new( ROOT => 'path/to/templates' )

$HTML::KTemplate::ROOT = 'wrong/path';
$tpl = HTML::KTemplate->new('templates');

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('simple.tpl');
$output = $tpl->fetch();

$HTML::KTemplate::ROOT = undef;

ok( $$output =~ /^\s*(?:Everything okay ...\s*){1}\s*$/ && !defined $tpl->error );



# test clear_vars() clears variables

$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );
$tpl->clear_vars();

$tpl->process('templates/simple.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*$/ && !defined $tpl->error );



# test clear_vars() clears block reference

$tpl = HTML::KTemplate->new();

$tpl->block('BLOCK');
$tpl->assign( VARIABLE => 'Everything okay ...' );
$tpl->clear_vars();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('templates/block.tpl');
$output = $tpl->fetch();

ok( $$output =~ /^\s*$/ && !defined $tpl->error );



# test clear_out()

$tpl = HTML::KTemplate->new();

$tpl->assign( VARIABLE => 'Everything okay ...' );

$tpl->process('templates/simple.tpl');
$tpl->clear_out();

$output = $tpl->fetch();

ok( $$output =~ /^$/ && !defined $tpl->error );


