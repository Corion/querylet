package Querylet::Parser;
use strict;
use Module::Pluggable
    require => 1,
    search_path => 'Querylet::Section',
    sub_name => 'known_sections'
    ;

=head1 NAME

Querylet::Parser - parse a document into its Querylet sections

=head1 SYNOPSIS

    my @sections = Querylet::Parser->parse($querylet);
    
    for my $s (@sections) {
        print $s->{name};
        print $s->{type}; # "perl" for Perl code, "querylet" for Querylet section
        print $s->{block}; # content
        print $s->as_perl; # the compiled Perl code
    };

=cut

sub known_verbs {
    # We should sort them by descending length of keyword
    # so we get overlapping matches correct
    map { [ $_, $_->signature ] } known_sections
};

sub parse {
    my ($class, $code) = @_;
    
    # load all the verbs we know/accept
    my @verbs = known_verbs;
    
    my @sections;
    
    $code =~ s/\s+$//;
    
    # and parse them out:
    while ($code ne '') {
        # find the section that matches leftmost:
        my $leftmost_pos;
        my $leftmost_end;
        my $leftmost_match;
        for my $v (@verbs) {
            #warn $v->[0];
            if ($code =~ m/$v->[1]/) {
                if (!defined $leftmost_pos or $-[0] < $leftmost_pos) {
                    $leftmost_pos = $-[0];
                    $leftmost_end = $+[0];
                    $leftmost_match = [ $v, %+ ];
                    last if $leftmost_pos == 0; # we can't match anything better than start of $code
                };
            };
        };
        if (defined $leftmost_pos) {
            push @sections, Querylet::Section::Perl->new(substr($code, 0, $leftmost_pos))
                if $leftmost_pos;
            my $class = (shift @{ $leftmost_match })->[0];
            push @sections, $class->new( @$leftmost_match );
            $code = substr $code, $leftmost_end;
        } else {
            # The rest of $code is Perl code
            push @sections, Querylet::Section::Perl->new($code);
            last
        };
        
    };
    
    @sections
};

package Querylet::Section::Base;
use strict;

sub block {
    my ($class,$name) = (@_, 'block');
    qr/(?<$name>.*?)(?=^\S|\Z)/sm;
}
sub signature { qr/(?!)/ };
sub new { 
    my ($class, %args ) = @_;
    bless {
        type => 'querylet',
        %args
    } => $class
}
sub as_perl {
    die sprintf "# %s *** unimplemented ***", ref $_[0];
};

package Querylet::Section::Perl;
use strict;
use parent -norequire => 'Querylet::Section::Base';

# Never matched automatically
sub signature {
    qr/(?!)/
};

sub new {
    my ($class, $code ) = @_;
    bless {
        type => 'perl',
        block => $code,
    } => $class
};

sub as_perl {
    $_[0]->{block}
};

1;

package Querylet::Section::Query;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^query:\s*/m . $_[0]->block('query');
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->set_query($self->{query});
};

package Querylet::Section::Database;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^database:[\t ]*(?<dsn>\S.+)$/m
};

sub as_perl {
    my ($self, $target_class) = @_;
    sprintf <<'PERL', $self->{dsn}, $target_class;
        my $dbh = DBI->connect(q|%s|);
        $q->set_dbh($dbh);
PERL
};

package Querylet::Section::MungeQuery;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^munge\s+query:\s*/m . $_[0]->block('query_vars')
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->set_query_vars($self->{query_vars});
}

package Querylet::Section::QueryParameter;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^query\s+parameter:\s*/m . $_[0]->block('parameter')
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->bind_next_param($self->{parameter});
};

package Querylet::Section::SetOption;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^set\s+option\s+(?<name>[\/A-Za-z0-9_]+):\s*/m . $_[0]->block('value');
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->set_option( $self->{name} => $self->{value} );
}

package Querylet::Section::Input;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^input:\s*(?<name>[^\n]+)/m;
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->input($self->{name});
};

package Querylet::Section::InputType;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^input\s+type:\s*(?<name>\w+)/m;
};

sub as_perl {
    my ($self, $target_class) = @_;
    $target_class->set_input_type($self->{name});
};

package Querylet::Section::MungeRows;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^munge\s+rows:\s*/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->munge_rows($self->{expr});
};

package Querylet::Section::DeleteRowsWhere;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^delete\s+rows\s+where:\s*/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->delete_rows($self->{expr});
}

package Querylet::Section::MungeAllValues;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^munge\s+all\s+values:\s*/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->munge_values($self->{expr});
}

package Querylet::Section::MungeColumn;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^munge\s+column\s+(?<column>\w+):/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->munge_col($self->{column}, $self->{expr});
}

package Querylet::Section::AddColumn;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^add\s+column\s+(?<column>\w+):/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->add_col($self->{column}, $self->{expr});
}

package Querylet::Section::DeleteColumn;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^delete\s+column\s+(?<column>\w+)/m;
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->delete_col($self->{column});
}

package Querylet::Section::DeleteColumnsWhere;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^delete\s+columns\s+where:\s*/m . $_[0]->block('expr');
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->delete_cols($self->{expr});
}

package Querylet::Section::ColumnHeaders;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^column\s+headers?:\s*/m . $_[0]->block('headers');
};

package Querylet::Section::OutputFormat;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^output\s+format:\s*(?<format>\w+)/m;
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->set_output_type($self->{format});
};

package Querylet::Section::OutputMethod;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
  qr/^output\s+method:\s+(?<method>\w+)$/
};

package Querylet::Section::OutputFilename;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr!^output\s+file:\s+(?<filename>[\\/_.A-Za-z0-9]+)\s*$!m;
};

sub as_perl {
    my ($self,$target_class) = @_;
    $target_class->set_output_filename($self->{filename})
};

package Querylet::Section::NoOutput;
use strict;
use parent -norequire => 'Querylet::Section::Base';

sub signature {
    qr/^no\s+output$/m;
};

sub as_perl {
    Querylet::once('output', '');
}

1;

=head1 TODO

=over 4

=item *

Remember line number/offset of sections
for improved error reporting and generation
of

  #line 123

statements for better runtime error reporting

=item *

Implement mail sending plugin

=item *

Implement query parameter option that generates
a filesystem-safe string of all parameters added to the query

=item *

Implement command-line "input" for query parameters

=item *

Implement default "input" for query parameters (like "today()")

=back

=cut