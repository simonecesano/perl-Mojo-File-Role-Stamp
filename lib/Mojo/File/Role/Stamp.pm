package Mojo::File::Role::Stamp;

use strict;
use warnings;

use Mojo::Base -role;

sub gzextname {
    local $_ = shift()->basename;
    /(.+?)\.(([A-Za-z0-9]{1,4})(\.[A-Za-z0-9]{1,4})*)/;
    return $2;
}

sub date_stamp {
    local $_ = shift()->basename;
    my $date;
    if (/\-(\d{8})[\.\-]/) {
	$date = eval { Time::Piece->strptime($1, '%Y%m%d')->strftime('%Y%m%d') }
    }
    elsif (/\-(\d{12})[\.\-]/) {
	$date = eval { Time::Piece->strptime($1, '%Y%m%d%H%M')->strftime('%Y%m%d%H%M') }
    }
    elsif (/\-(\d{14})[\.\-]/) {
	$date = eval { Time::Piece->strptime($1, '%Y%m%d%H%M%S')->strftime('%Y%m%d%H%M%S') }
    }
    return $date;
}

sub md5_stamp {
    local $_ = shift()->basename;
    /\-([0-9a-f]{32,32})[\.\-]/i;
    return $1;
}

sub unstamped {
    my $self = shift();
    local $_ = $self->basename;
    my $md5  = $self->md5_stamp;
    my $date = $self->date_stamp;

    if ($date) { s/\-$date// }
    if ($md5)  { s/\-$md5// }

    Mojo::File->new($self->dirname, $_);
}

sub stamp {
    my $self = shift();
    my $opts = shift() || {};

    my $defaults = { time => '%Y%m%d', action => "copy" };
    for (keys $defaults->%*) { $opts->{$_} //= $defaults->{$_} }

    die sprintf "Error: cannot stamp non-existing file %s\n", "$self" unless -e $self;

    my $time = $opts->{now} ? time() : $self->stat->mtime ;
    my $md5  = $opts->{md5} ? md5_sum($self->slurp) : "";

    my $timestamp = Time::Piece->strptime($time, '%s')->strftime($opts->{time} || '%Y%m%d');

    my $unstamped = $self->unstamped;
    my $ext = $unstamped->with_roles('+Stamp')->gzextname;

    local $_ = $self->basename; s/\.$ext//;

    my $dest = $opts->{time} && $opts->{md5} ?
	Mojo::File->new($self->dirname, (sprintf "%s-%s-%s.%s", $_, $md5, $timestamp, $ext))
	:
	$opts->{time} ?
	Mojo::File->new($self->dirname, sprintf ("%s-%s.%s", $_, $timestamp, $ext))
	:
	Mojo::File->new($self->dirname, sprintf ("%s-%s.%s", $_, $md5, $ext));

    if ($opts->{action} eq "copy") {
	$self->copy_to($dest);
	utime $self->stat->atime, $self->stat->mtime, $dest;
    }
    elsif ($opts->{action} eq "move") {
	$self->move_to($dest)
    }
    return $dest;
}

1;
