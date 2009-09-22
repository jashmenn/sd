package App::SD::Replica::jira::PushEncoder;
use Any::Moose;
use Params::Validate;
use Path::Class;
use Data::Dumper;

has sync_source => (
    isa => 'App::SD::Replica::jira',
    is  => 'rw',
);
extends 'App::SD::ForeignReplica::PushEncoder';
our %COMPONENTS_MAP = ();
our %TYPES_MAP = ();

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id = $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $ticket = $self->sync_source->jira->getIssue($remote_ticket_id);
    my $attr = $self->_recode_props_for_integrate($change);

    # my @rfvs;

    # while(my ($key, $value) = each(%$attr)) {
      # push @rfvs, RemoteFieldValue->new($key, $value);
    # }

    # print Dumper($remote_ticket_id);
    # print Dumper(@rfvs);
    $self->sync_source->jira->updateIssue($remote_ticket_id, $attr);
    # $ticket->edit( $remote_ticket_id, $attr->{title}, $attr->{body} );
    # if ( $attr->{status} ) {
    #     $ticket->reopen( $remote_ticket_id ) if $attr->{status} eq 'open';
    #     $ticket->close( $remote_ticket_id ) if $attr->{status} eq 'closed';
    # }
    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my $jira = $self->sync_source->jira;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Build up a ticket object out of all the record's attributes
    # my $ticket = $self->sync_source->jira->issue;
    my $attr = $self->_recode_props_for_integrate($change);

    my $new = $jira->create_issue(
      {
        project => $attr->{project},
        components => [$attr->{component}],
        summary => $attr->{summary},
        assignee => $attr->{assignee},
        type => $attr->{type}
      }
    );

    # TODO: better error handler?
    if ( $new->{error} ) {
        die "\n\n$new->{error}";
    }
    return $new->{number};
}

sub integrate_comment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Figure out the remote site's ticket ID for this change's record

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = $self->sync_source->jira->getIssue($ticket_id);
    $self->sync_source->jira->addComment($ticket_id, $props{'content'});
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;
    $props{project} = trim($props{project});
    $props{task} = trim($props{task});

    # neither body nor description pushes to jira with what we want.

    for my $key (qw/summary description project body assignee/) {
        $attr{$key} = trim($props{$key}) if $props{$key};
    }

    for my $key ( keys %props ) {
        if ( $key eq 'summary' ) {
            $attr{summary} = $props{$key};
        }
        elsif ( $key eq 'status' ) {
            $attr{state} = $props{$key} =~ /new|open/ ? 'open' : 'closed';
        }
        elsif ( $key eq 'component' ) {
            $attr{$key} = $self->_lookup_component($props{project}, $props{$key});
        }
        elsif ( $key eq 'type' ) {
            $attr{$key} = $self->_lookup_type($props{$key});
        }

    }

    return \%attr;
}

sub _lookup_component {
    my $self = shift;
    my $project = shift;
    my $component  = shift;
    $self->_build_components_map($project) unless exists $COMPONENTS_MAP{$project};
    return $COMPONENTS_MAP{$project}{lc $component};
}

sub _build_components_map {
    my $self = shift;
    my $project  = shift;
    my $raw_components = $self->sync_source->jira->get_components($project);
    my %components = ();
    foreach my $key (keys %$raw_components) {
      $components{lc $key} = $raw_components->{$key}->{id};
    }
    $COMPONENTS_MAP{$project} = \%components; 
}

sub _lookup_type {
    my $self = shift;
    my $type  = shift;
    $self->_build_types_map unless length keys %TYPES_MAP > 1;
    $type = trim(lc $type);
    return $TYPES_MAP{lc $type};
}

sub _build_types_map {
    my $self = shift;
    my $project  = shift;
    my $raw_types = $self->sync_source->jira->getIssueTypes;
    foreach my $component (@$raw_types) {
      $TYPES_MAP{lc $component->{name}} = $component->{id};
    }
}

# todo, mv to utils
sub trim
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}



__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
