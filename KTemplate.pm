
#=======================================================================
#
#   Copyright (c) 2002 Kasper Dziurdz. All rights reserved.
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

use vars qw(
	$VAR_START_TAG $VAR_END_TAG 
	$BLOCK_START_TAG $BLOCK_END_TAG 
	$ROOT $CHOMP $VERSION
);

$VERSION = '1.03';

$VAR_START_TAG = '[%';
$VAR_END_TAG   = '%]';

$BLOCK_START_TAG = '<!--';
$BLOCK_END_TAG   = '-->';

$ROOT  = undef;
$CHOMP = 1;

sub TEXT  () { 0 }
sub VAR   () { 1 }
sub BLOCK () { 2 }

sub TYPE  () { 0 }
sub IDENT () { 1 }
sub STACK () { 2 }


sub new {
	my $class = shift;
	my $self = {
		'values' => [{}],  # values for template vars
		'block'  => undef, # current block reference
		'pstack' => undef, # parse stack
		'file'   => '',    # template file
		'output' => '',    # template output
		'config' => {},    # configuration
	};
	
	# only one parameter: path to templates
	$self->{'config'}->{'root'} = shift if @_ == 1;
	
	# check everything is passed as option => value
	croak("Odd number of option parameters") if @_ % 2 != 0;
	
	# load in all options passed to new()
	for (my $i = 0; $i < $#_; $i += 2) {
	${ $self->{'config'} }{ lc $_[$i] } = $_[$i+1] }
	
	# consider $HTML::KTemplate::ROOT
	$self->{'config'}->{'root'} = $ROOT
	unless exists $self->{'config'}->{'root'};

	$self->{'config'}->{'chomp'} = $CHOMP
	unless exists $self->{'config'}->{'chomp'};	 # will not be supported in the next versions
	
	bless ($self, $class);
	return $self;
}


sub assign {
	my $self = shift;
	
	# if a block reference is defined,
	# assign the variables to the block
	my $target = defined $self->{'block'}
		? ${ $self->{'block'} }[ $#{ $self->{'block'} } ]
		: ${ $self->{'values'} }[0];
	
	if (ref $_[0] eq 'HASH') {
	@{ $target }{ keys %{$_[0]} } = values %{$_[0]};
	} # copying for faster variable lookup
	
	else { my %assign = @_;
	@{ $target }{ keys %assign } = values %assign;
	}
	
} 


sub block {
	my $self = shift;
	my (@ident, $root, $key, $last_key);
	
	# no argument: undefine block reference 
	if (!defined $_[0] || !length $_[0]) {
	$self->{'block'} = undef; return 1 }
	
	@ident = split /\./, $_[0];
	$root = ${ $self->{'values'} }[0];

	# last key is treated differently
	$last_key = pop @ident;
	
	foreach $key (@ident) {
	
		# hash reference: perfect
		if ( ref $root->{$key} eq 'HASH' ) {
		$root =  $root->{$key};
		}
	
		# array reference: block continues in hash 
		# reference at the end of the array
		elsif ( ref $root->{$key} eq 'ARRAY' 
		  && ref ${ $root->{$key} }[ $#{ $root->{$key} } ] eq 'HASH' ) {
		$root =  ${ $root->{$key} }[ $#{ $root->{$key} } ];
		}
		
		else { # create hash reference
		$root = $root->{$key} = {};
		}
		
	}
	
	# block already exists: add new loop
	if (ref $root->{$last_key} eq 'ARRAY') {
	push @{ $root->{$last_key} }, {};
	}
	
	else { # create new block
	$root->{$last_key} = [{}];
	}
	
	$self->{'block'} = $root->{$last_key};
}


sub process {
	my $self = shift;
	my $filename;
	
	foreach $filename (@_) {
		
		# skip if not defined
		next unless defined $filename;
		
		# load the template file
		$self->_load( $filename );
		# create the parse stack
		$self->_parse( $filename );
		# and add to the output
		$self->_output( $self->{'pstack'} );
		
		# to clear memory (?) hm ... 
		$self->{'pstack'} = undef;
	
	}
	
	return 1;
}


sub _load {
	my $self = shift;
	my $filename = shift;
	my $filepath;
	
	# slurp the file
	local $/ = undef;
	
	$filepath = defined $self->{'config'}->{'root'}
		? $self->{'config'}->{'root'} . '/' . $filename
		: $filename;
	
	croak("Can't open file $filename: $!") 
	if !open TEMPLATE, '<' . $filepath;

	$self->{'file'} = <TEMPLATE>;
	close TEMPLATE;
}


sub _parse {
	my $self = shift;
	my $filename = shift;
	my ($pre, $block, $ident);
	
	my $bdepth = 0;    # block depth to check that all blocks are closed
	my @pstack = ([]); # parse stack: array containing the parsed template

	while ($self->{'file'} =~ s/^
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
			(?:([Bb][Ee][Gg][Ii][Nn]|[Ee][Nn][Dd])\s+)?
			([\w.-]+)
			\s*
			\Q$BLOCK_END_TAG\E
		)
	//sox) {

		$pre   = $1;		# preceding text
		$block = $3;		# block type (undef for var)
		$ident = $2 || $4;	# identification
	
		# delete whitespace characters preceding the block tag
		$pre =~ s/\s*$//s if $block && $self->{'config'}->{'chomp'};
		
		# the first element of the parse stack contains a reference
		# to the current array where the template data is added.
		# there the data is pushed as an array reference with
		# the data type (text, var, block) and the data itself.
		
		push @{$pstack[0]}, [ TEXT, $pre ] if defined $pre;
	
		if (!defined $block) {
			
			push @{$pstack[0]}, [ VAR, $ident ];
		
		} elsif ($block =~ /^[Bb]/) {
		
			# add a new array to the beginning of the parse stack so 
			# all data will be added there until the block ends.
			unshift @pstack, [];
		
			# create a reference to this new parse stack in the old stack
			# so the block data doesn't get lost after the end of the block.
			push @{$pstack[1]}, [ BLOCK, $ident, $pstack[0] ];
			
			++$bdepth;
		
		} elsif ($block =~ /^[Ee]/) {
		
			shift @pstack;
			--$bdepth;
			
		}
	
	}
	
	# add remaining text not recognized by the regex
	push @{$pstack[0]}, [ TEXT, $self->{'file'} ];

	$self->{'file'} = '';
	$self->{'pstack'} = $pstack[0];
	
	croak("Parse error: block not closed in template file $filename") if $bdepth > 0; 
	croak("Parse error: block closed but never opened in template file $filename") if $bdepth < 0;
}


sub _output {
	my $self = shift;
	my $pstack = shift;
	my $line;
	
	foreach $line (@$pstack) {
	
		$line->[TYPE] == TEXT  ? $self->{'output'} .= $line->[IDENT] :
		$line->[TYPE] == VAR   ? $self->{'output'} .= $self->_value( $line->[IDENT] ) :
		$line->[TYPE] == BLOCK ? $self->_loop( $line->[IDENT], $line->[STACK] ) : next;
	
	}
}


sub _loop {	
	my $self = shift;
	my $data = $self->_get(shift);
	my $pstack = shift;
	my ($vars, $skip);
	
	return 1 unless defined $data;
	
	# no array reference: check the Boolean 
	# context to loop once or skip the block
	unless (ref $data eq 'ARRAY') {
	$data ? $data = [1] : return 1 }
	
	foreach $vars ( @$data ) {
	
		# add the current loop vars
		ref $vars eq 'HASH'
		? unshift @{ $self->{'values'} }, $vars
		: ($skip = 1);
	
		$self->_output( $pstack );
	
		# delete the loop vars
		$skip ? ($skip = 0)
		: shift @{ $self->{'values'} };
		
	}
}


sub _value {
	my $self  = shift;
	my $value = $self->_get($_[0]);
	
	# variable value not found
	return '' unless defined $value;
	
	# if the value is a code reference the code
	# is called and the output is returned
	
	if (ref $value) {
	$value = &{$value} if ref $value eq 'CODE';
	return '' if !defined $value || ref $value;
	}
	
	return $value;
}


sub _get {
	my $self  = shift;
	my (@ident, $hash, $root, $key);
	
	@ident = split /\./, $_[0];
	
	# loop values are prepended to the front of the 
	# var array so start with them first
	
	foreach $hash (@{ $self->{'values'} }) {
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
}


sub print {
	my $self = shift;
	print STDOUT $self->{'output'};
}


sub fetch {
	my $self = shift;
	my $temp = $self->{'output'};	# just a temporary solution
	return \$temp;
}


sub clear {
	my $self = shift;
	$self->clear_vars();
	$self->clear_out();
}


sub clear_vars {
	my $self = shift;
	$self->{'values'} = [{}];
	$self->block();
}


sub clear_out {
	my $self = shift;
	$self->{'output'} = '';
	$self->{'pstack'} = undef;
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
  
  $tpl->process('header.tpl', 'body.tpl');
   
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

Although there are many different template modules at CPAN, I couldn't find any that would meet my expectations. So I created this one, with following features:

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
          NAME  => 'Kasper Dziurdz',
          EMAIL => 'kasper@repsak.de',
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
  
          $tpl->block('BLOCK_1.BLOCK_2');
          $tpl->assign($_);
  
      }
  }

Blocks can also be used to create if-statements. Simply assign a variable with a true or false value. Based on that, the block is skipped or included in the output. 

  $tpl->assign( SHOW_INFO => 1 );   # show block SHOW_INFO
  $tpl->assign( SHOW_LOGIN => 0 );  # skip block SHOW_LOGIN


=head1 METHODS

=head2 new()

Creates a new template object.

  $tpl = HTML::KTemplate->new();
  
  $tpl = HTML::KTemplate->new( '/path/to/templates' );
  
  $tpl = HTML::KTemplate->new( 
      root  => '/path/to/templates',
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

  $tpl->process('header.tpl', 'body.tpl', 'footer.tpl');

=head2 print()

Prints the output data to C<STDOUT>.

  $tpl->print();

=head2 fetch()

Returns a scalar reference to the output data. 

  $output_ref = $tpl->fetch();
  
  print FILE $$output_ref;

=head2 clear()

Clears all variable values and other data being held in memory (only needed for CGI scripts in a persistent environment like mod_perl). 

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


=head1 OPTIONS

=head2 Variable Tag

  $HTML::KTemplate::VAR_START_TAG = '[%';
  $HTML::KTemplate::VAR_END_TAG   = '%]';

=head2 Block Tag

  $HTML::KTemplate::BLOCK_START_TAG = '<!--';
  $HTML::KTemplate::BLOCK_END_TAG   = '-->';

=head2 Root

  $HTML::KTemplate::ROOT = undef;  # default
  $HTML::KTemplate::ROOT = '/path/to/templates';
  
  $tpl = HTML::KTemplate->new( '/path/to/templates' );
  $tpl = HTML::KTemplate->new( root => '/path/to/templates' );

=head2 Chomp

Deletes all whitespace characters preceding a block tag.

  $HTML::KTemplate::CHOMP = 1;  # default
  $HTML::KTemplate::CHOMP = 0;


=head1 COPYRIGHT

  Copyright (c) 2002 Kasper Dziurdz. All rights reserved.
  
  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  Artistic License for more details.

=head1 AUTHOR

Kasper Dziurdz <kasper@repsak.de>

=cut