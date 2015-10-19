
=head1 NAME

VRPipe::Pipelines::bam_mapping_with_bwa_mem_hgi_via_fastq - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.
Martin Pollard <mp15@sanger.ac.uk>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012, 2014 Genome Research Limited.

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

class VRPipe::Pipelines::bam_mapping_with_bwa_mem_hgi_via_fastq with VRPipe::PipelineRole {
    method name {
        return 'bam_mapping_with_bwa_mem_hgi_via_fastq';
    }
    
    method description {
        return 'Map reads in bam files to a reference genome with bwa via fastq.';
    }
    
    method step_names {
        (
            'sequence_dictionary',   #1
            'bwa_index',             #2
            'bam_metadata',          #3
            'bam_name_sort',         #4
            'bam_to_fastq',          #5
            'fastq_split',           #6
            'bwa_mem_fastq',         #7
            'sam_to_fixed_ns_bam',   #8
            'bam_merge_lane_splits', #9
            'bam_merge_align',       #10
            'bam_sort',              #11
            'bam_calculate_bq',      #12
            'bam_mark_duplicates',   #13
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 3, to_key   => 'bam_files' },
            { from_step => 0, to_step => 4, to_key   => 'bam_files' },
            { from_step => 1, to_step => 9, from_key => 'reference_dict', to_key => 'dict_file' },
            { from_step => 4, to_step => 10, from_key => 'name_sorted_bam_files', to_key => 'input_bam_files' },
            { from_step => 4, to_step => 5, from_key => 'name_sorted_bam_files', to_key => 'bam_files' },
            { from_step => 5, to_step => 6, from_key => 'fastq_files', to_key => 'fastq_files' },
            { from_step => 6, to_step => 7, from_key => 'split_fastq_files', to_key => 'fastq_files' },
            { from_step => 7, to_step => 8, from_key => 'bwa_mem_sam_files', to_key => 'sam_files' },
            { from_step => 8, to_step => 9, from_key => 'fixed_bam_files', to_key => 'bam_files' },
            { from_step => 9, to_step => 10, from_key => 'merged_lane_bams', to_key => 'aligned_bam_files' },
            { from_step => 10, to_step => 11, from_key => 'merge_align_bam_files', to_key => 'bam_files' },
            { from_step => 11, to_step => 12, from_key => 'coord_sorted_bam_files', to_key => 'bam_files' },
            { from_step => 12, to_step => 13, from_key => 'bq_bam_files', to_key => 'bam_files' },
        );
    }
    
    method behaviour_definitions {
        (
            { after_step => 7, behaviour => 'delete_outputs', act_on_steps => [5, 6], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 9, behaviour => 'delete_outputs', act_on_steps => [8], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 10, behaviour => 'delete_outputs', act_on_steps => [4, 9], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 11, behaviour => 'delete_outputs', act_on_steps => [10], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 12, behaviour => 'delete_outputs', act_on_steps => [11], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 13, behaviour => 'delete_outputs', act_on_steps => [12], regulated_by => 'cleanup', default_regulation => 1 },
        );
    }
}

1;
