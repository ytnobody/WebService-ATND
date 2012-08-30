#line 1
package File::Slurp;

my $printed ;

use strict;

use Carp ;
use Exporter ;
use Fcntl qw( :DEFAULT ) ;
use POSIX qw( :fcntl_h ) ;
use Symbol ;
use UNIVERSAL ;

use vars qw( @ISA %EXPORT_TAGS @EXPORT_OK $VERSION @EXPORT ) ;
@ISA = qw( Exporter ) ;

%EXPORT_TAGS = ( 'all' => [
	qw( read_file write_file overwrite_file append_file read_dir ) ] ) ;

@EXPORT = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT_OK = qw( slurp ) ;

$VERSION = '9999.14';

my $max_fast_slurp_size = 1024 * 100 ;

my $is_win32 = $^O =~ /win32/i ;

# Install subs for various constants that aren't set in older perls
# (< 5.005).  Fcntl on old perls uses Exporter to define subs without a
# () prototype These can't be overridden with the constant pragma or
# we get a prototype mismatch.  Hence this less than aesthetically
# appealing BEGIN block:

BEGIN {
	unless( defined &SEEK_SET ) {
		*SEEK_SET = sub { 0 };
		*SEEK_CUR = sub { 1 };
		*SEEK_END = sub { 2 };
	}

	unless( defined &O_BINARY ) {
		*O_BINARY = sub { 0 };
		*O_RDONLY = sub { 0 };
		*O_WRONLY = sub { 1 };
	}

	unless ( defined &O_APPEND ) {

		if ( $^O =~ /olaris/ ) {
			*O_APPEND = sub { 8 };
			*O_CREAT = sub { 256 };
			*O_EXCL = sub { 1024 };
		}
		elsif ( $^O =~ /inux/ ) {
			*O_APPEND = sub { 1024 };
			*O_CREAT = sub { 64 };
			*O_EXCL = sub { 128 };
		}
		elsif ( $^O =~ /BSD/i ) {
			*O_APPEND = sub { 8 };
			*O_CREAT = sub { 512 };
			*O_EXCL = sub { 2048 };
		}
	}
}

# print "OS [$^O]\n" ;

# print "O_BINARY = ", O_BINARY(), "\n" ;
# print "O_RDONLY = ", O_RDONLY(), "\n" ;
# print "O_WRONLY = ", O_WRONLY(), "\n" ;
# print "O_APPEND = ", O_APPEND(), "\n" ;
# print "O_CREAT   ", O_CREAT(), "\n" ;
# print "O_EXCL   ", O_EXCL(), "\n" ;


*slurp = \&read_file ;

sub read_file {

	my( $file_name, %args ) = @_ ;

	if ( !ref $file_name && 0 &&
	     -e $file_name && -s _ < $max_fast_slurp_size && ! %args && !wantarray ) {

		local( *FH ) ;

		unless( open( FH, $file_name ) ) {

			@_ = ( \%args, "read_file '$file_name' - sysopen: $!");
			goto &_error ;
		}

		my $read_cnt = sysread( FH, my $buf, -s _ ) ;

		unless ( defined $read_cnt ) {

# handle the read error

			@_ = ( \%args,
				"read_file '$file_name' - small sysread: $!");
			goto &_error ;
		}

		return $buf ;
	}

# set the buffer to either the passed in one or ours and init it to the null
# string

	my $buf ;
	my $buf_ref = $args{'buf_ref'} || \$buf ;
	${$buf_ref} = '' ;

	my( $read_fh, $size_left, $blk_size ) ;

# deal with ref for a file name
# it could be an open handle or an overloaded object

	if ( ref $file_name ) {

		my $ref_result = _check_ref( $file_name ) ;

		if ( ref $ref_result ) {

# we got an error, deal with it

			@_ = ( \%args, $ref_result ) ;
			goto &_error ;
		}

		if ( $ref_result ) {

# we got an overloaded object and the result is the stringified value
# use it as the file name

			$file_name = $ref_result ;
		}
		else {

# here we have just an open handle. set $read_fh so we don't do a sysopen

			$read_fh = $file_name ;
			$blk_size = $args{'blk_size'} || 1024 * 1024 ;
			$size_left = $blk_size ;
		}
	}

# see if we have a path we need to open

	unless ( $read_fh ) {

# a regular file. set the sysopen mode

		my $mode = O_RDONLY ;

#printf "RD: BINARY %x MODE %x\n", O_BINARY, $mode ;

# open the file and handle any error

		$read_fh = gensym ;
		unless ( sysopen( $read_fh, $file_name, $mode ) ) {
			@_ = ( \%args, "read_file '$file_name' - sysopen: $!");
			goto &_error ;
		}

		if ( my $binmode = $args{'binmode'} ) {
			binmode( $read_fh, $binmode ) ;
		}

# get the size of the file for use in the read loop

		$size_left = -s $read_fh ;

#print "SIZE $size_left\n" ;


# we need a blk_size if the size is 0 so we can handle pseudofiles like in
# /proc. these show as 0 size but have data to be slurped.

		unless( $size_left ) {

			$blk_size = $args{'blk_size'} || 1024 * 1024 ;
			$size_left = $blk_size ;
		}
	}


# 	if ( $size_left < 10000 && keys %args == 0 && !wantarray ) {

# #print "OPT\n" and $printed++ unless $printed ;

# 		my $read_cnt = sysread( $read_fh, my $buf, $size_left ) ;

# 		unless ( defined $read_cnt ) {

# # handle the read error

# 			@_ = ( \%args, "read_file '$file_name' - small2 sysread: $!");
# 			goto &_error ;
# 		}

# 		return $buf ;
# 	}

# infinite read loop. we exit when we are done slurping

	while( 1 ) {

# do the read and see how much we got

		my $read_cnt = sysread( $read_fh, ${$buf_ref},
				$size_left, length ${$buf_ref} ) ;

		unless ( defined $read_cnt ) {

# handle the read error

			@_ = ( \%args, "read_file '$file_name' - loop sysread: $!");
			goto &_error ;
		}

# good read. see if we hit EOF (nothing left to read)

		last if $read_cnt == 0 ;

# loop if we are slurping a handle. we don't track $size_left then.

		next if $blk_size ;

# count down how much we read and loop if we have more to read.

		$size_left -= $read_cnt ;
		last if $size_left <= 0 ;
	}

# fix up cr/lf to be a newline if this is a windows text file

	${$buf_ref} =~ s/\015\012/\n/g if $is_win32 && !$args{'binmode'} ;

# this is the 5 returns in a row. each handles one possible
# combination of caller context and requested return type

	my $sep = $/ ;
	$sep = '\n\n+' if defined $sep && $sep eq '' ;

# see if caller wants lines

	if( wantarray || $args{'array_ref'} ) {

		my @parts = split m/($sep)/, ${$buf_ref}, -1;

		my @lines ;

		while( @parts > 2 ) {

			my( $line, $sep ) = splice( @parts, 0, 2 ) ;
			push @lines, "$line$sep" ;
		}

		push @lines, shift @parts if @parts && length $parts[0] ;

		return @lines if wantarray ;
		return \@lines ;
	}

# caller wants a scalar ref to the slurped text

	return $buf_ref if $args{'scalar_ref'} ;

# caller wants a scalar with the slurped text (normal scalar context)

	return ${$buf_ref} if defined wantarray ;

# caller passed in an i/o buffer by reference (normal void context)

	return ;


# # caller wants to get an array ref of lines

# # this split doesn't work since it tries to use variable length lookbehind
# # the m// line works.
# #	return [ split( m|(?<=$sep)|, ${$buf_ref} ) ] if $args{'array_ref'}  ;
# 	return [ length(${$buf_ref}) ? ${$buf_ref} =~ /(.*?$sep|.+)/sg : () ]
# 		if $args{'array_ref'}  ;

# # caller wants a list of lines (normal list context)

# # same problem with this split as before.
# #	return split( m|(?<=$sep)|, ${$buf_ref} ) if wantarray ;
# 	return length(${$buf_ref}) ? ${$buf_ref} =~ /(.*?$sep|.+)/sg : ()
# 		if wantarray ;

# # caller wants a scalar ref to the slurped text

# 	return $buf_ref if $args{'scalar_ref'} ;

# # caller wants a scalar with the slurped text (normal scalar context)

# 	return ${$buf_ref} if defined wantarray ;

# # caller passed in an i/o buffer by reference (normal void context)

# 	return ;
}


# errors in this sub are returned as scalar refs
# a normal IO/GLOB handle is an empty return
# an overloaded object returns its stringified as a scalarfilename

sub _check_ref {

	my( $handle ) = @_ ;

# check if we are reading from a handle (GLOB or IO object)

	if ( eval { $handle->isa( 'GLOB' ) || $handle->isa( 'IO' ) } ) {

# we have a handle. deal with seeking to it if it is DATA

		my $err = _seek_data_handle( $handle ) ;

# return the error string if any

		return \$err if $err ;

# we have good handle
		return ;
	}

	eval { require overload } ;

# return an error if we can't load the overload pragma
# or if the object isn't overloaded

	return \"Bad handle '$handle' is not a GLOB or IO object or overloaded"
		 if $@ || !overload::Overloaded( $handle ) ;

# must be overloaded so return its stringified value

	return "$handle" ;
}

sub _seek_data_handle {

	my( $handle ) = @_ ;

# DEEP DARK MAGIC. this checks the UNTAINT IO flag of a
# glob/handle. only the DATA handle is untainted (since it is from
# trusted data in the source file). this allows us to test if this is
# the DATA handle and then to do a sysseek to make sure it gets
# slurped correctly. on some systems, the buffered i/o pointer is not
# left at the same place as the fd pointer. this sysseek makes them
# the same so slurping with sysread will work.

	eval{ require B } ;

	if ( $@ ) {

		return <<ERR ;
Can't find B.pm with this Perl: $!.
That module is needed to properly slurp the DATA handle.
ERR
	}

	if ( B::svref_2object( $handle )->IO->IoFLAGS & 16 ) {

# set the seek position to the current tell.

		unless( sysseek( $handle, tell( $handle ), SEEK_SET ) ) {
			return "read_file '$handle' - sysseek: $!" ;
		}
	}

# seek was successful, return no error string

	return ;
}


sub write_file {

	my $file_name = shift ;

# get the optional argument hash ref from @_ or an empty hash ref.

	my $args = ( ref $_[0] eq 'HASH' ) ? shift : {} ;

	my( $buf_ref, $write_fh, $no_truncate, $orig_file_name, $data_is_ref ) ;

# get the buffer ref - it depends on how the data is passed into write_file
# after this if/else $buf_ref will have a scalar ref to the data.

	if ( ref $args->{'buf_ref'} eq 'SCALAR' ) {

# a scalar ref passed in %args has the data
# note that the data was passed by ref

		$buf_ref = $args->{'buf_ref'} ;
		$data_is_ref = 1 ;
	}
	elsif ( ref $_[0] eq 'SCALAR' ) {

# the first value in @_ is the scalar ref to the data
# note that the data was passed by ref

		$buf_ref = shift ;
		$data_is_ref = 1 ;
	}
	elsif ( ref $_[0] eq 'ARRAY' ) {

# the first value in @_ is the array ref to the data so join it.

		${$buf_ref} = join '', @{$_[0]} ;
	}
	else {

# good old @_ has all the data so join it.

		${$buf_ref} = join '', @_ ;
	}

# deal with ref for a file name

	if ( ref $file_name ) {

		my $ref_result = _check_ref( $file_name ) ;

		if ( ref $ref_result ) {

# we got an error, deal with it

			@_ = ( $args, $ref_result ) ;
			goto &_error ;
		}

		if ( $ref_result ) {

# we got an overloaded object and the result is the stringified value
# use it as the file name

			$file_name = $ref_result ;
		}
		else {

# we now have a proper handle ref.
# make sure we don't call truncate on it.

			$write_fh = $file_name ;
			$no_truncate = 1 ;
		}
	}

# see if we have a path we need to open

	unless( $write_fh ) {

# spew to regular file.

		if ( $args->{'atomic'} ) {

# in atomic mode, we spew to a temp file so make one and save the original
# file name.
			$orig_file_name = $file_name ;
			$file_name .= ".$$" ;
		}

# set the mode for the sysopen

		my $mode = O_WRONLY | O_CREAT ;
		$mode |= O_APPEND if $args->{'append'} ;
		$mode |= O_EXCL if $args->{'no_clobber'} ;

		my $perms = $args->{perms} ;
		$perms = 0666 unless defined $perms ;

#printf "WR: BINARY %x MODE %x\n", O_BINARY, $mode ;

# open the file and handle any error.

		$write_fh = gensym ;
		unless ( sysopen( $write_fh, $file_name, $mode, $perms ) ) {
			@_ = ( $args, "write_file '$file_name' - sysopen: $!");
			goto &_error ;
		}
	}

	if ( my $binmode = $args->{'binmode'} ) {
		binmode( $write_fh, $binmode ) ;
	}

	sysseek( $write_fh, 0, SEEK_END ) if $args->{'append'} ;


#print 'WR before data ', unpack( 'H*', ${$buf_ref}), "\n" ;

# fix up newline to write cr/lf if this is a windows text file

	if ( $is_win32 && !$args->{'binmode'} ) {

# copy the write data if it was passed by ref so we don't clobber the
# caller's data
		$buf_ref = \do{ my $copy = ${$buf_ref}; } if $data_is_ref ;
		${$buf_ref} =~ s/\n/\015\012/g ;
	}

#print 'after data ', unpack( 'H*', ${$buf_ref}), "\n" ;

# get the size of how much we are writing and init the offset into that buffer

	my $size_left = length( ${$buf_ref} ) ;
	my $offset = 0 ;

# loop until we have no more data left to write

	do {

# do the write and track how much we just wrote

		my $write_cnt = syswrite( $write_fh, ${$buf_ref},
				$size_left, $offset ) ;

		unless ( defined $write_cnt ) {

# the write failed
			@_ = ( $args, "write_file '$file_name' - syswrite: $!");
			goto &_error ;
		}

# track much left to write and where to write from in the buffer

		$size_left -= $write_cnt ;
		$offset += $write_cnt ;

	} while( $size_left > 0 ) ;

# we truncate regular files in case we overwrite a long file with a shorter file
# so seek to the current position to get it (same as tell()).

	truncate( $write_fh,
		  sysseek( $write_fh, 0, SEEK_CUR ) ) unless $no_truncate ;

	close( $write_fh ) ;

# handle the atomic mode - move the temp file to the original filename.

	if ( $args->{'atomic'} && !rename( $file_name, $orig_file_name ) ) {

		@_ = ( $args, "write_file '$file_name' - rename: $!" ) ;
		goto &_error ;
	}

	return 1 ;
}

# this is for backwards compatibility with the previous File::Slurp module. 
# write_file always overwrites an existing file

*overwrite_file = \&write_file ;

# the current write_file has an append mode so we use that. this
# supports the same API with an optional second argument which is a
# hash ref of options.

sub append_file {

# get the optional args hash ref
	my $args = $_[1] ;
	if ( ref $args eq 'HASH' ) {

# we were passed an args ref so just mark the append mode

		$args->{append} = 1 ;
	}
	else {

# no args hash so insert one with the append mode

		splice( @_, 1, 0, { append => 1 } ) ;
	}

# magic goto the main write_file sub. this overlays the sub without touching
# the stack or @_

	goto &write_file
}

# basic wrapper around opendir/readdir

sub read_dir {

	my ($dir, %args ) = @_;

# this handle will be destroyed upon return

	local(*DIRH);

# open the dir and handle any errors

	unless ( opendir( DIRH, $dir ) ) {

		@_ = ( \%args, "read_dir '$dir' - opendir: $!" ) ;
		goto &_error ;
	}

	my @dir_entries = readdir(DIRH) ;

	@dir_entries = grep( $_ ne "." && $_ ne "..", @dir_entries )
		unless $args{'keep_dot_dot'} ;

	return @dir_entries if wantarray ;
	return \@dir_entries ;
}

# error handling section
#
# all the error handling uses magic goto so the caller will get the
# error message as if from their code and not this module. if we just
# did a call on the error code, the carp/croak would report it from
# this module since the error sub is one level down on the call stack
# from read_file/write_file/read_dir.


my %err_func = (
	'carp'	=> \&carp,
	'croak'	=> \&croak,
) ;

sub _error {

	my( $args, $err_msg ) = @_ ;

# get the error function to use

 	my $func = $err_func{ $args->{'err_mode'} || 'croak' } ;

# if we didn't find it in our error function hash, they must have set
# it to quiet and we don't do anything.

	return unless $func ;

# call the carp/croak function

	$func->($err_msg) if $func ;

# return a hard undef (in list context this will be a single value of
# undef which is not a legal in-band value)

	return undef ;
}

1;
__END__

#line 993
