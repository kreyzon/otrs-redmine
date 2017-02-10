# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Invoker::Test::RedmineInvoker;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsString IsStringWithData);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

use Kernel::System::Ticket;

use JSON;
use Encode;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Invoker::Test::RedmineInvoker - GenericInterface test Invoker backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Invoker->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    $Self->{TicketObject} = Kernel::System::Ticket->new( %Param );
    bless( $Self, $Type );

    # check needed params
    if ( !$Param{DebuggerObject} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no DebuggerObject!"
        };
    }

    $Self->{DebuggerObject} = $Param{DebuggerObject};

    return $Self;
}

=item PrepareRequest()

prepare the invocation of the configured remote webservice.

    my $Result = $InvokerObject->PrepareRequest(
        Data => {                               # data payload
            ...
        },
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {                    # data payload after Invoker
            ...
        },
    };

=cut

sub PrepareRequest {
	my ( $Self, %Param ) = @_;
  # Carrega o ticket atual
  my %Ticket = $Self->{TicketObject}->TicketGet(TicketID => $Param{Data}->{TicketID},);
  # verifica se o Estado dele é 11 (Em Desenvolvimento)
  if ( %Ticket{StateID} == 11 && $Param{Data}->{OldTicketData}->{StateID} != %Ticket{StateID}) {
      # Pesquisando as Notas do Ticket
    	my @Article = $Self->{TicketObject}->ArticleGet(TicketID => $Param{Data}->{TicketID},
    	);
      # Extraindo a Ultima nota e colocando-a no Param Data
      my $last_one = pop @Article;
      $Param{Data}->{UltimaNota} = $last_one;
      # Montando array  que correlaciona QueueID com project_id
      my %queueProject;
      $queueProject{3} = 24; # Compras
      $queueProject{4} = 25; # Estoque
      $queueProject{8} = 26; # Faturamento
      $queueProject{6} = 27; # Financeiro
      $queueProject{9} = 17; # NFe
      $queueProject{5} = 28; # Serviço
      # adicionar proximas correlções quando tiver ou refazer
      # Montando o JSON da Issue
      my %issue_json = (
        issue => {
          status_id => 1, # Quest Nova
          tracker_1 => 2, # Funcionalidade
    			author_id => 37, # ID do SuporteOTRS no Redmine
          assigned_to_id => 37, # ID do SuporteOTRS no Redmine
    			project_id => $queueProject{$Param{Data}->{OldTicketData}->{QueueID}},
          subject => $Param{Data}->{UltimaNota}->{Subject},
          description => $Param{Data}->{UltimaNota}->{Body},
          custom_fields => [
              {
                id => 1,
                name => "OTRS",
                value => $Param{Data}->{OldTicketData}->{TicketNumber}
              }
          ]
        }
    	);
      # Adicionando o JSON no Param Data
      $Param{Data}->{issue} = encode_utf8(encode_json \%issue_json);
    	return {
    		Success => 1,
    		Data => $Param{Data},
    	};
  }else{
    return $Self->{DebuggerObject}->Error( Summary => 'Estado Atual: ' . %Ticket{StateID});
  }
}

=item HandleResponse()

handle response data of the configured remote webservice.

    my $Result = $InvokerObject->HandleResponse(
        ResponseSuccess      => 1,              # success status of the remote webservice
        ResponseErrorMessage => '',             # in case of webservice error
        Data => {                               # data payload
            ...
        },
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {                    # data payload after Invoker
            ...
        },
    };

=cut

sub HandleResponse {
	my ( $Self, %Param ) = @_;

	# if there was an error in the response, forward it
	if ( !$Param{ResponseSuccess} ) {
		return {
			Success => 0,
			ErrorMessage => $Param{ResponseErrorMessage},
		};
	}

	return {
		Success => 1,
		Data => $Param{Data}->{issue}->{custom_fields},
		};
	}
1;
=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
