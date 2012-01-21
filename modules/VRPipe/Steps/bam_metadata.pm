use VRPipe::Base;

class VRPipe::Steps::bam_metadata extends VRPipe::Steps::bamcheck {
    method body_sub {
        return sub {
            my $self = shift;
            use VRPipe::Steps::bamcheck;
            
            my $options = $self->options;
            my $bamcheck_exe = $options->{bamcheck_exe};
            my $opts = VRPipe::Steps::bamcheck->get_bamcheck_options($options);
            my @meta_to_check = (qw(bases reads avg_read_length));
            if ($opts && $opts =~ /-d/) {
                push(@meta_to_check, qw(rmdup_reads rmdup_reads_mapped rmdup_bases_mapped_c rmdup_bases rmdup_bases_trimmed));
            }
            
            my $req = $self->new_requirements(memory => 500, time => 1);
            foreach my $bam_file (@{$self->inputs->{bam_files}}) {
                # our output file is our input file
                my $ifile = $bam_file->path;
                $self->output_file(output_key => 'bam_files_with_metadata', output_dir => $ifile->dir, basename => $ifile->basename, type => 'bam');
                
                # run bamcheck if we don't have enough metadata
                my $meta = $bam_file->metadata;
                my $meta_count = 0;
                foreach my $type (@meta_to_check) {
                    $meta_count++ if $meta->{$type};
                }
                unless ($meta_count == @meta_to_check) {
                    my $check_file = $self->output_file(output_key => 'bamcheck_files', basename => $ifile->basename.'.bamcheck', type => 'txt', temporary => 1);
                    my $ofile = $check_file->path;
                    $self->dispatch_wrapped_cmd('VRPipe::Steps::bamcheck', 'stats_from_bamcheck', ["$bamcheck_exe $opts $ifile > $ofile", $req, {output_files => [$check_file]}]);
                }
            }
        };
    }
    method outputs_definition {
        return { bam_files_with_metadata => VRPipe::StepIODefinition->get(type => 'bam',
                                                                          description => 'a bam file with associated metadata',
                                                                          max_files => -1,
                                                                          metadata => {lane => 'lane name (a unique identifer for this sequencing run, aka read group)',
                                                                                       bases => 'total number of base pairs',
                                                                                       reads => 'total number of reads (sequences)',
                                                                                       forward_reads => 'number of forward reads',
                                                                                       reverse_reads => 'number of reverse reads',
                                                                                       avg_read_length => 'the average length of reads',
                                                                                       paired => '0=single ended reads only; 1=paired end reads present',
                                                                                       insert_size => 'average insert size (0 if unpaired)',
                                                                                       library => 'library name',
                                                                                       sample => 'sample name',
                                                                                       center_name => 'center name',
                                                                                       platform => 'sequencing platform, eg. ILLUMINA|LS454|ABI_SOLID',
                                                                                       study => 'name of the study, put in the DS field of the RG header line',
                                                                                       optional => ['library', 'sample', 'center_name', 'platform', 'study', 'insert_size']}) };
    }
    method description {
        return "Takes a bam file and associates metadata with the file in the VRPipe database, making the bam file usable in other bam-related Steps";
    }
}

1;
