package App::SD::Replica::jira;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use URI;
use Memoize;
use JIRA::Client;
use Data::Dumper;

use Prophet::ChangeSet;

use constant scheme => 'jira';
use constant pull_encoder => 'App::SD::Replica::jira::PullEncoder';
use constant push_encoder => 'App::SD::Replica::jira::PushEncoder';

has jira       => ( isa => 'JIRA::Client',    is => 'rw' );
has remote_url => ( isa => 'Str',             is => 'rw' );
has owner      => ( isa => 'Str',             is => 'rw' );
has query      => ( isa => 'Str',             is => 'rw' );
# has repo       => ( isa => 'Str',             is => 'rw' );

our %PROP_MAP = ( state => 'status', title => 'summary' );

sub BUILD {
    my $self = shift;
    my ($server) = $self->{url} =~ m{^jira:(http://.*)}
      or die "Can't parse Jira server spec. Expected jira:http://jira-base-url";

    my ( $uri, $username, $password );

    $uri = URI->new($server);

    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }

    $self->remote_url("$uri");

    $self->{query} = "Cloud-Team-Projects"; # tmp

    $self->jira(
        JIRA::Client->new(
            $uri,
            $username,
            $password
        ) );

}

sub record_pushed_transactions {}

sub uuid {
    my $self = shift;
    Carp::cluck "- can't make a uuid for this" unless ($self->remote_url);
    return $self->uuid_for_url( join( '/', $self->remote_url) );
}

# sub remote_uri_path_for_comment {
#     my $self = shift;
#     my $id = shift;
#     return "/comment/".$id;
# }

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/browse/".$id;
}

# sub database_settings {
#     my $self = shift;
#     return {
# # TODO limit statuses too? the problem is githubs's statuses are so poor,
# # it only has 2 statuses: 'open' and 'closed'.
#         project_name => $self->owner . '/' . $self->repo,
#     };

# }

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
