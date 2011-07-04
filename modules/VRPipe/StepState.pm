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
    
    has 'output_files' => (is => 'rw',
                           isa => PersistentFileHashRef,
                           traits => ['VRPipe::Persistent::Attributes'],
                           default => sub { {} });
    
    has 'complete' => (is => 'rw',
                       isa => 'Bool',
                       traits => ['VRPipe::Persistent::Attributes'],
                       default => 0);
    
    __PACKAGE__->make_persistent(has_many => [submissions => 'VRPipe::Submission']);
}

1;