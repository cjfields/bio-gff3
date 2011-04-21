package Bio::GFF3::Transform::FromFasta;
# ABSTRACT: make gff3 for the sequences in a fasta file

use strict;
use warnings FATAL => 'all';
use Carp;
use Scalar::Util 'blessed';

use base 'Exporter';
our @EXPORT_OK = ( 'gff3_from_fasta' );

use Bio::GFF3::LowLevel 'gff3_format_feature';

=head1 SYNOPSIS

  use Bio::GFF3::Transform::FromFasta 'gff3_from_fasta';

  gff3_from_fasta(
    in            => [ 'file1', $filehandle, ... ],
    out           => \*STDOUT,
    type          => 'contig',
    fasta_section => 1,
    source        => 'MyAnalysis',
  );

=func  gff3_from_fasta( in => \@files_or_fhs, out => $fh, type => 'SO_type' )

=head3 Arguments

=over 4

=item in

  in   => \@files_or_fhs

Arrayref of filenames or filehandles containing FASTA.

=item out

  out  => $file,

Filename or filehandle to write GFF3 to.

=item type

  type => 'SO_type',

String Sequence Ontology term name for the features being made.

=item source

  source => 'fasta',

Source name to put in the gff3.  Default 'fasta'.

=item fasta_section

  fasta_section => 0,

Default off. if true, write the actual sequencesh '##FASTA' section.

=back

=cut

sub gff3_from_fasta {
    my %args = @_;
    $args{out} or croak 'must provide "out" arg';

    $args{in} or croak 'must provide "in" arg';
    $args{in} = [ $args{in} ] unless ref $args{in} eq 'ARRAY';
    $args{type} or croak( 'must provide "type" arg');

    my $out_fh = _to_filehandle($args{out},'>');

    my @fhs =
        map _to_filehandle($_),
        @{ $args{in} };

    print $out_fh "##gff-version 3\n";
    for my $fh ( @fhs ) {
        _for_fasta( $fh, sub {
            my ( $ident, $desc, $seq ) = @_;

            print $out_fh gff3_format_feature({
                seq_id => $$ident,
                source => $args{source} || 'fasta',
                type   => $args{type},
                start  => 1,
                end    => length($$seq),
                strand => '+',
                attributes => {
                    Name => [ $$ident ],
                    ( $$desc ? (Note => [ $$desc ]) : () ),
                  },
              });
        });
    }

    if( $args{fasta_section} ) {
        seek( $_, 0, 0 ) for @fhs;
        print $out_fh "##FASTA\n";
        local $_;
        for my $fh (@fhs) {
            while( <$fh> ) {
                chomp;
                s/\s//g unless /^>/;
                print $out_fh $_,"\n";
            }
        }
    }
}

sub _for_fasta {
    my ( $fh, $cb ) = @_;

    local $/ = "\n>";
    while( my $seq = <$fh> ) {
        $seq =~ s/\s*>?\s*//;
        $seq =~ s/^(\S+) *(.*)//
            or croak 'error parsing fasta';
        my ( $ident, $desc ) = ( $1, $2 );
        $seq =~ s/\s//g;
        $cb->( \$ident, \$desc, \$seq );
    }

}

sub _to_filehandle {
    my ( $thing, $mode ) = @_;
    return $thing if
        ref $thing
        && (    ref $thing eq 'GLOB'
             || blessed $thing && $thing->can('print')
           );

    open( my $f, ($mode || '<'), $thing) or die "$! opening $thing";
    return $f;
}

1;