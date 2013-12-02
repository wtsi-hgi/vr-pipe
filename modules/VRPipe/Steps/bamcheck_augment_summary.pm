
=head1 NAME

VRPipe::Steps::bamcheck_augment_summary - a step

=head1 DESCRIPTION

=head1 AUTHOR

Martin Pollard <mp15@sanger.co.uk>
Joshua Randall <jcrandall@alum.mit.edu>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012, 2013 Genome Research Limited.

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

class VRPipe::Steps::bamcheck_augment_summary extends VRPipe::Steps::r_script {
    around options_definition {
        return {
            %{ $self->$orig },
            'hgi_rscript_augment_path' => VRPipe::StepOption->create(description => 'full path to hgi R script for augmenting bamcheck summary data'),
        };
    }
    
    method inputs_definition {
        return {
            bamcheck_files => VRPipe::StepIODefinition->create(
                type        => 'txt',
                description => 'bamcheck files',
                max_files   => -1,
                metadata    => {
                    source_bam => 'path to the bam file this bamcheck file was created from',
                    lane       => 'lane name (a unique identifer for this sequencing run, aka read group)',
                }
            ),
        };
    }
    
    method body_sub {
        return sub {
            my $self = shift;
            
            my $options = $self->options;
            $self->handle_standard_options($options);
            
            my $hgi_rscript_path = $options->{'hgi_rscript_augment_path'};
            
            my $req = $self->new_requirements(memory => 2000, time => 1);
            
            # make a copy of our input file
            foreach my $bamcheck_file (@{ $self->inputs->{bamcheck_files} }) {
                my $output_bamcheck = $self->output_file(output_key => 'bamcheck_files', basename => $bamcheck_file->basename, type => 'txt', metadata => $bamcheck_file->metadata);
                
		my $bamcheck_in_path = $bamcheck_file->path;
                my $bamcheck_out_path = $output_bamcheck->path;
		$output_bamcheck->disconnect();
                
                my $cmd = $self->rscript_cmd_prefix . " $hgi_rscript_path \"$bamcheck_in_path\" \"$bamcheck_out_path\"";
                
                $self->dispatch([$cmd, $req, { output_files => [$output_bamcheck] }]);
            }
        
        };
    }
    
    method outputs_definition {
        return {
            bamcheck_files => VRPipe::StepIODefinition->create(
                type        => 'txt',
                description => 'the output of bamcheck on a bam',
                max_files   => -1,
                metadata    => {
                    source_bam => 'path to the bam file this bamcheck file was created from',
                    lane       => 'lane name (a unique identifer for this sequencing run, aka read group)'
                }
            ),
        };
    }
    
    method post_process_sub {
        return sub { return 1; };
    }
    
    method description {
        return "Augments bamcheck data with additional summary numbers calculated from other section data";
    }
}

1;
