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

# jira's keys: 'description' 'duedate' 'environment' 'fixVersions' 'id' 'key' 'priority' 'project' 'reporter' 'resolution' 'status' 'summary' 'type' 'updated' 'votes'
# sd keys: ["id","summary","status","milestone","component","owner","created","due","creator","reporter","original_replica"]
# our %PROP_MAP = (description => 'body', status => 'state', summary => 'title', updated => 'date' );
# our %PROP_MAP = (body => 'description', state => 'status', title => 'summary', date => 'updated');

our %PROP_MAP = (
    # jira's => sd's
    'description' => 'body',
    'duedate' => 'due',
    'reporter' => "reporter",
    'status' => 'status',
    'summary' => 'summary',
    'environment' => undef,
    'fixVersions' => undef,
    'priority' => undef, 
    'project' => undef,
    'resolution' => undef,
    'type' => undef,
    'updated' => undef, 
    'votes' => undef
    );

our %STATUS_MAP = (
   # jira's => sd's
    1 => "open"
    );

sub BUILD {
    my $self = shift;
    my ($server) = $self->{url} =~ m{^jira:(http://.*)}
      or die "Can't parse Jira server spec. Expected jira:http://jira-base-url";

    my ( $uri, $username, $password );
    $uri = URI->new($server);

    # to set these up run the following:
    # sd config user.username $USERNAME
    # sd config user.password $PASSWORD
    $username = $self->{app_handle}->{config}->{data}->{'user.username'};
    $password = $self->{app_handle}->{config}->{data}->{'user.password'};

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
