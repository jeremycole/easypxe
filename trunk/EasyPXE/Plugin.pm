#!/usr/bin/perl -w

# Copyright (c) 2010 Jeremy Cole
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

package EasyPXE::Plugin;

use strict;
use warnings;

our $VERSION = 0.00;

our $PLUGIN_STATUS_OK         = 1;
our $PLUGIN_STATUS_FAILED     = 2;

our %PLUGIN_STATUS = (
  $PLUGIN_STATUS_OK       => "OK",
  $PLUGIN_STATUS_FAILED   => "FAILED",
);

sub new
{
  my ($class, $config, $plugin) = @_;
  my $self = {};

  $self->{'CONFIG'} = $config;
  $self->{'PLUGIN'} = $plugin;
  $self->{'CONFIG_PLUGIN'} = {};

  bless($self, $class);
  return $self;
}

sub config($)
{
  my ($self) = @_;
  
  return $self->{'CONFIG'};
}

sub plugin($)
{
  my ($self) = @_;
  
  return $self->{'PLUGIN'};
}

sub config_plugin($)
{
  my ($self) = @_;
  
  return $self->{'CONFIG_PLUGIN'};
}

sub dbh($)
{
  my ($self) = @_;
  
  return $self->plugin->{'dbi'}->dbh();
}

sub initialize_priority()
{
  return 10;
}

#
# Return a list of configuration keys which must be defined by config_plugin
# options in order to successfully load this plugin.  Re-define this in any
# plugin for which you need configuration.
#
sub needed_config_keys()
{
  return ();
}

#
# Attempt to load this plugin's configuration into the object's namespace.
# Re-define this only if the plugin needs something very special done
# instead of just loading needed_config_keys.  In any case, return the list
# of the configuration keys which were missing/not defined.  An empty list
# returned indicates success.
#
sub load_config()
{
  my ($self) = @_;

  foreach my $needed_key ($self->needed_config_keys())
  {
    $self->config_plugin->{$needed_key} = undef;
  }
  
  foreach my $config_item (@{$self->config->get('config_plugin')})
  {
    my ($key, $value) = split /=/, $config_item;

    if(exists($self->config_plugin->{$key}))
    {
      $self->config_plugin->{$key} = $value;
    }
  }

  my @missing_keys = ();
  foreach my $needed_key ($self->needed_config_keys())
  {
    if(!defined($self->config_plugin->{$needed_key}))
    {
      push @missing_keys, $needed_key;
    }
  }

  return @missing_keys;
}

#
# Do any initialization work you want to do before we enter the event loop.
# This is a good place to add any timers or other events you might want to
# be triggered.
#
sub initialize($)
{
  return $EasyPXE::Plugin::PLUGIN_STATUS_OK;
}

#
# Do any cleanup work you'd like to do on clean shutdown.
#
sub shutdown($)
{
}

1;
