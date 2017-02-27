use strict;
use warnings;

use Git::Wrapper;

my $git = Git::Wrapper->new('.');

my @files = $git->ls_tree( HEAD => { r => 1, 'name-only' => 1 } );

my %files = map { $_ => blame_file( $_ ) } @files;

use List::AllUtils qw/ pairmap pairgrep pairs sum /;
use List::UtilsBy qw/ partition_by /;

use DDP;

sub List::Util::_Pair::_data_printer {
    require Data::Printer::Filter;

    my ($self, $properties) = @_;

    sprintf "List::Util::_Pair { %s => %s }", $self->key, $self->value;
}


my %authors = pairmap {
    $a => sum map { @$_ } @$b
} partition_by { shift @$_ } map { pairs %$_ } values %files;

p %authors;


use 5.20.0;
use experimental  'signatures';
sub blame_file($file) {
    my %authors;
    for ( $git->blame( 'HEAD', $file, {'show-email' => 1} ) ) {
        /<([^>]+)/ or next;
        $authors{$1}++;
    }
    return \%authors;
}


