package App::SD::Replica::jira::PushEncoder;
use Any::Moose;
use Params::Validate;
use Path::Class;

has sync_source => (
    isa => 'App::SD::Replica::jira',
    is  => 'rw',
);

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id =
      $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $ticket = $self->sync_source->jira->issue();
    my $attr = $self->_recode_props_for_integrate($change);
    $ticket->edit( $remote_ticket_id, $attr->{title}, $attr->{body} );
    if ( $attr->{status} ) {
        $ticket->reopen( $remote_ticket_id ) if $attr->{status} eq 'open';
        $ticket->close( $remote_ticket_id ) if $attr->{status} eq 'closed';
    }
    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Build up a ticket object out of all the record's attributes
    my $ticket = $self->sync_source->jira->issue;
    my $attr = $self->_recode_props_for_integrate($change);
    my $new =
      $ticket->open( $attr->{title}, $attr->{body} );
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
    my $ticket = $self->sync_source->jira->issue();
    $ticket->comment($ticket_id, $props{'content'});
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        if ( $key eq 'summary' ) {
            $attr{title} = $props{$key};
        }
        elsif ( $key eq 'body' ) {
            $attr{$key} = $props{$key};
        }
        elsif ( $key eq 'status' ) {
            $attr{state} = $props{$key} =~ /new|open/ ? 'open' : 'closed';
        }
    }
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
