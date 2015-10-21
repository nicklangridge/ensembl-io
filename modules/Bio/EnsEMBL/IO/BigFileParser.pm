=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

BigFileParser - a parser for indexed files such as BigBed and BigWig 

=cut

package Bio::EnsEMBL::IO::BigFileParser;

use strict;
use warnings;

use List::Util qw(max);

use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;
use Bio::EnsEMBL::IO::Utils;

use parent qw(Bio::EnsEMBL::IO::Parser);

=head2 new

    Constructor
    Argument [1+]: Hash of parameters for configuration, e.g. buffer sizes or 
                   specific functions for handling headers or data
    Returntype   : Bio::EnsEMBL::IO::BigFileParser

=cut

sub new {
    my ($class, $url) = @_;
    
    my $self = {
      url               => $url,
      cache             => {
                            'file_handle' => undef,
                            'features'    => [],
                            },
      current_block     => undef,
      waiting_block     => undef,
      record            => undef,
      strand_conversion => {'+' => '1', '.' => '0', '-' => '-1'},
    };

    bless $self, $class;
   
    return $self;
}

=head2 open

    Constructor
    Argument [1] : Filepath or GLOB or open filehandle
    Argument [2+]: Hash of parameters for configuration, e.g. buffer sizes or 
                   specific functions for handling headers or data
    Returntype   : Bio::EnsEMBL::IO::BigFileParser

=cut

sub open {
    my ($caller, $url, @other_args) = @_;
    #warn ">>> OPENING BIGFILE $url";
    my $class = ref($caller) || $caller;

    my $self = $class->new($url, @other_args);

    ## Open and cache the file handle
    my $fh = $self->open_file;
    #warn ">>> OPENED FILE WITH $fh";
 
    ## Cache the chromosome list from the file, mapping Ensembl's non-'chr' names 
    ## to the file's actual chromosome names
    my $list = $fh->chromList;
    my $head = $list->head;
    my $chromosomes = {};
    do {
      if ($head->name && $head->size) {
        (my $chr = $head->name) =~ s/^chr//;
        $chromosomes->{$chr} = $head->name;
      }
    } while ($head && ($head = $head->next));
    #use Data::Dumper; warn Dumper($chromosomes);
    $self->{cache}{chromosomes} = $chromosomes;

    return $self;
}


=head2 type

    Description : Placeholder for accessor 
    Returntype  : String

=cut

sub type {
      confess("Method not implemented. This is really important");
}

=head2 url

    Description : Accessor for file url
    Returntype  : String

=cut

sub url {
  my $self = shift;
  return $self->{'url'};
}

=head2 cache

    Description : Accessor for cache
    Returntype  : Hashref

=cut

sub cache {
  my $self = shift;
  return $self->{'cache'};
}


=head2 open

    Description: Opens a remote file from URL
    Returntype : Filehandle 

=cut

sub open_file {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;

  my $method = $self->type.'FileOpen';
  $self->{cache}->{file_handle} ||= Bio::DB::BigFile->$method($self->url);
  return $self->{cache}->{file_handle};
}

=head2 next_block

    Description: Shifts to next block. Note that Big files don't have metadata 
    Returntype : Void

=cut

sub next_block {
    my $self = shift;
    $self->shift_block();
}

=head2 read_block

    Description : Reads a line of text, stores it into next_block, 
                  moving next_block to current_block.
    Returntype   : True/False on existence of a defined current_block after running.

=cut

sub read_block {
    my $self = shift;
    my $features = $self->{'cache'}{'features'};

    if (scalar @$features) {
        $self->{'waiting_block'} = shift @$features || confess ("Error reading cached features: $!");
    } else {
        $self->{'waiting_block'} = undef;
    }
}

=head2 read_record

    Description: Features are cached as an array, so no processing needed 
    Returntype : Void 

=cut


sub read_record {
    my $self = shift;
    $self->{'record'} = $self->{'current_block'};
}


1;