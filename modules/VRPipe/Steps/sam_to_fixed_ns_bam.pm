
=head1 NAME

VRPipe::Steps::sam_to_fixed_ns_bam - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Genome Research Limited.

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

class VRPipe::Steps::sam_to_fixed_ns_bam with VRPipe::StepRole {
    method options_definition {
        return {
            uncompressed_fixed_bam_output => VRPipe::StepOption->create(
                description   => 'A boolean to choose if the output bams from this step should be uncompressed',
                optional      => 1,
                default_value => 1
            ),
            samtools_exe => VRPipe::StepOption->create(
                description   => 'path to your samtools executable',
                optional      => 1,
                default_value => 'samtools'
            )
        };
    }
    
    method inputs_definition {
        return {
            sam_files => VRPipe::StepIODefinition->create(
                type        => 'txt',
                max_files   => -1,
                description => 'raw sam files from a mapper',
                metadata    => {
                    reads  => 'total number of reads (sequences)',
                    paired => '0=unpaired reads were mapped; 1=paired reads were mapped'
                }
            )
        };
    }
    
    method body_sub {
        return sub {
            my $self    = shift;
            my $options = $self->options;
            
            my $samtools = $options->{samtools_exe};
            
            my $u = $options->{uncompressed_fixed_bam_output} ? ' -u' : ' -b';
            $self->set_cmd_summary(
                VRPipe::StepCmdSummary->create(
                    exe     => 'samtools',
                    version => VRPipe::StepCmdSummary->determine_version($samtools, '^Version: (.+)$'),
                    summary => "samtools fixmate \$sam_file \$fixed_bam_file"
                )
            );
            
            my $req = $self->new_requirements(memory => 2900, time => 1);
            foreach my $sam (@{ $self->inputs->{sam_files} }) {
                my $bam_basename = $sam->basename;
                $bam_basename =~ s/\.sam$//;
                my $prefix_base = '.' . $bam_basename;
                $bam_basename .= '.bam';
                
                my $bam_file = $self->output_file(
                    output_key => 'fixed_bam_files',
                    basename   => $bam_basename,
                    type       => 'bam',
                    metadata   => $sam->metadata
                );
                
                my $bam_dir  = $bam_file->dir;
                my $sam_path = $sam->path;
                my $bam_path = $bam_file->path;
                
                my $this_cmd = "$samtools fixmate $sam_path $bam_path";
                
                $self->dispatch_wrapped_cmd('VRPipe::Steps::sam_to_fixed_ns_bam', 'fix_and_check', [$this_cmd, $req, { output_files => [$bam_file] }]);
            }
        };
    }
    
    method outputs_definition {
        return {
            fixed_bam_files => VRPipe::StepIODefinition->create(
                type        => 'bam',
                max_files   => -1,
                description => 'uncompressed name-sorted bam file(s)',
                metadata    => {
                    reads  => 'total number of reads (sequences)',
                    paired => '0=unpaired reads were mapped; 1=paired reads were mapped'
                }
            )
        };
    }
    
    method post_process_sub {
        return sub { return 1; };
    }
    
    method description {
        return "Turns a sam file into an uncompressed name-sorted bam file with fixed mates.";
    }
    
    method max_simultaneous {
        return 0;
    }
    
    method fix_and_check (ClassName|Object $self: Str $cmd_line) {
        my ($samtools, $sam_path, $bam_path) = $cmd_line =~ /^(\S+) fixmate (\S+) (\S+)$/;
        $bam_path || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        
        my $sam_file = VRPipe::File->get(path => $sam_path);
        my $bam_file = VRPipe::File->get(path => $bam_path);
        
        $bam_file->disconnect;
        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        my $expected_reads = $sam_file->metadata->{reads};
        $bam_file->update_stats_from_disc(retries => 3);
        my $actual_reads = $bam_file->num_records;
        
        if ($actual_reads == $expected_reads) {
            return 1;
        }
        else {
            $bam_file->unlink;
            $self->throw("cmd [$cmd_line] failed because $actual_reads lines were generated in the bam file, yet there were $expected_reads reads in the sam file");
        }
    }
}

1;
