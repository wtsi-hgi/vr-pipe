
=head1 NAME

VRPipe::Steps::gatk_combine_gvcfs - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk> and Yasin Memari <ym3@sanger.ac.uk>.

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

# java -Xmx2g -jar GenomeAnalysisTK.jar \
#   -R ref.fasta \
#   -T CombineGVCFs \
#   --variant gvcf1.vcf \
#   --variant gvcf2.vcf \
#   -o mergeGvcf.vcf

class VRPipe::Steps::gatk_combine_gvcfs extends VRPipe::Steps::gatk_v2 {
    around options_definition {
        return {
            %{ $self->$orig }, # gatk options
            combine_gvcfs_options    => VRPipe::StepOption->create(description => 'Options for GATK CombineGVCFs, excluding -R,-V,-o', optional      => 1),
            maximum_gvcfs_to_combine => VRPipe::StepOption->create(description => 'The maximum gVCFs to combine at once',              default_value => 200),
        };
    }
    
    method inputs_definition {
        return {
            gvcf_files       => VRPipe::StepIODefinition->create(type => 'vcf', max_files => -1, description => '1 or more gvcf files'),
            gvcf_index_files => VRPipe::StepIODefinition->create(type => 'bin', max_files => -1, description => 'index files for the input gvcf files'),
        };
    }
    
    method body_sub {
        return sub {
            my $self     = shift;
            my $vcf_meta = $self->common_metadata($self->inputs->{gvcf_files});
            $vcf_meta = { %$vcf_meta, $self->element_meta };
            my $options = $self->handle_override_options($vcf_meta);
            $self->handle_standard_options($options);
            
            my $reference_fasta          = $options->{reference_fasta};
            my $combine_gvcfs_opts       = $options->{combine_gvcfs_options} ? $options->{combine_gvcfs_options} : "";
            my $maximum_gvcfs_to_combine = $options->{maximum_gvcfs_to_combine};
            
            if ($combine_gvcfs_opts =~ /$reference_fasta|-V |--variant|-o | --output|CombineGVCFs/) {
                $self->throw("combine_gvcfs_options should not include the reference, input or output options or CombineGVCFs task command");
            }
            
            # if all input files have chrom,from,to metadata, then this is from
            # a genome_chunking step and we should group files with the same
            # values together
            my @input_files = @{ $self->inputs->{gvcf_files} };
            my %region_gvcfs;
            foreach my $input_file (@input_files) {
                my $meta = $input_file->metadata;
                if (defined $$meta{chrom} && defined $$meta{from} && defined $$meta{to}) {
                    my ($chrom, $from, $to) = ($$meta{chrom}, $$meta{from}, $$meta{to});
                    push @{ $region_gvcfs{"$chrom:$from-$to"} }, $input_file;
                }
                else {
                    if (exists $region_gvcfs{all} && defined $$vcf_meta{chrom} && defined $$vcf_meta{from} && defined $$vcf_meta{to}) {
                        my ($chrom, $from, $to) = ($$vcf_meta{chrom}, $$vcf_meta{from}, $$vcf_meta{to});
                        %region_gvcfs = ("$chrom:$from-$to" => [@input_files]);
                    }
                    else {
                        %region_gvcfs = (all => [@input_files]);
                    }
                    last;
                }
            }
            
            my $summary_opts = $combine_gvcfs_opts;
            my $basename     = 'gatk_combineGvcf.vcf.gz';
            unless (exists $region_gvcfs{all}) {
                $summary_opts .= ' -L $region';
            }
            
            $self->set_cmd_summary(
                VRPipe::StepCmdSummary->create(
                    exe     => 'GenomeAnalysisTK',
                    version => $self->gatk_version(),
                    summary => 'java $jvm_args -jar GenomeAnalysisTK.jar -T CombineGVCFs -R $reference_fasta --variant $gvcf1 --variant $gvcf2 [...] -o $out_gvcf ' . $summary_opts
                )
            );
            
            my $req = $self->new_requirements(memory => 6000, time => 1);
            while (my ($region, $region_input_files) = each %region_gvcfs) {
                my $this_combine_gvcfs_opts = $combine_gvcfs_opts;
                my $this_basename           = $basename;
                unless ($region eq 'all') {
                    $this_combine_gvcfs_opts .= " -L $region";
                    my ($chrom, $from, $to) = $region =~ m/^(.+):(\d+)-(\d+)$/;
                    $vcf_meta = { %$vcf_meta, chrom => $chrom, from => $from, to => $to };
                    $this_basename = "$region.$basename";
                    $this_basename =~ s/:/_/;
                }
                my @file_inputs = map { "--variant " . $_->path } @$region_input_files;
                $this_combine_gvcfs_opts .= " @file_inputs";
                
                my $vcf_file  = $self->output_file(output_key => 'combine_gvcf_files', basename => $this_basename, type => 'vcf', metadata => $vcf_meta);
                my $vcf_path  = $vcf_file->path;
                my $vcf_index = $self->output_file(output_key => 'combine_gvcf_index_files', basename => $this_basename . ".tbi", type => 'bin', metadata => $vcf_meta);
                
                my $cmd      = $self->gatk_prefix($req->memory) . qq[ -T CombineGVCFs -R $reference_fasta $this_combine_gvcfs_opts -o $vcf_path];
                my $this_cmd = "use VRPipe::Steps::gatk_combine_gvcfs; VRPipe::Steps::gatk_combine_gvcfs->combine_and_check(q[$cmd]);";
                $self->dispatch_vrpipecode($this_cmd, $req, { output_files => [$vcf_file, $vcf_index] });
            }
        };
    }
    
    method outputs_definition {
        return {
            combine_gvcf_files       => VRPipe::StepIODefinition->create(type => 'vcf', max_files => -1, description => 'combined gvcf files'),
            combine_gvcf_index_files => VRPipe::StepIODefinition->create(type => 'bin', max_files => -1, description => 'index of combined gvcf files'),
        };
    }
    
    method post_process_sub {
        return sub { return 1; };
    }
    
    method description {
        return "Run GATK CombineGVCFs on equal sized batches of input gVCF files produced by the Haplotype Caller, generating one joint VCF file for each batch. Will group input files per-region if chrom/from/to metadata is present";
    }
    
    method max_simultaneous {
        return 0;            # meaning unlimited
    }
    
    method combine_and_check (ClassName|Object $self: Str $cmd_line) {
        my ($input_path, $out_path) = $cmd_line =~ /--variant (\S+) .*? -o (\S+)/;
        $input_path || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        $out_path   || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        
        my $input_file = VRPipe::File->get(path => $input_path);
        my $out_file   = VRPipe::File->get(path => $out_path);
        
        $input_file->disconnect;
        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        return 1;
    }
}

1;
