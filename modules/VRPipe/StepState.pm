use VRPipe::Base;

class VRPipe::StepState extends VRPipe::Persistent {
    has 'stepmember' => (is => 'rw',
                         isa => Persistent,
                         coerce => 1,
                         traits => ['VRPipe::Persistent::Attributes'],
                         is_key => 1,
                         belongs_to => 'VRPipe::StepMember');
    
    has 'dataelement' => (is => 'rw',
                          isa => Persistent,
                          coerce => 1,
                          traits => ['VRPipe::Persistent::Attributes'],
                          is_key => 1,
                          belongs_to => 'VRPipe::DataElement');
    
    has 'pipelinesetup' => (is => 'rw',
                            isa => Persistent,
                            coerce => 1,
                            traits => ['VRPipe::Persistent::Attributes'],
                            is_key => 1,
                            belongs_to => 'VRPipe::PipelineSetup');
    
    has 'cmd_summary' => (is => 'rw',
                          isa => Persistent,
                          coerce => 1,
                          traits => ['VRPipe::Persistent::Attributes'],
                          is_nullable => 1,
                          belongs_to => 'VRPipe::StepCmdSummary');
    
    has 'complete' => (is => 'rw',
                       isa => 'Bool',
                       traits => ['VRPipe::Persistent::Attributes'],
                       default => 0);
    
    __PACKAGE__->make_persistent(has_many => [[submissions => 'VRPipe::Submission'],
                                              ['_output_files' => 'VRPipe::StepOutputFile']]);
    
    method output_files (PersistentFileHashRef $new_hash?) {
        my @current_ofiles = $self->_output_files;
        my %hash;
        foreach my $sof (@current_ofiles) {
            next if $sof->output_key eq 'temp';
            push(@{$hash{$sof->output_key}}, $sof->file);
        }
        
        if ($new_hash) {
            # forget output files we no longer have
            while (my ($key, $files) = each %hash) {
                my @current_file_ids = map { $_->id } @$files;
                my @files_to_forget;
                if (exists $new_hash->{$key}) {
                    my %new_file_ids = map { $_->id => 1 } @{$new_hash->{$key}};
                    foreach my $id (@current_file_ids) {
                        unless (exists $new_file_ids{$id}) {
                            push(@files_to_forget, $id);
                        }
                    }
                }
                else {
                    @files_to_forget = @current_file_ids;
                }
                
                foreach my $file_id (@files_to_forget) {
                    VRPipe::StepOutputFile->get(stepstate => $self, file => $file_id, output_key => $key)->delete;
                }
            }
            
            # remember new ones
            delete $new_hash->{temp};
            while (my ($key, $files) = each %$new_hash) {
                foreach my $file (@$files) {
                    VRPipe::StepOutputFile->get(stepstate => $self, file => $file, output_key => $key);
                }
            }
            
            return $new_hash;
        }
        else {
            return \%hash;
        }
    }
    
    method temp_files (ArrayRefOfPersistent $new_array?) {
        my $schema = $self->result_source->schema;
        my $rs = $schema->resultset('StepOutputFile')->search({ stepstate => $self->id, output_key => 'temp' });
        my @array;
        while (my $sof = $rs->next) {
            push(@array, $sof->file);
        }
        
        if ($new_array) {
            # forget temp files we no longer have
            my %new_file_ids = map { $_->id => 1 } @$new_array;
            foreach my $file (@array) {
                unless (exists $new_file_ids{$file->id}) {
                    VRPipe::StepOutputFile->get(stepstate => $self, file => $file, output_key => 'temp')->delete;
                }
            }
            
            # remember new ones
            foreach my $file (@$new_array) {
                VRPipe::StepOutputFile->get(stepstate => $self, file => $file, output_key => 'temp');
            }
            
            return $new_array;
        }
        else {
            return \@array;
        }
        
    }
    
    method output_files_list {
        my $outputs = $self->output_files;
        my @files;
        if ($outputs) {
            foreach my $val (values %$outputs) {
                push(@files, @$val);
            }
        }
        return @files;
    }
    
    method update_output_file_stats {
        foreach my $file ($self->output_files_list) {
            $file->update_stats_from_disc(retries => 3);
        }
    }
    
    method unlink_output_files {
        foreach my $file ($self->output_files_list) {
            $file->unlink;
        }
    }
    
    method unlink_temp_files {
        foreach my $vrfile (@{$self->temp_files}) {
            $vrfile->unlink;
        }
    }
    
    method start_over {
        # first reset all associated submissions in order to reset their jobs
        my @sub_ids;
        foreach my $sub ($self->submissions) {
            push(@sub_ids, $sub->id);
            $sub->start_over;
            $sub->delete;
        }
        
        # now reset self
        $self->unlink_output_files;
        $self->complete(0);
        $self->update;
    }
}

1;