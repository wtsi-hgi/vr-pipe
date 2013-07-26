
=head1 NAME

VRPipe::Pipelines::bam_improvement_hgi - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.
Martin Pollard <mp15@sanger.ac.uk>.

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

class VRPipe::Pipelines::bam_improvement_hgi with VRPipe::PipelineRole {
    method name {
        return 'bam_improvement_hgi';
    }
    
    method description {
        return 'Improves bam files by realigning around known and discovered indels, fixing mate information, recalibrating quality scores and adding NM and BQ tags.';
    }
    
    method step_names {
        (
            'sequence_dictionary',                 #1
            'bam_metadata',                        #2
            'bam_index',                           #3
            'gatk_target_interval_creator_discovery', #4
            'bam_realignment_around_discovered_indels', #5
            'bam_index',                           #6
            'bam_fix_mates',                       #7
            'bam_index',                           #8
            'bam_count_covariates',                #9
            'bam_recalibrate_quality_scores',      #10
            'bam_calculate_bq',                    #11
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0,  to_step => 2,  to_key   => 'bam_files' },
            { from_step => 0,  to_step => 3,  to_key   => 'bam_files' },
            { from_step => 0,  to_step => 4,  to_key   => 'bam_files' },
            { from_step => 3,  to_step => 4,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 4,  to_step => 5,  from_key => 'intervals_file', to_key => 'intervals_file' },
            { from_step => 0,  to_step => 5,  to_key   => 'bam_files' },
            { from_step => 3,  to_step => 5,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 5,  to_step => 6,  from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 5,  to_step => 7,  from_key => 'realigned_bam_files', to_key => 'bam_files' },
            { from_step => 6,  to_step => 7,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 7,  to_step => 8,  from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 7,  to_step => 9,  from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 8,  to_step => 9,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 9,  to_step => 10, from_key => 'bam_recalibration_files', to_key => 'bam_recalibration_files' },
            { from_step => 7,  to_step => 10, from_key => 'fixmate_bam_files', to_key => 'bam_files' },
            { from_step => 8,  to_step => 10,  from_key => 'bai_files', to_key => 'bai_files' },
            { from_step => 10, to_step => 11, from_key => 'recalibrated_bam_files', to_key => 'bam_files' },
        );
    }
    
    method behaviour_definitions {
       (
            { after_step => 5, behaviour => 'delete_inputs',  act_on_steps => [0], regulated_by => 'delete_input_bams', default_regulation => 0 },
            { after_step => 5, behaviour => 'delete_outputs', act_on_steps => [3], regulated_by => 'delete_input_bams', default_regulation => 0 },
            { after_step => 8, behaviour => 'delete_outputs', act_on_steps => [5, 6], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 10, behaviour => 'delete_outputs', act_on_steps => [7, 8, 9], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 11, behaviour => 'delete_outputs', act_on_steps => [10], regulated_by => 'cleanup', default_regulation => 1 },
        );
    }
}

1;
