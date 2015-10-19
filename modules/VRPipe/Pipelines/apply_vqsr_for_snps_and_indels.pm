
=head1 NAME

VRPipe::Pipelines::apply_vqsr_for_snps_and_indels - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2015 Genome Research Limited.

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

class VRPipe::Pipelines::apply_vqsr_for_snps_and_indels with VRPipe::PipelineRole {
    method name {
        return 'apply_vqsr_for_snps_and_indels';
    }
    
    method description {
        return 'Apply VQSR to SNPs and indels.';
    }
    
    method step_names {
        (
            'gatk_apply_recalibration_for_indels', #1
            'gatk_apply_recalibration_for_snps',   #2
            'bcftools_concat',                     #3 make per-chromosome, VQSR applied vcf files
        );
    }
    
    method adaptor_definitions {
        (
            
            { from_step => 0, to_step => 1, to_key   => 'vcf_files' },
            { from_step => 0, to_step => 1, to_key   => 'vcf_index_files' },
            { from_step => 0, to_step => 1, to_key   => 'recalibration_file' },
            { from_step => 0, to_step => 1, to_key   => 'tranches_file' },
            { from_step => 1, to_step => 2, from_key => 'recalibrated_vcf_files', to_key => 'vcf_files' },
            { from_step => 1, to_step => 2, from_key => 'recalibrated_vcf_index_files', to_key => 'vcf_index_files' },
            { from_step => 0, to_step => 2, to_key   => 'recalibration_file' },
            { from_step => 0, to_step => 2, to_key   => 'tranches_file' },
            { from_step => 2, to_step => 3, from_key => 'recalibrated_vcf_files', to_key => 'vcf_files' },
        );
    }
    
    method behaviour_definitions {
        (
            { after_step => 2, behaviour => 'delete_inputs',  act_on_steps => [0], regulated_by => 'remove_input_vcfs', default_regulation => 0 },
            { after_step => 2, behaviour => 'delete_outputs', act_on_steps => [1], regulated_by => 'cleanup',           default_regulation => 1 },
            { after_step => 3, behaviour => 'delete_outputs', act_on_steps => [2], regulated_by => 'cleanup',           default_regulation => 1 },
        );
    }
}

1;
