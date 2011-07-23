package Querylet::Document;

=head1 NAME

Querylet::Document - represent a parsed Querylet

=head1 SYNOPSIS

    my $q = Querylet::Parser->parse($querylet);

=cut

sub new {
    my ($class, %args) = @_;
    
    bless \%args => $class;
}

sub as_perl {
    my( $self, $target_class ) = @_;
    
    join ";\n",
        map { join "\n", $_->line_comment, $_->as_perl($target_class) } @{ $self->{sections} };
};

=head2 C<< $doc->sections >>

    my @sections = $doc->sections()

List all sections

=cut

sub sections { @{ $_[0]->{sections} } };

=head2 C<< $doc->inputs >>

    my @input_sections = $doc->inputs;

List all parameters declared for this querylet

=cut

sub inputs {
    my( $self ) = @_;
    
    grep { $_->{type} eq 'input' } $self->sections;
};


1;