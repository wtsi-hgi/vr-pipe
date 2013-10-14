
=head1 NAME

VRPipe::Pipelines::1000genomes_illumina_mapping_with_improvement - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

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

class VRPipe::Pipelines::1000genomes_illumina_mapping_with_improvement with VRPipe::PipelineRole {
    method name {
        return '1000genomes_illumina_mapping_with_improvement';
    }
    
    method description {
        return 'Map (with improvement) Illumina reads in fastq files on the DCC ftp site to a reference genome with bwa';
    }
    
    method step_names {
        (
            'sequence_dictionary',                 #1
            'bwa_index',                           #2
            'fastq_import',                        #3
            'fastq_metadata',                      #4
            'fastq_split',                         #5
            'bwa_aln_fastq',                       #6
            'bwa_sam',                             #7
            'sam_to_fixed_bam',                    #8
            'bam_merge_lane_splits',               #9
            'bam_index',                           #10
            'gatk_target_interval_creator',        #11
            'bam_realignment_around_known_indels', #12
            'bam_index',                           #13
            'bam_count_covariates',                #14
            'bam_recalibrate_quality_scores',      #15
            'bam_calculate_bq',                    #16
            'bam_reheader',                        #17
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0,  to_step => 3,  to_key   => 'fastq_files' },
            { from_step => 3,  to_step => 4,  from_key => 'local_fastq_files', to_key => 'fastq_files' },
            { from_step => 3,  to_step => 5,  from_key => 'local_fastq_files', to_key => 'fastq_files' },
            { from_step => 5,  to_step => 6,  from_key => 'split_fastq_files', to_key => 'fastq_files' },
            { from_step => 5,  to_step => 7,  from_key => 'split_fastq_files', to_key => 'fastq_files' },
            { from_step => 6,  to_step => 7,  from_key => 'bwa_sai_files', to_key => 'sai_files' },
            { from_step => 7,  to_step => 8,  from_key => 'bwa_sam_files', to_key => 'sam_files' },
            { from_step => 8,  to_step => 9,  from_key => 'fixed_bam_files', to_key => 'bam_files' },
            { from_step => 1,  to_step => 9,  from_key => 'reference_dict', to_key => 'dict_file' },
            { from_step => 9,  to_step => 10, from_key => 'merged_lane_bams', to_key => 'bam_files' },
            { from_step => 11, to_step => 12, from_key => 'intervals_file', to_key => 'intervals_file' },
            { from_step => 9,  to_step => 12, from_key => 'merged_lane_bams', to_key => 'bam_files' },
            { from_step => 10, to_step => 12, from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 12, to_step => 13, from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 12, to_step => 14, from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 13, to_step => 14, from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 14, to_step => 15, from_key => 'bam_recalibration_files', to_key => 'bam_recalibration_files' },
            { from_step => 12, to_step => 15, from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 13, to_step => 15, from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 15, to_step => 16, from_key => 'recalibrated_bam_files', to_key => 'bam_files' },
            { from_step => 16, to_step => 17, from_key => 'bq_bam_files', to_key => 'bam_files' },
            { from_step => 1,  to_step => 17, from_key => 'reference_dict', to_key => 'dict_file' },
        );
    }
    
    method behaviour_definitions {
        (
            { after_step => 7, behaviour => 'delete_outputs', act_on_steps => [3, 5, 6], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 8, behaviour => 'delete_outputs', act_on_steps => [7], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 9, behaviour => 'delete_outputs', act_on_steps => [8], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 12, behaviour => 'delete_outputs', act_on_steps => [9, 10], regulated_by => 'remove_mapped_bams', default_regulation => 0 },
            { after_step => 15, behaviour => 'delete_outputs', act_on_steps => [12, 13, 14], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 16, behaviour => 'delete_outputs', act_on_steps => [15], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 17, behaviour => 'delete_outputs', act_on_steps => [16], regulated_by => 'cleanup', default_regulation => 1 }
        );
    }
}

1;
