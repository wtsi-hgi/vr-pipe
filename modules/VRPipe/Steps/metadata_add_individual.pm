
=head1 NAME

VRPipe::Steps::dcc_metadata - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Genome Research Limited.

This file is part of VRPipe.

VRPipe is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use VRPipe::Base;

class VRPipe::Steps::metadata_add_individual with VRPipe::StepRole {
    method options_definition {
        return {
            individual_file => VRPipe::StepOption->create(description => 'file containing mappings between sample ids and individuals'),
	}
    }
    
    method inputs_definition {
        return {
            bam_files => VRPipe::StepIODefinition->create(
                type        => 'bam',
                description => 'bam files',
                max_files   => -1,
                metadata    => {
                    sample         => 'sample name',
                }
            )
        };
    }
    
    method body_sub {
        return sub {
            my $self           = shift;
            my $options        = $self->options;
            my $indiv          = $options->{individual_file};
            foreach my $bam (@{ $self->inputs->{bam_files} }) {
                my $in_path  = $bam->path;
                my $ofile    = $self->output_file(output_key => 'bam_files', basename => $bam->basename, type => 'bam', metadata => $bam->metadata);
                my $out_path = $ofile->path;
                my $req      = $self->new_requirements(memory => 500, time => 1);
                my $this_cmd = "use VRPipe::Steps::metadata_add_individual; VRPipe::Steps::metadata_add_individual->add_individual_metadata(q[$indiv], q[$in_path], q[$out_path]);";
                $self->dispatch_vrpipecode($this_cmd, $req, { output_files => [$ofile] });
            }
        };
    }
    
    method outputs_definition {
        return {
            bam_files => VRPipe::StepIODefinition->create(
                type        => 'bam',
                description => 'a bam file with associated metadata',
                max_files   => -1,
                metadata    => {
                    sample         => 'sample name',
                    individual     => 'individual name',
                }
            )
        };
    }
    
    method post_process_sub {
        return sub {
            return 1;
        };
    }
    
    method description {
        return "Check the metadata in the bam header, vrpipe and the sequence index are all in agreement and the bam has the expected number of reads.";
    }
    
    method max_simultaneous {
        return 0;          # meaning unlimited
    }

    method get_map (ClassName|Object $self: Str $file) {
        open(my $fh, $file) || $self->throw("Couldn't open '$file': $!");
        my $lookup = {};
        while (<$fh>) {
            chomp;
            my @map = split /\t/;
            $lookup->{$map[0]} = $map[1];
        }
        close($fh);
        return $lookup;
    }

    
    method add_individual_metadata (ClassName|Object $self: Str|File $indiv_file, Str|File $bam!, Str|File $symlink!) {
        unless (ref($bam) && ref($bam) eq 'VRPipe::File') {
            $bam = VRPipe::File->get(path => file($bam));
        }
        unless (ref($symlink) && ref($symlink) eq 'VRPipe::File') {
            $symlink = VRPipe::File->get(path => file($symlink));
        }
        my $lookup = $self->get_map($indiv_file);
        my $sample = $bam->metadata->{ sample };
	$bam->add_metadata({ individual => $lookup->{$sample} });
        
        $bam->disconnect;
        
#        if (@fails) {
#        }
#        else {
            $bam->symlink($symlink);
            return 1;
#        }
    }
}

1;
