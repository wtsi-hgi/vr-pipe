
=head1 NAME

VRPipe::Steps::bam_merge_align - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.
Martin Pollard <mp15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011,2012,2014 Genome Research Limited.

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

class VRPipe::Steps::bam_merge_align extends VRPipe::Steps::illumina2bam_generic {
    around options_definition {
        return {
            %{ $self->$orig },
            merge_align_options => VRPipe::StepOption->create(description => 'command line options for Illumina2BAM BamMerger', optional => 1, default_value => 'VALIDATION_STRINGENCY=SILENT'),
        };
    }
    
    method inputs_definition {
        return { input_bam_files => VRPipe::StepIODefinition->create(type => 'bam', max_files => -1, description => '1 or more name-sorted bam files'),
		 aligned_bam_files => VRPipe::StepIODefinition->create(type => 'bam', max_files => -1, description => '1 or more name-sorted bam files') };
    }
    
    method body_sub {
        return sub {
            my $self    = shift;
            my $options = $self->options;
            $self->handle_standard_options($options);
            my $markdup_jar = $self->jar('BamMerger.jar');
            
            my $markdup_opts = $options->{merge_align_options};
            my $ref = $options->{reference_fasta};
            
            $self->set_cmd_summary(
                VRPipe::StepCmdSummary->create(
                    exe     => 'illumina2bam',
                    version => $self->illumina2bam_version(),
                    summary => 'java $jvm_args -jar BamMerger.jar INPUT=$bam_file ALIGNED=$aligned_bam_file OUTPUT=$markdup_bam_file ' . $markdup_opts
                )
            );
            
            my $req = $self->new_requirements(memory => 2500, time => 2);
            for my $i ($@{ $self->inputs->{input_bam_files} }) {
                my $bam = @{ $self->inputs->{input_bam_files} }[$i];
                my $aligned_bam = @{ $self->inputs->{aligned_bam_files} }[$i];
                my $bam_base     = $bam->basename;
                my $bam_meta     = $bam->metadata;
                my $markdup_base = $bam_base;
                $markdup_base =~ s/bam$/merge_align.bam/;
                my $markdup_bam_file = $self->output_file(
                    output_key => 'merge_align_bam_files',
                    basename   => $markdup_base,
                    type       => 'bam',
                    metadata   => $bam_meta
                );
                
                my $temp_dir = $options->{tmp_dir} || $markdup_bam_file->dir;
                my $jvm_args = $self->jvm_args($req->memory, $temp_dir);
                
                my $this_cmd = $self->java_exe . " $jvm_args -jar $markdup_jar INPUT=" . $bam->path . " ALIGNED=" . $aligned_bam->path . " OUTPUT=" . $markdup_bam_file->path . " $markdup_opts";
                $self->dispatch_wrapped_cmd('VRPipe::Steps::bam_merge_align', 'merge_align_and_check', [$this_cmd, $req, { output_files => [$markdup_bam_file] }]);
            }
        };
    }
    
    method outputs_definition {
        return { merge_align_bam_files => VRPipe::StepIODefinition->create(type => 'bam', max_files => -1, description => 'a bam file with alignment merged in') };
    }
    
    method post_process_sub {
        return sub { return 1; };
    }
    
    method description {
        return "Merge alignment information in a bam file into another bam file using Illumina2BAM";
    }
    
    method max_simultaneous {
        return 0;            # meaning unlimited
    }
    
    method merge_align_and_check (ClassName|Object $self: Str $cmd_line) {
        my ($in_path)  = $cmd_line =~ /ALIGNED=(\S+)/;
	my ($out_path) = $cmd_line =~ /OUTPUT=(\S+)/;
        $in_path  || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        $out_path || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        
        my $in_file  = VRPipe::File->get(path => $in_path);
        my $out_file = VRPipe::File->get(path => $out_path);
        
        $in_file->disconnect;
        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        $out_file->update_stats_from_disc(retries => 3);
        my $expected_reads = $in_file->metadata->{reads} || $in_file->num_records;
        my $actual_reads = $out_file->num_records;
        
        if ($actual_reads == $expected_reads) {
            return 1;
        }
        else {
            $out_file->unlink;
            $self->throw("cmd [$cmd_line] failed because $actual_reads reads were generated in the output bam file, yet there were $expected_reads reads in the original bam file");
        }
    }
}

1;
