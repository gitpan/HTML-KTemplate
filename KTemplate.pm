
#=======================================================================
#
#   Copyright (c) 2002-2003 Kasper Dziurdz. All rights reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   Artistic License for more details.
#
#   Please email me any comments, questions, suggestions or bug 
#   reports to: <kasper@repsak.de>
#
#=======================================================================

package HTML::KTemplate;
use strict;
use Carp;
use File::Spec;

use vars qw(
	$VAR_START_TAG $VAR_END_TAG 
	$BLOCK_START_TAG $BLOCK_END_TAG
	$INCLUDE_START_TAG $INCLUDE_END_TAG
	$ROOT $CHOMP $VERSION $CACHE
);

$VERSION = '1.10';

$VAR_START_TAG = '[%';
$VAR_END_TAG   = '%]';

$BLOCK_START_TAG = '<!--';
$BLOCK_END_TAG   = '-->';

$INCLUDE_START_TAG = '<!--';
$INCLUDE_END_TAG   = '-->';

$ROOT  = undef;
$CHOMP = 1;
$CACHE = {};


sub TEXT  () { 0 }
sub VAR   () { 1 }
sub BLOCK () { 2 }
sub FILE  () { 3 }

sub TYPE  () { 0 }
sub IDENT () { 1 }
sub STACK () { 2 }

sub NAME  () { 0 }
sub PATH  () { 1 }


sub new {

	my $class = shift;
	my $self = {
		'vars'   => [{}],  # values for template vars
		'block'  => undef, # current block reference
		'files'  => [],    # file paths for include
		'output' => '',    # template output
		'config' => {      # configuration
			'cache' => 0,
			'strict' => 0,
			'no_includes' => 0,
			'max_includes' => 15,
			'loop_vars' => 0,
		},
	};
	
	$self->{'config'}->{'root'} = shift	if @_ == 1;
	croak('Odd number of option parameters') if @_ % 2 != 0;
	
	# load in all option parameters
	$self->{'config'}->{$_} = shift while $_ = lc shift;
	
	$self->{'config'}->{'root'} = $ROOT
		unless exists $self->{'config'}->{'root'};
	
	bless ($self, $class);
	return $self;
	
}


sub assign {

	my $self = shift;
	my $target;
	
	# if a block reference is defined,
	# assign the variables to the block
	$target = defined $self->{'block'}
		? $self->{'block'}->[ $#{ $self->{'block'} } ]
		: $self->{'vars'}->[0];
	
	if (ref $_[0] eq 'HASH') {
		# copy data for faster variable lookup
		@{ $target }{ keys %{$_[0]} } = values %{$_[0]};
	} else {
		my %assign = @_;
		@{ $target }{ keys %assign } = values %assign;
	}
	
	return 1;

} 


sub block {
# - creates a new loop in the defined block
# - sets a reference so all future variable values will
#   be assigned there (until this method is called again)

	my $self = shift;
	my (@ident, $root, $key, $last_key);
	
	# no argument: undefine block reference 
	if (!defined $_[0] || !length $_[0]) {
		$self->{'block'} = undef; 
		return 1;
	}
	
	@ident = split /\./, $_[0];
	$last_key = pop @ident;
	
	$root = $self->{'vars'}->[0];
	
	foreach $key (@ident) {
	
		# hash reference: perfect!
		if ( ref $root->{$key} eq 'HASH' ) {
		$root =  $root->{$key};
		}
	
		# array reference: block continues in hash 
		# reference at the end of the array
		elsif ( ref $root->{$key} eq 'ARRAY' 
		  && ref $root->{$key}->[ $#{ $root->{$key} } ] eq 'HASH' ) {
		$root =  $root->{$key}->[ $#{ $root->{$key} } ];
		}
		
		else { # create new hash reference
		$root = $root->{$key} = {};
		}
		
	}
	
	if (ref $root->{$last_key} eq 'ARRAY') {
		# block exists: add new loop
		push @{ $root->{$last_key} }, {};
	} else {
		# create new block
		$root->{$last_key} = [{}];
	}
	
	$self->{'block'} = $root->{$last_key};
	
	return 1;
	
}


sub process {
	my $self = shift;

	foreach (@_) {
		next unless defined;
		$self->_include($_);
	}
	
	return 1;
}


sub _include {

	my $self = shift;
	my $filename = shift;
	my ($stack, $filepath);
	
	# check whether includes are disabled
	if ($self->{'config'}->{'no_includes'} && scalar @{ $self->{'files'} } != 0) {
		croak("Include blocks are disabled in template file " . $self->{'files'}->[0]->[NAME]) 
			if $self->{'config'}->{'strict'};
		return;
	}
	
	# check for recursive includes
	croak("Recursive includes: maximum recursion depth of " . $self->{'config'}->{'max_includes'} . " files exceeded") 
		if scalar @{ $self->{'files'} } > $self->{'config'}->{'max_includes'}; 

	($stack, $filepath) = $self->_load($filename);
	
	# add file path to use as include path 
	# and check for recursive includes
	unshift @{ $self->{'files'} }, [ $filename, $filepath ];
	
	# create output
	$self->_output($stack);
	
	# delete file info
	shift @{ $self->{'files'} };

}


sub _load {
# - loads the template file from cache or hard drive
# - returns the parsed stack and the full template path

	my $self = shift;
	my $filename = shift;
	my ($filepath, $mtime, $filedata);
	
	($filepath, $mtime) = $self->_find($filename);
	
	croak("Can't open file $filename: file not found") 
		unless defined $filepath;
	
	# load from cache
	$filedata = $CACHE->{$filepath}
		if $self->{'config'}->{'cache'};
	return ($filedata->[0], $filepath) 
		if defined $filedata && $filedata->[1] == $mtime;
	
	# slurp the file
	local $/ = undef;
	
	open (TEMPLATE, '<' . $filepath) ||
		croak("Can't open file $filename: $!");
	$filedata = <TEMPLATE>;
	close TEMPLATE;
	
	$filedata = $self->_parse(\$filedata, $filename);
	
	# commit to cache
	$CACHE->{$filepath} = [ $filedata, $mtime ]
		if $self->{'config'}->{'cache'};
		
	return ($filedata, $filepath);

}


sub _find {
# - searches for the template file in the 
#   root path or from where it was included
# - returns a full path and the mtime or 
#   undef if the file cannot be found

    my $self = shift;
    my $filename = shift;
    my ($inclpath, $filepath);

	# check path from where the file was included
    if (defined $self->{'files'}->[0]->[PATH]) {
		$inclpath = $self->{'files'}->[0]->[PATH];
        $inclpath = [ File::Spec->splitdir($inclpath) ];
        $inclpath->[$#$inclpath] = $filename;
        $filepath = File::Spec->catfile(@$inclpath);
        return (File::Spec->canonpath($filepath), (stat(_))[9])
			if -e $filepath;
    }

    $filepath = defined $self->{'config'}->{'root'}
        ? File::Spec->catfile($self->{'config'}->{'root'},$filename)
        : File::Spec->canonpath($filename);

    return ($filepath, (stat(_))[9]) if -e $filepath;
    return undef;
	
}


sub _parse {
# - parses the template data passed as a reference 
# - returns the finished stack

	my $self = shift;
	my $filedata = shift;
	my $filename = shift;
	my ($pre, $type, $ident);
	
	my $blocks = 0; # open blocks
	my @pstacks = ([]);
	
	# block and include tags are the same by default
	# if that wasn't changed, use a faster regexp 
	
	my $regexp = $BLOCK_START_TAG eq $INCLUDE_START_TAG 
		&& $BLOCK_END_TAG eq $INCLUDE_END_TAG
		
		? qr/^
			(.*?)
			(?:
				\Q$VAR_START_TAG\E		
				\s*
				([\w.-]+)
				\s*			
				\Q$VAR_END_TAG\E
			|
				\Q$BLOCK_START_TAG\E		
				\s*
				(?:
					([Bb][Ee][Gg][Ii][Nn]|[Ee][Nn][Dd])\s+
					([\w.-]+)
					|
					([Ii][Nn][Cc][Ll][Uu][Dd][Ee])\s+
					(?: "([^"]*?)" | '([^']*?)' | (\S*?) )
				)
				\s*
				\Q$BLOCK_END_TAG\E
			)
			/sox
			
		: qr/^
			(.*?)
			(?:
				\Q$VAR_START_TAG\E		
				\s*
				([\w.-]+)
				\s*			
				\Q$VAR_END_TAG\E
			|
				\Q$BLOCK_START_TAG\E		
				\s*
				([Bb][Ee][Gg][Ii][Nn]|[Ee][Nn][Dd])\s+
				([\w.-]+)
				\s*
				\Q$BLOCK_END_TAG\E
			|
				\Q$INCLUDE_START_TAG\E		
				\s*
				([Ii][Nn][Cc][Ll][Uu][Dd][Ee])\s+
				(?: "([^"]*?)" | '([^']*?)' | (\S*?) )
				\s*
				\Q$INCLUDE_END_TAG\E
			)
			/sox;

	while ($$filedata =~ s/$regexp//sox) {

		$pre   = $1;  # preceding text
		$type  = $3 || $5;  # tag type (undef for var)
		$ident = defined $2 ? $2 : defined $4 ? $4 : defined $6 ? $6 : 
				 defined $7 ? $7 : defined $8 ? $8 : undef;
	
		# delete whitespace characters preceding the block tag
		$pre =~ s/\s*$//s if $type && $CHOMP && $type !~ /^[Ii]/;
		
		# the first element of the @pstacks array contains a reference
		# to the current parse stack where the template data is added.
		
		push @{$pstacks[0]}, [ TEXT, $pre ] if defined $pre;
	
		if (!defined $type) {
		
			push @{$pstacks[0]}, [ VAR, $ident ];
			
		} elsif ($type =~ /^[Bb]/) {
		
			# create a new parse stack were all data 
			# will be added until the block ends.
			unshift @pstacks, [];
			
			# create a reference to this new parse stack in the old one
			# so the block data doesn't get lost after the block ends.
			push @{$pstacks[1]}, [ BLOCK, $ident, $pstacks[0] ];
			
			++$blocks;
			
		} elsif ($type =~ /^[Ee]/) {
			
			shift @pstacks;
			--$blocks;
			
		} elsif ($type =~ /^[Ii]/) {
		
			push @{$pstacks[0]}, [ FILE, $ident ];
			
		}
	}
	
	# add remaining text not recognized by the regex
	push @{$pstacks[0]}, [ TEXT, $$filedata ];
	
	croak("Parse error: block not closed in template file $filename") if $blocks > 0; 
	croak("Parse error: block closed but never opened in template file $filename") if $blocks < 0;
	
	return $pstacks[0];

}


sub _output {

	my $self = shift;
	my $stack = shift;
	my $line;
	
	foreach $line (@$stack) {
		$line->[TYPE] == TEXT  ? $self->{'output'} .= $line->[IDENT] :
		$line->[TYPE] == VAR   ? $self->{'output'} .= $self->_value( $line->[IDENT] ) :
		$line->[TYPE] == BLOCK ? $self->_loop( $line->[IDENT], $line->[STACK] ) :
		$line->[TYPE] == FILE  ? $self->_include( $line->[IDENT] ) : next;	
	}

}


sub _value {

	my $self  = shift;
	my $ident = shift;
	my $value = $self->_get($ident);
	
	unless (defined $value) {
		croak("No value found for variable $ident in file " . $self->{'files'}->[0]->[NAME])
			if $self->{'config'}->{'strict'};
		return '';
	}
	
	# if the value is a code reference the code
	# is called and the output is returned
	
	if (ref $value) {
		$value = &{$value} if ref $value eq 'CODE';
		return '' if !defined $value || ref $value;
	}
	
	return $value;

}


sub _loop {
#  - gets the array with the loop variables
#  - loops through the array, each time creating an output 
#    with the current loop variables

	my $self = shift;
	my $data = $self->_get(shift);
	my $stack = shift;
	my ($vars, $skip);
	
	return unless defined $data;
	
	my $loop_vars = $self->{'config'}->{'loop_vars'};
	my $loop_count = 0;
	
	# no array reference: check the Boolean 
	# context to loop once or skip the block
	unless (ref $data eq 'ARRAY') {
		$data ? $data = [1] : return 1;
		$loop_vars = 0; # just an if block
	}
	
	foreach $vars (@$data) {
	
		# add current loop vars
		if (ref $vars eq 'HASH') {
			unshift @{ $self->{'vars'} }, $vars;
		} else { $skip = 1 }
		
		# add context vars
		if ($loop_vars) {
			++$loop_count;
			
			if (@$data == 1) {
			unshift @{ $self->{'vars'} },
				{ 
				'FIRST' => 1, 'LAST' => 1, 
				'first' => 1, 'last' => 1,
				};
			}
			
			elsif ($loop_count == 1) {
			unshift @{ $self->{'vars'} },
				{
				'FIRST' => 1,
				'first' => 1,
				};
			}
			
			elsif ($loop_count == @$data) { 
			unshift @{ $self->{'vars'} },
				{
				'LAST' => 1,
				'last' => 1,
				};
			}

			else {
			unshift @{ $self->{'vars'} },
				{
				'INNER' => 1,
				'inner' => 1,
				};
			}
			
		}
	
		# create output
		$self->_output($stack);

		# delete context vars
		shift @{ $self->{'vars'} } if $loop_vars;
		
		# delete current loop vars
		unless ($skip) { 
			shift @{ $self->{'vars'} };
		} else { $skip = 0 }
		
	}

}


sub _get {
# - returns the variable value from the variable
#   hash (considering the temporary loop variables)

	my $self  = shift;
	my (@ident, $hash, $root, $key);
	
	@ident = split /\./, $_[0];
	
	# loop values are prepended to the front of the 
	# var array so start with them first
	
	foreach $hash (@{ $self->{'vars'} }) {
		$root = $hash;	# not to change the hash
	
		# for each element of the identification
		# go down the hash structure
		
		foreach $key (@ident) {
			$root = ref $root eq 'HASH'
				? $root->{$key}
				: undef;
			last unless defined $root;
		}
	
		# return if found something
		return $root if defined $root;
	}
	
	return undef;

}


sub print {
	my $self = shift;
	local *FH = shift || *STDOUT;

	defined fileno FH  # hope that works with all handles 
		? print FH $self->{'output'}
		: print STDOUT $self->{'output'};
		
	return 1;
}


sub fetch {
	my $self = shift;
	my $temp = $self->{'output'};  # not the best solution
	return \$temp;
}


sub clear {
	my $self = shift;
	$self->clear_vars();
	$self->clear_out();
	return 1;
}


sub clear_vars {
	my $self = shift;
	$self->{'vars'} = [{}];
	$self->block();
	return 1;
}

sub clear_out {
	my $self = shift;
	$self->{'output'} = '';
	return 1;
}


sub clear_cache {
	$CACHE = {};
	return 1;
}


sub error {
# this method is not used anymore
# errors are raised with croak now
}


1;




=head1 NAME

HTML::KTemplate - Perl module to process HTML templates.


=head1 SYNOPSIS

B<CGI-Script:>

  #!/usr/bin/perl -w
  use HTML::KTemplate;
  
  $tpl = HTML::KTemplate->new('path/to/templates');
  
  $tpl->assign( TITLE  => 'Template Test Page'    );
  $tpl->assign( TEXT   => 'Some welcome text ...' );
  
  foreach (@some_data) {
  
      $tpl->block('LOOP');
      $tpl->assign( TEXT => 'Just a test ...' );
  
  }
  
  $tpl->process('template.tpl');
   
  $tpl->print();

B<Template:>

  <html>
  <head><title>[% TITLE %]</title>
  <body>
  
  Hello! [% TEXT %]<p>
  
  <!-- BEGIN LOOP -->  
  
  [% TEXT %]<br>
  
  <!-- END LOOP -->
  
  </body>
  </html>


B<Output:>

  Hello! Some welcome text ...
  
  Just a test ...
  Just a test ...
  Just a test ...


=head1 MOTIVATION

Although there are many different template modules at CPAN, I couldn't find any that would meet my expectations. So I created this one, with following main features:

=over 4

=item *
No statements in the template files, only variables and blocks.

=item *
Support for multidimensional data structures.

=item *
Everything is very simple and very fast.

=back

Please email me any comments, suggestions or bug reports to <kasper@repsak.de>.


=head1 VARIABLES

By default, template variables are embedded within C<[% %]> and may contain any alphanumeric characters including the underscore and the hyphen. The values for the variables are assigned with C<assign()>, passed as a hash or a hash reference.

  %hash = (
      VARIABLE => 'Value',
  );
  
  $tpl->assign( %hash );
  $tpl->assign(\%hash );
  $tpl->assign( VARIABLE => 'Value' );

To access a multidimensional hash data structure, the variable names are separated by a dot. In the following example, two values for the variables C<[% USER.NAME %]> and C<[% USER.EMAIL %]> are assigned:

  $tpl->assign(
  
      USER => {
          NAME  => 'Kasper Dziurdz',     # [% USER.NAME %]
          EMAIL => 'kasper@repsak.de',   # [% USER.EMAIL %]
      },
      
  );

If the value of a variable is a reference to a subroutine, the subroutine is called and the returned string is included in the output. This is the only way to execute perl code in a template.

  $tpl->assign(
  
      BENCHMARK => sub {
          # get benchmark data
          return 'created in 0.01 seconds';
      }
  
  );


=head1 BLOCKS

Blocks allow you to create loops and iterate over a part of a template or to write simple if-statements. A block begins with C<< <!-- BEGIN BLOCKNAME --> >> and ends with C<< <!-- END BLOCKNAME --> >>. The following example shows the easiest way to create a block:

  $tpl->assign( HEADER  => 'Some numbers:' );
  
  @block_values= ('One', 'Two', 'Three', 'Four');
  
  foreach ( @block_values ) {
  
      $tpl->block('LOOP_NUMBERS');
      $tpl->assign( NUMBER => $_ );
  
  }
  
  $tpl->block();   # leave the block
  $tpl->assign( FOOTER => '...in words.' );

Each time C<block()> is called it creates a new loop in the selected block. All variable values passed to C<assign()> are assigned only to this loop until a new loop is created or C<block()> is called without any arguments (to access global variables again).

Global variables (or outer block variables) are also available inside a block. However, if there is a block variable with the same name, the block variable is used.

Here is an example of a template for the script above:

  [% HEADER %]
  
  <!-- BEGIN LOOP_NUMBERS -->
  
    [% NUMBER %]
  
  <!-- END LOOP_NUMBERS -->
  
  [% FOOTER %]

Because a block is a normal variable with an array reference, blocks can also be created (faster) without the C<block()> method:

  $tpl->assign( 
      HEADER  => 'Some numbers:',
      LOOP_NUMBERS => 
          [
              { NUMBER => 'One'   },
              { NUMBER => 'Two'   },
              { NUMBER => 'Three' },
              { NUMBER => 'Four'  },
          ],
      FOOTER => '...in words.',
  );

Loops within loops work as you would expect. To create a nested loop with C<block()>, you have to pass all blocknames separated by a dot, for example C<BLOCK_1.BLOCK_2>. This way, a new loop called C<BLOCK_2> is created in the last loop of C<BLOCK_1>. The variable values are assigned with C<assign()>.

  foreach (@block_one) {
  
      $tpl->block('BLOCK_1');
      $tpl->assign($_);
  
      foreach (@block_two) {
  
          $tpl->block('BLOCK_1.BLOCK_2');  # block name is just BLOCK_2
          $tpl->assign($_);
  
      }
  }

Blocks can also be used to create if-statements. Simply assign a variable with a true or false value. Based on that, the block is skipped or included in the output. 

  $tpl->assign( SHOW_INFO => 1 );   # show block SHOW_INFO
  $tpl->assign( SHOW_LOGIN => 0 );  # skip block SHOW_LOGIN

For a better control of the loop output, three special loop variables can be made available inside a loop: C<FIRST>, C<INNER> and C<LAST>. This variables are disabled by default (see L<OPTIONS|"Loop Vars"> section how to enable them).

  <!-- BEGIN LOOP -->
  
  
      <!-- BEGIN FIRST -->
       First loop pass
      <!-- END FIRST -->
  
  
      <!-- BEGIN INNER -->
       Neither first nor last
      <!-- END INNER -->
  
  
      <!-- BEGIN LAST -->
       Last loop pass
      <!-- END LAST -->
  
  
  <!-- END LOOP -->


=head1 INCLUDES

Includes are used to process and include the output of another template file directly into the current template in place of the include tag. All variables and blocks assigned to the current template are also available inside the included template.

  <!-- INCLUDE file.tpl -->
  
  <!-- INCLUDE "file.tpl" -->
  
  <!-- INCLUDE 'file.tpl' -->

If the template can't be found under the specified file path (considering the root path), the path to the enclosing file is tried. See L<OPTIONS|"No Includes"> section how to disable includes or change the limit for recursive includes.

=head1 METHODS

=head2 new()

Creates a new template object.

  $tpl = HTML::KTemplate->new();
  
  $tpl = HTML::KTemplate->new( '/path/to/templates' );
  
  $tpl = HTML::KTemplate->new( 
      root  => '/path/to/templates',
      no_includes => 0,
      max_includes => 15,
      loop_vars => 0,
      strict => 0,
      cache => 0,
  );


=head2 assign()

Assigns values for the variables used in the templates. Accepts a hash or a hash reference.

  %hash = (
      VARIABLE => 'Value',
  );
  
  $tpl->assign( %hash );
  $tpl->assign(\%hash );
  $tpl->assign( VARIABLE => 'Value' );  

=head2 block()

See the describtion of L<BLOCKS|"BLOCKS">.

=head2 process()

The C<process()> method is called to process the template files passed as arguments. It loads each template file, parses it and adds it to the template output. The use of the template output is determined by the C<print()> or the C<fetch()> method.

  $tpl->process( 'header.tpl', 'footer.tpl' );
  
  $tpl->process('header.tpl');
  $tpl->process('footer.tpl');

=head2 print()

Prints the output data to C<STDOUT>. If a filehandle is passed, it is used instead of the standard output.

  $tpl->print();
  
  $tpl->print(*FILE);

=head2 fetch()

Returns a scalar reference to the output data. 

  $output_ref = $tpl->fetch();
  
  print FILE $$output_ref;

=head2 clear()

Clears all variable values and other data being held in memory (except cache data). 

  $tpl->clear();

Equivalent to:

  $tpl->clear_vars();
  $tpl->clear_out();

=head2 clear_vars()

Clears all assigned variable values.

  $tpl->clear_vars();

=head2 clear_out()

Clears all output data created by C<process()>.

  $tpl->clear_out();

=head2 clear_cache()

Empties all cache data.

  $tpl->clear_cache();


=head1 OPTIONS

=head2 Variable Tag

  $HTML::KTemplate::VAR_START_TAG = '[%';
  $HTML::KTemplate::VAR_END_TAG   = '%]';

=head2 Block Tag

  $HTML::KTemplate::BLOCK_START_TAG = '<!--';
  $HTML::KTemplate::BLOCK_END_TAG   = '-->';

=head2 Include Tag

  $HTML::KTemplate::INCLUDE_START_TAG = '<!--';
  $HTML::KTemplate::INCLUDE_END_TAG   = '-->';

=head2 Root

  $HTML::KTemplate::ROOT = undef;  # default
  $HTML::KTemplate::ROOT = '/path/to/templates';
  
  $tpl = HTML::KTemplate->new( '/path/to/templates' );
  $tpl = HTML::KTemplate->new( root => '/path/to/templates' );

=head2 No Includes

Set this option to 1 to disable includes. The include tags will be skipped unless the strict option is set to 1.

  $tpl = HTML::KTemplate->new( no_includes => 0 );  # default
  $tpl = HTML::KTemplate->new( no_includes => 1 );

=head2 Max Includes

Allows to set the maximum depth that includes can reach. An error is raised when this depth is exceeded.

  $tpl = HTML::KTemplate->new( max_includes => 15 );  # default

=head2 Cache

Caching option for a persistent environment like mod_perl. Parsed templates will be cached in memory based on their filepath and modification date. Use C<clear_cache()> to empty cache.

  $tpl = HTML::KTemplate->new( cache => 0 );  # default
  $tpl = HTML::KTemplate->new( cache => 1 );

=head2 Loop Vars

Set this option to 1 to enable the loop variables C<FIRST>, C<INNER> and C<LAST>.

  $tpl = HTML::KTemplate->new( loop_vars => 0 );  # default
  $tpl = HTML::KTemplate->new( loop_vars => 1 );

=head2 Strict

Set this option to 1, to raise errors on not defined variables and include tags when disabled.

  $tpl = HTML::KTemplate->new( strict => 0 );  # default
  $tpl = HTML::KTemplate->new( strict => 1 );

=head2 Chomp

Deletes all whitespace characters preceding a block tag.

  $HTML::KTemplate::CHOMP = 1;  # default
  $HTML::KTemplate::CHOMP = 0;


=head1 COPYRIGHT

  Copyright (c) 2002-2003 Kasper Dziurdz. All rights reserved.
  
  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  Artistic License for more details.

=head1 AUTHOR

Kasper Dziurdz <kasper@repsak.de>

=cut

