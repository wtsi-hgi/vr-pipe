
=head1 NAME

VRPipe::Pipelines::bam_improvement_and_update_vrtrack_hgi - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.

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

class VRPipe::Pipelines::bam_improvement_with_mark_dup_hgi with VRPipe::PipelineRole {
    method name {
        return 'bam_improvement_with_mark_dup_hgi';
    }
    
    method description {
        return 'Improves bam files by marking duplicates, realigning around known indels, fixing mate information, recalibrating quality scores and adding NM and BQ tags; adds the resulting bam to your VRTrack db';
    }
    
    method step_names {
        (
            'sequence_dictionary',                 #1
            'bam_metadata',                        #2
            'bam_index',                           #3
            'bam_mark_duplicates',                 #4
            'bam_index',                           #5
            'gatk_target_interval_creator_discovery',#6
            'bam_realignment_around_discovered_indels', #7
            'bam_index',                           #8
            'bam_fix_mates',                       #9
            'bam_index',                           #10
            'bam_count_covariates',                #11
            'bam_recalibrate_quality_scores',      #12
            'bam_calculate_bq',                    #13
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0,  to_step => 2,  to_key   => 'bam_files' },
            { from_step => 0,  to_step => 3,  to_key   => 'bam_files' },
            { from_step => 6,  to_step => 7,  from_key => 'intervals_file', to_key => 'intervals_file' },
            { from_step => 0,  to_step => 4,  to_key   => 'bam_files' },
            { from_step => 3,  to_step => 4,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 4,  to_step => 5,  from_key => 'markdup_bam_files', to_key => 'bam_files' },
            { from_step => 4,  to_step => 6,  from_key => 'markdup_bam_files', to_key => 'bam_files' },
            { from_step => 5,  to_step => 6,  from_key => 'bai_files', to_key   => 'bai_files' },
            { from_step => 4,  to_step => 7,  from_key => 'markdup_bam_files', to_key   => 'bam_files' },
            { from_step => 5,  to_step => 7,  from_key => 'bai_files', to_key   => 'bai_files' },
            { from_step => 7,  to_step => 8,  from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 7,  to_step => 9,  from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 8,  to_step => 9,  from_key => 'bai_files', to_key   => 'bai_files' },
            { from_step => 9,  to_step => 10,  from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 9,  to_step => 11,  from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 10,  to_step => 11,  from_key => 'bai_files', to_key   => 'bai_files' },
            { from_step => 11,  to_step => 12, from_key => 'bam_recalibration_files', to_key => 'bam_recalibration_files' },
            { from_step => 9,  to_step => 12, from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 10,  to_step => 12,  from_key => 'bai_files', to_key   => 'bai_files' },
            { from_step => 12, to_step => 13, from_key => 'recalibrated_bam_files', to_key => 'bam_files' },
        );
    }
    
    method behaviour_definitions {
       (
            { after_step => 4, behaviour => 'delete_inputs',  act_on_steps => [0], regulated_by => 'delete_input_bams', default_regulation => 0 },
            { after_step => 4, behaviour => 'delete_outputs', act_on_steps => [3], regulated_by => 'delete_input_bams', default_regulation => 0 },
            { after_step => 7, behaviour => 'delete_outputs', act_on_steps => [4, 5], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 9, behaviour => 'delete_outputs', act_on_steps => [7, 8], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 12, behaviour => 'delete_outputs', act_on_steps => [9,10,11], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 13, behaviour => 'delete_outputs', act_on_steps => [12], regulated_by => 'cleanup', default_regulation => 1 },
        );
    }
}

1;
