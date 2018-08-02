package Git::Contributors;

use strict;
use warnings;

use Git::Wrapper;
use List::AllUtils qw/ pairmap pairgrep pairs sum /;
use List::UtilsBy qw/ partition_by /;

use DDP;

use MooseX::App::Simple;

use 5.20.0;
use experimental  'signatures', 'postderef';

parameter 'repo_dir',
    is => 'ro';

use MooseX::MungeHas {
    'has_ro' => [ 'is_ro' ],
};

has_ro git => sub {
    Git::Wrapper->new($_[0]->repo_dir);
};

has_ro files => sub { +{} };


#my %files = map { $_ => blame_file( $_ ) } @files;

sub List::Util::_Pair::_data_printer {
    require Data::Printer::Filter;

    my ($self, $properties) = @_;

    sprintf "List::Util::_Pair { %s => %s }", $self->key, $self->value;
}

option version => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub($self) {
        [ grep { /^v\d/ } $self->git->tag({ sort => 'version:refname' }) ]
    }
);

sub run($self) {

    # p %authors;

    # get all the versions, in right order
    # for all versions, get the master merge-base
    # get the contributors

    my @versions = map {
        p $self->process_version($_)
    } $self->version->@*;

    use JSON 'to_json';

    say to_json \@versions, { canonical => 1, pretty => 1 };
}

option work_branch => (
    is => 'ro',
    isa => 'Str',
    lazy =>  1,
    default => sub { 'master' },
);

has previous_version_commit => (
    is => 'rw',
);

sub process_version($self,$version) {
    my( $commit )= $self->git->merge_base( $version, $self->work_branch );

    # TODO add date
    my( $date ) = [ $self->git->RUN( 'log', $commit,  {1 => 1, pretty => '%aI'} ) ]->[0];
    $date =~ s/T.*//;

    my $data = $self->populate_version($commit);

    return {
        version      => $version,
        date         => $date,
        %$data,

        contributors => $self->aggregate_contributors,
    };

}

before populate_version => sub($self,$commit){
    return unless $self->previous_version_commit;

    my @files = $self->git->diff( { 'name-only' => 1 }, $self->previous_version_commit, $commit );

    delete $self->{files}->@{ @files };

};

after populate_version => sub($self,$commit){
    $self->previous_version_commit($commit);
};

sub aggregate_contributors($self) {
    +[ pairmap {
            +{ id => $a, 
                lines => sum map { @$_ } @$b
            }
    } partition_by { shift @$_ } map { pairs %$_ } values $self->files->%* ];
}

sub churn ($self,$commit,$previous = '4b825dc642cb6eb9a060e54bf8d69288fbee4904' ) {
    $previous ||= '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
    my %churn = ( added => 0, removed => 0 );
    for ( $self->git->diff( $previous, $commit ) ) {
        next unless /^([+-])(?!=-)/;
        $churn{ $1 eq '+' ? 'added' : 'removed' }++;
    }

    return \%churn;
}

sub populate_version($self,$commit) {
    my @files = $self->git->ls_tree( $commit => { r => 1, 'name-only' => 1 } );

    my $total = @files;

    @files = grep { !$self->files->{$_} } @files;

    $self->populate_file( $commit, $_ ) for @files;

    my $churn = $self->churn(
        $commit,
        $self->previous_version_commit 
    );

    return {
		files => { total => $total, modified => scalar @files },
        churn          => $churn,
    };


}

sub populate_file($self,$commit,$file) {
    $self->files->{$file} = $self->blame_file($commit,$file);
}


sub blame_file($self,$commit,$file) {
    my %authors;
    for ( $self->git->blame( {'show-email' => 1}, $commit, '--', $file  ) ) {
        /<([^>]+)/ or next;
        $authors{$1}++;
    }
    return \%authors;
}


__PACKAGE__->new_with_options->run;
