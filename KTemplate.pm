
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

use vars qw(
	$VAR_START_TAG $VAR_END_TAG 
	$BLOCK_START_TAG $BLOCK_END_TAG 
	$ERROR $ROOT $CHOMP $VERSION
);

$VERSION = '1.01';

$VAR_START_TAG = '[%';
$VAR_END_TAG   = '%]';

$BLOCK_START_TAG = '<!--';
$BLOCK_END_TAG   = '-->';

$ERROR = undef;
$ROOT  = undef;
$CHOMP = 1;



sub new {
	my $class = shift;
	my $self = {
		var_values => [{}],  # values for template vars
		block_ref  => undef, # current block reference
		data_raw   => '',    # template file
		data_code  => '',    # template code
		data_out   => '',    # template output
		config     => {},    # configuration
	};
	
	$self->{'config'}->{'ROOT'} = shift if @_ == 1;
	%{ $self->{'config'} } = @_ if @_ >= 2;
	
	bless ($self, $class);
	return $self;
}



sub assign {
	my $self = shift;
	
	# if a block reference is defined,
	# assign the variables to the block
	
	my $target = defined $self->{'block_ref'}
		? ${ $self->{'block_ref'} }[ $#{ $self->{'block_ref'} } ]
		: ${ $self->{'var_values'} }[0];
	
	if (ref $_[0] eq 'HASH') {
	@{ $target }{ keys %{$_[0]} } = values %{$_[0]};
	} # copying for faster variable lookup
	
	else { my %assign = @_;
	@{ $target }{ keys %assign } = values %assign;
	}
	
	return 1;
} 



sub block {
	my $self = shift;
	my (@ident, $root, $key, $last_key);
	
	if (!defined $_[0] || !length $_[0]) {
	$self->{'block_ref'} = undef;
	return 1;
	}
	
	@ident = split /\./, $_[0];
	$root = ${ $self->{'var_values'} }[0];

	# last key is treated differently
	$last_key = pop @ident;

	
	foreach $key (@ident) {
	
		# hash reference: perfect
		if ( ref $root->{$key} eq 'HASH' ) {
		$root =  $root->{$key};
		}
	
		# array reference: block continues in hash 
		# reference at the end of the array
		elsif ( ref    $root->{$key} eq 'ARRAY' 
		  && ref ${ $root->{$key} }[ $#{ $root->{$key} } ] eq 'HASH' ) {
		$root =  ${ $root->{$key} }[ $#{ $root->{$key} } ];
		}
		
		else {	# create hash reference
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
	
	$self->{'block_ref'} = $root->{$last_key};
	return 1;
}



sub process {
	my $self = shift;
	
	$self->{'config'}->{'ROOT'} = $ROOT
	unless exists $self->{'config'}->{'ROOT'};
	
	foreach (@_) {
	$self->_load($_) || return undef;
	$self->_parse()  || return undef;
	}
	
	eval $self->{'data_code'};
	$self->{'data_code'} = '';

	return $self->error("Unexpected error while evaluating template.\n") if $@;
	return 1;
}



sub _load {
	my $self = shift;
	my $file = shift;
	local $/ = undef;
    
	return $self->error("Template filename not defined.\n") 
		unless defined $file;
	
	$file = $self->{'config'}->{'ROOT'} . '/' . $file
	if defined $self->{'config'}->{'ROOT'};
	
	return $self->error("Can't open file: $file ($!).\n") 
	if !open TEMPLATE, '<' . $file;

	$self->{'data_raw'} = <TEMPLATE>;
	close TEMPLATE;
	
	return 1;
}



sub _parse {
	my $self = shift;
	my ($pre, $block, $ident);
	my $level = 0;
	
	$self->{'data_code'} .= qq[\$self->{'data_out'} .= ''\n];

	while ($self->{'data_raw'} =~ s/^
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
			(?:(BEGIN|END)\s+)?
			([\w.-]+)
			\s*
			\Q$BLOCK_END_TAG\E
		)
	//sox) {

	
	$pre   = $1;		# preceding text
	$block = $3;		# block type (undef for var)
	$ident = $2 || $4;	# identification
	
	$pre = '' unless defined $pre;
	$pre =~ s/\s*$//s if $block && $CHOMP;
	$pre =~ s[`][\\`]g;

	$self->{'data_code'} .= qq[\n. q`$pre`];
	
	if (!defined $block) {	# variable
	$self->{'data_code'} .= qq[\n. \$self->_value('$ident')];
	}

	elsif ($block eq 'BEGIN') {
	$self->{'data_code'} .= qq[;\n\n]
		. qq[foreach (\@{ \$self->_loop('$ident') }) {\n]
		. qq[\$self->_add(\$_);\n]
		. qq[\$self->{'data_out'} .= ''\n];
	++$level;
	}
	
	elsif ($block eq 'END') {
	$self->{'data_code'} .= qq[;\n\n]
		. qq[\$self->_del()  }\n]
		. qq[\$self->{'data_out'} .= ''\n];
	--$level;
	}
	
	}	# end while
	
	$self->{'data_code'} .= qq[\n. q`$self->{'data_raw'}`;\n];
	$self->{'data_raw'} = '';

	return $self->error("Parse error: block not closed.\n") if $level > 0; 
	return $self->error("Parse error: block closed but never opened.\n") if $level < 0;
	
	return 1;
}



sub print {
	my $self = shift;
	print STDOUT $self->{'data_out'};
	return 1;
}



sub fetch {
	my $self = shift;
	return \$self->{'data_out'};
}



sub clear {
	my $self = shift;
	$self->clear_vars();
	$self->clear_out();
	return 1;
}



sub clear_vars {
	my $self = shift;
	$self->{'var_values'} = [{}];
	$self->block();
	return 1;
}



sub clear_out {
	my $self = shift;
	$self->{'data_out'} = '';
	return 1;
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
	
	foreach $hash (@{ $self->{'var_values'} }) {
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



# following method returns an array reference 
# containing the data to loop through

sub _loop {	
	my $self = shift;
	my $data = $self->_get($_[0]);
	
	# if $data is not an array reference
	# create one dependent on the Boolean 
	# context (to loop once or skip the block)
	
	return [] unless defined $data;
	return $data if ref $data eq 'ARRAY';
	return $data ? [{}] : [];
}



sub _add {
	my $self = shift;
	ref $_[0] eq 'HASH'
	? unshift @{ $self->{'var_values'} }, $_[0]
	: unshift @{ $self->{'var_values'} }, {};
}



sub _del {
	my $self = shift;
	shift @{ $self->{'var_values'} };
}



sub error {
	my $self = shift;
	return $ERROR unless defined $_[0];
	$ERROR = $_[0];
	return undef;
}


1;




=head1 NAME

HTML::KTemplate - Perl module to process HTML templates.


=head1 SYNOPSIS

B<Perl code:>

  use KTemplate;
  
  $tpl = KTemplate->new('path/to/templates');
  
  $tpl->assign( TITLE => 'Template Test Page' );
  
  %hash = (
      TEXT => 'Some welcome text ...',
      USER => {
          NAME => 'Kasper Dziurdz',
          EMAIL => 'kasper@repsak.de',
      },
  );
  
  $tpl->assign( \%hash );
  
  for (1 .. 3) {
      $tpl->block('LOOP');
      $tpl->assign( TEXT => 'Just a test ...' );
  }
  
  $tpl->process('header.tpl', 'body.tpl') || die $tpl->error();
   
  $tpl->print();

B<Template:>

  +--------- -- -- - - -  -  -   -
  | [% TITLE %]
  +--------- -- -- - - -  -  -   -

  Hello [% USER.NAME %]! [% TEXT %]
  
  Your eMail: [% USER.EMAIL %]
  
  <!-- BEGIN LOOP -->
  
  [% TEXT %]
  
  <!-- END LOOP -->

B<Output:>

  +--------- -- -- - - -  -  -   -
  | Template Test Page
  +--------- -- -- - - -  -  -   -
  
  Hello Kasper Dziurdz! Some welcome text ...
  
  Your eMail: kasper@repsak.de
  
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
Everything is very simple and (i believe) pretty fast.

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

  $tpl = KTemplate->new();
  
  $tpl = KTemplate->new( '/path/to/templates' );
  $tpl = KTemplate->new( ROOT => '/path/to/templates' );

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

The C<process()> method is called to process the template files passed as arguments. It loads each template file and parses it into perl code. After all files are parsed the perl code is evaluated and the template output is created. The use of the template output is determined by the C<print()> or the C<fetch()> method.

  $tpl->process(
  
      'header.tpl',
      'body.tpl',
      'footer.tpl',
  
  ) || die $tpl->error();

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

=head2 error()

On error, the C<process()> method returns false (C<undef>). Then the C<error()> method can be called to retrieve details of the error. 

  $tpl->process() || die $tpl->error();


=head1 OPTIONS

=head2 Variable Tag

  $KTemplate::VAR_START_TAG = '[%';
  $KTemplate::VAR_END_TAG   = '%]';

=head2 Block Tag
 
  $KTemplate::BLOCK_START_TAG = '<!--';
  $KTemplate::BLOCK_END_TAG   = '-->';

=head2 Root

  $KTemplate::ROOT = undef;  # default
  $KTemplate::ROOT = '/path/to/templates';
  
  $tpl = KTemplate->new( '/path/to/templates' );
  $tpl = KTemplate->new( ROOT => '/path/to/templates' );

=head2 Chomp

Deletes all whitespace characters preceding a block tag.

  $KTemplate::CHOMP = 1;  # default
  $KTemplate::CHOMP = 0;


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