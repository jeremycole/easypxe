#!/usr/bin/perl -w

# Copyright (c) 2010 Jeremy Cole <jeremy@jcole.us>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package EasyPXE::Plugin::Event;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 0.00;

use Event::Lib;

sub timer_add
{
  my ($self, $delay, $interval, $function, @args) = @_;
  
  timer_new(sub {
    my ($e,$t,$s,@a)=@_;
    $s->$function(@a);
    $e->add($interval) if ($interval);
  }, $self, @args)->add($delay);
}

1;
