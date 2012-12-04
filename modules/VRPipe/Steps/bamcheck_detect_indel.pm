
=head1 NAME

VRPipe::Steps::convex_L2R - a step

=head1 DESCRIPTION

Runs the SampleLogRatio R script from the CoNVex packages. Runs once per
pipeline, generating a log2 ratio file for each read depth file and a single
features file.

=head1 AUTHOR

Chris Joyce <cj5@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 Genome Research Limited.

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

class VRPipe::Steps::bamcheck_detect_indel extends VRPipe::Steps::r_script {
    around options_definition {
        return {
            %{ $self->$orig },
            'hgi_rscript_path' => VRPipe::StepOption->create(description => 'full path to hgi R scripts'),
            'k'                => VRPipe::StepOption->create(description => 'sliding window size'),
            'baseline_method'  => VRPipe::StepOption->create(description => 'controls which method is used to set the baseline'),
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
            
            my $hgi_rscript_path = $options->{'hgi_rscript_path'};
            my $method           = $options->{'baseline_method'};
            my $window_size      = $options->{'k'};
            
            my $req = $self->new_requirements(memory => 2000, time => 1);
            
            # make a copy of our input file
            foreach my $bamcheck_file (@{ $self->inputs->{bam_files} }) {
                my $output_bamcheck = $self->output_file(output_key => 'bamcheck_files', basename => $bamcheck_file->basename, type => 'txt', metadata => $bamcheck_file->metadata);
                $bamcheck_file->copy($output_bamcheck);
                
                my $bamcheck_path = $output_bamcheck->path;
                
                my $cmd = $self->rscript_cmd_prefix . " $hgi_rscript_path/bamcheck_indel_peaks.R bamcheck=\"$bamcheck_path\", outfile=\"$bamcheck_path\", k=$window_size, baseline.method=\"$method\"";
                
                $self->dispatch([$cmd, $req, { output_files => [$bamcheck_file] }]);
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
        return "Runs baseline check on indels";
    }
}

1;
