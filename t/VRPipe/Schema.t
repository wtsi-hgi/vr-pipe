#!/usr/bin/env perl
use strict;
use warnings;
use Path::Class;

BEGIN {
    use Test::Most tests => 88;
    use VRPipeTest;
    use_ok('VRPipe::Schema');
    use_ok('VRPipe::File');
}

ok my $schema = VRPipe::Schema->create('VRTrack'), 'able to create a schema instance';
ok my $graph = $schema->graph(), 'graph() method worked';
isa_ok($graph, 'VRPipe::Persistent::Graph');

ok my $sample = $schema->add('Sample', { name => 's1' }), 'add() method worked';
my $orig_sample_id = $sample->node_id();
$sample = $schema->add('Sample', { name => 's1', public_name => 'public_sone' });
is_deeply [$sample->{id}, $sample->{properties}], [$orig_sample_id, { name => 's1', public_name => 'public_sone' }], 'add() twice on the same unique property does an update with labels that keep their history';
$sample = $schema->add('Sample', { name => 's1', public_name => 'public_s1' });
is_deeply [$sample->{id}, $sample->{properties}, $sample->changed()], [$orig_sample_id, { name => 's1', public_name => 'public_s1' }, { public_name => ['public_sone', 'public_s1'] }], 'add() again on the same unique property with a changed property does really update it, and we can find out what the previous value was';

# Sample is marked to store history but EBI_Submission is not, so repeat some of
# the above tests to cover both code paths
my $ebisub = $schema->add('EBI_Submission', { acc => 'ebi1', sub_date => 12345 });
my $orig_ebi_id = $ebisub->node_id();
$ebisub = $schema->add('EBI_Submission', { acc => 'ebi1', sub_date => 67890 });
is_deeply [$ebisub->{id}, $ebisub->{properties}, $ebisub->changed()], [$orig_ebi_id, { acc => 'ebi1', sub_date => 67890 }], 'add() twice on the same unique property with different other properties does an update on a history-less label';

ok my @libs = $schema->add('Library', [{ id => 'l1' }, { id => 'l2' }], incoming => { type => 'prepared', node => $sample }), 'add() worked with incoming option, and for adding more than 1 at a time';

throws_ok { $schema->add('Foo', { foo => 'bar' }) } qr/'Foo' isn't a valid label for schema VRTrack/, 'add() throws when given an invalid label';
throws_ok { $schema->add('Sample', { id => '1' }) } qr/Parameter 'name' must be supplied/, 'add() throws when not given a required parameter';
throws_ok { $schema->add('Sample', { name => 's2', foo => 'bar' }) } qr/Property 'foo' supplied, but that isn't defined in the schema for VRTrack::Sample/, 'add() throws when given an invalid parameter';
my $bs_date = time();
ok my $bs = $schema->add('Bam_Stats', { uuid => 'uuid', mode => 'mode', options => 'opts', 'raw total sequences' => 100, foo => 'bar', date => $bs_date }), 'arbitrary parameters can be supplied to a label defined with allow_anything => 1';
ok $bs->add_properties({ cat => 'banana' }), 'add_properties() also worked with an arbitrary parameter';
is_deeply $bs->{properties}, { uuid => 'uuid', mode => 'mode', options => 'opts', 'raw total sequences' => 100, foo => 'bar', cat => 'banana', date => $bs_date }, 'We really do store whatever on a allow_anything label';

ok my $lib1 = $schema->get('Library', { id => 'l1' }), 'get() method worked';
ok @libs = $schema->get('Library'), 'get() method worked with no properties arg';

$schema->add('Library', { id => 'l3' });
my $lib3 = $schema->get('Library', { id => 'l3' });
is $lib3->{properties}->{id}, 'l3', 'really added a library to the database';
$schema->delete($lib3);
$lib3 = $schema->get('Library', { id => 'l3' });
is $lib3, undef, 'delete() worked';

isa_ok($lib1, 'VRPipe::Schema::VRTrack::Library');
is $lib1->id, 'l1', 'auto-generated property method worked to get';
$lib1->name('libone');
is $lib1->name, 'libone', 'auto-generated property method worked to set';
$lib1 = $schema->get('Library', { id => 'l1' });
is $lib1->name, 'libone', 'the set was really in the database';

is_deeply $lib1->properties(flatten_parents => 1), { id => 'l1', name => 'libone', sample_name => 's1', sample_public_name => 'public_s1' }, 'properties() method worked with flatten_parents';
$lib1->add_properties({ name => 'lib1', tag => 'ATG' });
$lib1 = $schema->get('Library', { id => 'l1' });
is_deeply $lib1->properties(), { id => 'l1', name => 'lib1', tag => 'ATG' }, 'add_properties() method worked';
is $lib1->parent_property('sample_name'), 's1', 'parent_property() worked';

throws_ok { $sample->add_properties({ foo  => 'bar' }) } qr/Property 'foo' supplied, but that isn't defined in the schema for VRTrack::Sample/,           'add_properties() throws when given an invalid property';
throws_ok { $sample->add_properties({ name => 'bar' }) } qr/Property 'name' supplied, but that's unique for schema VRTrack::Sample and can't be changed/, 'add_properties() throws when given a unique property';
$sample->add_properties({ public_name => 'pn1', supplier_name => 'sn1', accession => 'acc1' });
is_deeply [$sample->properties(), $sample->changed()], [{ name => 's1', public_name => 'pn1', supplier_name => 'sn1', accession => 'acc1' }, { public_name => ['public_s1', 'pn1'], supplier_name => [undef, 'sn1'], accession => [undef, 'acc1'] }], 'add_properties() method worked and let us see what changed';
$sample->add_properties({ public_name => 'pn1', supplier_name => 'sup1' }, replace => 1);
is_deeply [$sample->properties(), $sample->changed()], [{ name => 's1', public_name => 'pn1', supplier_name => 'sup1' }, { supplier_name => ['sn1', 'sup1'], accession => ['acc1', undef] }], 'add_properties(replace => 1) method worked and let us see what changed';
$sample->add_properties({ public_name => 'pn1', supplier_name => 'sup1' });
is_deeply [$sample->properties(), $sample->changed()], [{ name => 's1', public_name => 'pn1', supplier_name => 'sup1' }], 'add_properties() with only old properties changes nothing';
throws_ok { $sample->name('bar') } qr/Property 'name' is unique for schema VRTrack::Sample and can't be changed/, 'property method name() throws when given a value to set';
is $sample->name(), 's1', 'but name() to get works fine';
$sample->supplier_name('supn1');
is_deeply [$sample->supplier_name(), $sample->properties(), $sample->changed()], ['supn1', { name => 's1', public_name => 'pn1', supplier_name => 'supn1' }, { supplier_name => ['sup1', 'supn1'] }], 'setting a property with the dynamically created method works and can tell us what we changed';

# test history
$sample = $schema->get('Sample', { name => 's1' });
my @history        = $sample->property_history();
my $timestamps_ok  = 0;
my $prev_timestamp = time();
my @history_properties;
foreach my $hist (@history) {
    my $timestamp = $hist->{timestamp};
    if ($timestamp <= $prev_timestamp) {
        $timestamps_ok++;
    }
    $prev_timestamp = $timestamp;
    
    push(@history_properties, $hist->{properties});
}
is_deeply [$timestamps_ok, @history_properties], [5, { public_name => 'pn1', supplier_name => 'supn1' }, { public_name => 'pn1', supplier_name => 'sup1' }, { public_name => 'pn1', supplier_name => 'sn1', accession => 'acc1' }, { public_name => 'public_s1' }, { public_name => 'public_sone' }], 'sample_property_history() gives us the complete history of properties over time';

# test its ok to set null values
$sample = $schema->add('Sample', { name => 's1', created_date => undef });
is_deeply [$sample->{id}, $sample->{properties}], [$orig_sample_id, { name => 's1', public_name => 'pn1', supplier_name => 'supn1' }], 'add() with null values for properties does not add those properties';
$sample = $schema->add('Sample', { name => 's1', created_date => 12 });
$sample = $schema->add('Sample', { name => 's1', created_date => undef });
is_deeply [$sample->{id}, $sample->{properties}], [$orig_sample_id, { name => 's1', public_name => 'pn1', supplier_name => 'supn1', created_date => 12 }], 'add() with null values for properties does not unset previously set properties';
# also check it works on allow_anything labels
my $fooless_bs = $schema->add('Bam_Stats', { uuid => 'uuid2', mode => 'mode', options => 'opts', 'raw total sequences' => 100, foo => undef, date => $bs_date });
is_deeply $fooless_bs->{properties}, { uuid => 'uuid2', mode => 'mode', options => 'opts', 'raw total sequences' => 100, date => $bs_date }, 'add() with null values for properties does not add those properties for an allow_anything label';

# test that we can get the latest data if another process updates a property
is $lib1->tag, 'ATG', 'tag starts out as ATG';
my $pid = fork;
if (defined $pid && $pid == 0) {
    $lib1->tag('ATGC');
    exit;
}
waitpid($pid, 0);
is $lib1->tag, 'ATG', 'tag still seems to be ATG after another process changed it';
$lib1->update_from_db;
is $lib1->tag, 'ATGC', 'tag is correct after using update_from_db()';

my @related = $lib1->related();
is_deeply [sort map { $_->node_id } @related], [$sample->node_id], 'related() worked';
$lib3 = $schema->add('Library', { id => 'l3' });
@related = $lib3->related();
is_deeply [sort map { $_->node_id } @related], [], 'related() returned nothing for a node with no relations';
$sample->relate_to($lib3, 'prepared');
@related = $lib3->related();
is_deeply [sort map { $_->node_id } @related], [$sample->node_id], 'relate_to() worked';
is $related[0]->name, 's1', 'related() returns working objects';
my $lane1 = $schema->add('Lane', { unique => 'lane1', lane => 1 });
$lib3->relate_to($lane1, 'sequenced');
@related = $lane1->related(incoming => {});
is_deeply [sort map { $_->node_id } @related], [$lib3->node_id], 'related() worked with incoming specified';
$lib1->relate_to($lane1, 'sequenced', selfish => 1);
@related = $lane1->related(incoming => {});
is_deeply [sort map { $_->node_id } @related], [$lib1->node_id], 'relate_to(selfish => 1) worked';

# make sure we delete history nodes when we delete a schema node
$lib3->tag('A');
$lib3->tag('ATGC');
@related = $graph->related_nodes($lib3, outgoing => { max_depth => 500 }, return_history_nodes => 1);
is scalar(@related), 4, 'lib3 has 4 history nodes';
$schema->delete($lib3);
my $still_exist = 0;
foreach my $node (@related) {
    $still_exist++ if $graph->get_node_by_id($node->{id});
}
is $still_exist, 1, 'after deleting lib3, all the history nodes were also deleted, except for one used by another node';

# test Graph pass-through methods create_uuid() and date_to_epoch()
my $uuid = $schema->create_uuid();
like $uuid, qr/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/, 'create_uuid() worked';
is $schema->date_to_epoch('2013-05-10 06:45:32'), 1368168332, 'date_to_epoch() worked';

# unique uuid properties auto-fill if not supplied
ok my $bam_stats = $schema->add('Bam_Stats', { mode => 'normal', options => '-foo', 'raw total sequences' => 100, date => $bs_date }), 'could add a new node without supplying its unique value when the unique is a uuid';
like $bam_stats->uuid, qr/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/, 'the resulting node has a uuid';
is $bam_stats->raw_total_sequences(), 100, 'we can call a property method that has spaces in the name';

# test the VRTrack-specific ensure_sequencing_hierarchy method
ok my $hierarchy = $schema->ensure_sequencing_hierarchy(lane => 'esh_lane1', library => 'esh_library1', sample => 'esh_sample1', study => 'esh_study1', group => 'esh_group1', taxon => 'esh_taxon1'), 'ensure_sequencing_hierarchy() worked';
ok my $eshlane = $schema->get('Lane', { unique => 'esh_lane1' }), 'ensure_sequencing_hierarchy() created a Lane';
my $eshlib = $schema->get('Library', { id   => 'esh_library1' });
my $eshsam = $schema->get('Sample',  { name => 'esh_sample1' });
my $eshstu = $schema->get('Study',   { id   => 'esh_study1' });
my $eshgro = $schema->get('Group',   { name => 'esh_group1' });
my $eshtax = $schema->get('Taxon',   { id   => 'esh_taxon1' });
my %hierarchy_props = map { $_ => $hierarchy->{$_}->properties } keys %{$hierarchy};
is_deeply [\%hierarchy_props, [sort { $a <=> $b } map { $_->node_id } $eshlane->related(incoming => { max_depth => 10 })]], [{ lane => { unique => 'esh_lane1', lane => 'esh_lane1' }, library => { id => 'esh_library1' }, sample => { name => 'esh_sample1' }, study => { id => 'esh_study1' }, group => { name => 'esh_group1' }, taxon => { id => 'esh_taxon1' } }, [$eshlib->node_id, $eshsam->node_id, $eshstu->node_id, $eshgro->node_id, $eshtax->node_id]], 'ensure_sequencing_hierarchy() created the whole hierarchy correctly with expected properties';
$schema->ensure_sequencing_hierarchy(lane => 'esh_lane1', library => 'esh_library1', sample => 'esh_sample2', study => 'esh_study1', group => 'esh_group1', taxon => 'esh_taxon1');
is_deeply [sort { $a <=> $b } map { $_->node_id } $eshlane->related(incoming => { max_depth => 10 })], [$eshlib->node_id, $eshsam->node_id, $eshstu->node_id, $eshgro->node_id, $eshtax->node_id], 'ensure_sequencing_hierarchy() did not change anything when a different sample was supplied';
my $eshsam2 = $schema->get('Sample', { name => 'esh_sample2' });
is $eshsam2, undef, 'and the new sample was not created';
$schema->ensure_sequencing_hierarchy(lane => 'esh_lane1', library => 'esh_library1', sample => 'esh_sample2', study => 'esh_study1', group => 'esh_group1', taxon => 'esh_taxon1', enforce => 1);
$eshsam2 = $schema->get('Sample', { name => 'esh_sample2' });
is_deeply [sort { $a <=> $b } map { $_->node_id } $eshlane->related(incoming => { max_depth => 10 })], [$eshlib->node_id, $eshstu->node_id, $eshgro->node_id, $eshtax->node_id, $eshsam2->node_id], 'ensure_sequencing_hierarchy(enforce => 1) DID change the hierarchy when a different sample was supplied';

# test some VRPipe-specific things
my $vrpipe = VRPipe::Schema->create('VRPipe');
my @paths  = ('/foo/a/cat.txt', '/foo/b/cat.txt', '/foo/a/dog.txt');
my @files  = $vrpipe->get_or_store_filesystem_paths(\@paths);
my %got    = map { $vrpipe->filesystemelement_to_path($_) => 1 } @files;
is_deeply \%got, { '/foo/a/cat.txt' => 1, '/foo/b/cat.txt' => 1, '/foo/a/dog.txt' => 1 }, 'get_or_store_file_paths() and file_to_path() worked correctly';
my $dog_uuid = $files[2]->uuid;
my $llama = $vrpipe->move_filesystemelement($files[2], '/foo/b/llama.txt');
is_deeply [$llama->uuid, $vrpipe->filesystemelement_to_path($llama)], [$dog_uuid, '/foo/b/llama.txt'], 'move_filesystemelement() worked';
$vrpipe->move_filesystemelement('/foo/b', '/foo/a/b');
my $bcat = $vrpipe->get('FileSystemElement', { uuid => $files[1]->uuid });
is $vrpipe->filesystemelement_to_path($bcat), '/foo/a/b/cat.txt', 'move_filesystemelement() can be used to move directories, and it also moves all contained files';
ok my $file = $vrpipe->add('File', { path => '/bar/horse.txt' }), 'adding File is possible';
isa_ok($file, 'VRPipe::Schema::VRPipe::FileSystemElement');
is $file->basename, 'horse.txt', 'File, which is actually a FileSystemElement, has the correct basename';
ok my $gotten_file = $vrpipe->get('File', { path => '/bar/horse.txt' }), 'getting a File is possible';
is $gotten_file->node_id, $file->node_id, 'gotten and added filesystemelement nodes match';
is $vrpipe->get('File', { path => '/bar/horse' }), undef, 'getting a non-existing file does not create it in db';
is $gotten_file->path, '/bar/horse.txt', 'there is a working path method on FileSystemElements';
ok my $new_location = $gotten_file->move('/zar/horse.txt'), 'there is also a working move method';
is_deeply [$new_location->node_id, $new_location->path], [$gotten_file->node_id, '/zar/horse.txt'], 'the move worked correctly';
my $tmp_dir     = $vrpipe->tempdir();
my $source_path = file($tmp_dir, 'source')->stringify;
my $vrfile      = VRPipe::File->create(path => $source_path);
my $fh          = $vrfile->openw;
print $fh "source\n";
$vrfile->close;
my $sym_path   = file($tmp_dir, 'sym')->stringify;
my $cp_path    = file($tmp_dir, 'copy')->stringify;
my $symcp_path = file($tmp_dir, 'symcopy')->stringify;
my $graph_file = $vrpipe->path_to_filesystemelement($source_path);
my $vrsym = VRPipe::File->create(path => $sym_path);
ok $vrfile->symlink($vrsym), 'created a symlink of a file';
ok $vrfile->copy(VRPipe::File->create(path => $cp_path)), 'created a copy of a file';
ok $vrsym->copy(VRPipe::File->create(path => $symcp_path)), 'created a copy of a symlink';
@related = $graph_file->related(outgoing => { max_depth => 2, namespace => 'VRPipe', label => 'FileSystemElement', type => 'symlink|copy' });
my %expected = map { $_->path => 1 } @related;
is_deeply \%expected, { $sym_path => 1, $cp_path => 1, $symcp_path => 1 }, 'there are corresponding nodes in the graph related to the source filesystemelement node';
is $vrpipe->parent_filesystemelement($sym_path)->node_id,   $graph_file->node_id, 'parent_filesystemelement() worked on a symlink path';
is $vrpipe->parent_filesystemelement($cp_path)->node_id,    $graph_file->node_id, 'parent_filesystemelement() worked on a copy path';
is $vrpipe->parent_filesystemelement($symcp_path)->node_id, $graph_file->node_id, 'parent_filesystemelement() worked on a symlink copy path';
my $tmp_sub_dir = dir($tmp_dir, 'sub');
$vrpipe->make_path($tmp_sub_dir);
my $mv_path = file($tmp_sub_dir, 'move')->stringify;
ok $vrfile->move(VRPipe::File->create(path => $mv_path)), 'moved a file';
is_deeply [$vrpipe->parent_filesystemelement($sym_path)->node_id, $vrpipe->parent_filesystemelement($cp_path)->node_id, $vrpipe->parent_filesystemelement($symcp_path)->node_id, $vrpipe->parent_filesystemelement($sym_path)->path, $graph_file->path], [$graph_file->node_id, $graph_file->node_id, $graph_file->node_id, $mv_path, $mv_path], 'after moving the source file the graph of source and symlink and copy is still correct';

# make a traditional mysql vrpipe StepState so we can test that
# ensure_state_hierarchy() can represent the same thing in the graph database
my $pipeline = VRPipe::Pipeline->create(name => 'test_pipeline');
my $datasource = VRPipe::DataSource->create(type => 'fofn_with_metadata', method => 'grouped_by_metadata', options => { metadata_keys => 'study|sample' }, source => file(qw(t data datasource.fofn_with_metadata))->absolute);
my $setup = VRPipe::PipelineSetup->create(name => 'ps1', datasource => $datasource, output_root => '/tmp/out', pipeline => $pipeline, active => 0);
$datasource->elements;
my $ss1 = VRPipe::StepState->create(dataelement => 1, pipelinesetup => 1, stepmember => 1);
my $ss2 = VRPipe::StepState->create(dataelement => 2, pipelinesetup => 1, stepmember => 1);
ok my $graph_ss = $vrpipe->ensure_state_hierarchy($ss1), 'ensure_state_hierarchy() worked';
$graph_ss = $vrpipe->ensure_state_hierarchy($ss2);
ok $graph_ss = $vrpipe->ensure_state_hierarchy($ss2), 'ensure_state_hierarchy() worked twice on the same StepState';
ok my $ps = $vrpipe->get('PipelineSetup', { name => 'ps1' }), 'a PipelineSetup was created in the graph database';
@related = $ps->related(outgoing => { max_depth => 500 });
is scalar(@related), 21, 'all the related nodes were also created';
#*** more detailed, specific tests to make sure the graph is correct? checked visually it's fine...

# test VRTrack schema's add_file method, which passes through to VRPipe schema
ok my $vrtrack_file = $schema->add_file('/bar/snake.txt'), 'add_file() method on the VRTrack schema worked';
is $vrtrack_file->path, '/bar/snake.txt', 'the path() method worked on what that returned';

exit;