#line 1
package Plack::Loader;
use strict;
use Carp ();
use Plack::Util;
use Try::Tiny;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub watch {
    # do nothing. Override in subclass
}

sub auto {
    my($class, @args) = @_;

    my $backend = $class->guess
        or Carp::croak("Couldn't auto-guess server server implementation. Set it with PLACK_SERVER");

    my $server = try {
        $class->load($backend, @args);
    } catch {
        if (($ENV{PLACK_ENV}||'') eq 'development' or !/^Can't locate /) {
            warn "Autoloading '$backend' backend failed. Falling back to the Standalone. ",
                "(You might need to install Plack::Handler::$backend from CPAN.  Caught error was: $_)\n"
                    if $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development';
        }
        $class->load('Standalone' => @args);
    };

    return $server;
}

sub load {
    my($class, $server, @args) = @_;

    my($server_class, $error);
    for my $prefix (qw( Plack::Handler Plack::Server )) {
        try {
            $server_class = Plack::Util::load_class($server, $prefix);
        } catch {
            $error ||= $_;
        };
        last if $server_class;
        last if $error && $error !~ /^Can't locate Plack\/Handler\//;
    }

    if ($server_class) {
        $server_class->new(@args);
    } else {
        die $error;
    }
}

sub preload_app {
    my($self, $builder) = @_;
    $self->{app} = $builder->();
}

sub guess {
    my $class = shift;

    my $env = $class->env;

    return $env->{PLACK_SERVER} if $env->{PLACK_SERVER};

    if ($env->{PHP_FCGI_CHILDREN} || $env->{FCGI_ROLE} || $env->{FCGI_SOCKET_PATH}) {
        return "FCGI";
    } elsif ($env->{GATEWAY_INTERFACE}) {
        return "CGI";
    } elsif (exists $INC{"Coro.pm"}) {
        return "Corona";
    } elsif (exists $INC{"AnyEvent.pm"}) {
        return "Twiggy";
    } elsif (exists $INC{"POE.pm"}) {
        return "POE";
    } else {
        return "Standalone";
    }
}

sub env { \%ENV }

sub run {
    my($self, $server, $builder) = @_;
    $server->run($self->{app});
}

1;

__END__

#line 140


