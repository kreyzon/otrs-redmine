# otrs-redmine
Devido a uma necessidade de integrar as ferramentas OTRS e Redmine, foi desenvolvido uma comunicação via REST para isso.

# Introdução
Antes de mais nada, deve-se entender como está sendo planejado o processo de integração, pois é justamente nele que você pode personalizar de acordo com os parâmetros de empresa.
No meu caso, temos o seguinte:
* [Bitnami Redmine Stack](https://bitnami.com/stack/redmine)
* [OTRS 5.0.4](https://www.otrs.com/download-open-source-help-desk-software-otrs-free/)

O Redmine é utilizado para gerenciar as tarefas da equipe de desenvolvimento baseado na metodologia do SCRUM, mas adaptado à RPG (Role-playing game), onde nossas tarefas são tratadas como 'Monstros' que possuem as situações 'Quest' (To Do), 'Batalha' (In Process), 'Resultado' (To Verify) e 'Vitória' (Done).
O OTRS veio a ser implementado pois alguns clientes tinham acesso ao Redmine para que demandas fossem geradas, entretanto nem todas as demandas dos clientes realmente precisavam de desenvolvimento (no caso virar um monstro). Para filtrar melhor isso, deixamos a cargo do OTRS o recebimento de chamados, entre seus estados encontram-se 'Novo', 'Aberto', 'Em Atendimento', 'Em Desenvolvimento', 'Aguardando deploy', 'Pendente de Aprovação', 'Fechado com sucesso' e 'Fechado sem aprovação'. Caso fosse alguma dúvida ou erro operacional informaríamos a resposta pelo próprio OTRS, caso o chamado entra-se 'Em Desenvolvimento' seria gerado um Monstro no Redmine. Mas isso de ficar tendo que trocar de um sistema para outro, na visão de quem iria gerenciar isso, acabou sendo bastante massivo, por isso tentamos automatizar o máximo possivel do processo.

# Primeiro Passo: Processo
Primeira coisa que foi alterada utilizando os sistemas foi a criação de campos customizáveis em ambos os sistemas para que quem tiver em um pudesse achar facilmente no outro.
Cada chamado do OTRS tem um campo chamado "ID Redmine", que conterá o id do monstro do Redmine. Cada monstro do Redmine tem um campo chamado "OTRS", que conterá o número do chamado do OTRS. Esses campos só serão preenchidos quando tiver necessidade.
Isso ajudou muito, porém o responsável pelo suporte ainda teria que ir em um sistema e no outro ficar atualizando as informações. Daí veio o segundo passo que foi efetivamente fazer com que determinados eventos atualizassem os sistemas. No caso do que está em código, foi o evento de TicketStatusUpdate, além de que somente se o novo estado for 'Em Desenvolvimento', um JSON é montado com as informações da nota lançada, o título da nota é o título do Monstro, o corpo da nota se torna a descrição dele e o número do chamado é colocado no campo OTRS.
Quando a tarefa é criada, caso exista algum valor no campo OTRS, um update no OTRS é feito com o número do OTRS, ou seja, tanto criando através do OTRS quanto criando arbitrariamente no próprio Redmine, o atualização no OTRS funcionará.
O esquema de atualizações funciona assim:

Estado OTRS | Situação Redmine
--------- | ------
Novo/Aberto | Sem ação
Em Atendimento | Sem ação
Em Desenvolvimento | Quest
Sem ação | Batalha
Sem ação | Resultado
Pendente de deploy | Vitória
Pendente de autorização | Sem ação
Aberto* | Quest
Fechado com sucesso | Sem ação
Fechado sem autorização | Sem ação

# Segundo Passo: Configuração do OTRS
Após o entendimento de como o processo de atualização deva funcionar, tem que configurar inicialmente a parte de Webservice no OTRS. O Redmine por si só já fornece a [API bem simples de usar](http://www.redmine.org/projects/redmine/wiki/Rest_api), porém no OTRS isso deve ser ativado. Para isso:

+ Ir em Administração > Webservices
+ Clicar em "Adicionar Web Server"
+ Informar um nome, que será utilizado como referência na URL
+ Clicar em Salvar

Percebam que o OTRS tem 2 modos de webservices, Provedor e Requisitante. No Provedor será configurado para que chamadas possam ser feitas ao OTRS, onde uma série de Operações já definidas podem ser selecionadas para habilitar nesse webservice que foi criado. No nosso caso, focarei nas Operação de TicketUpdate, uma vez que a comunicação com o Redmine depende do chamado já está criado e está sendo atualizado. No Requisitante é configurado  a comunicação com o Redmine, onde é indicado o host do Redmine e autenticação, além de configurar Eventos do OTRS para realizar as chamadas no Redmine. Novamente no nosso caso, focarei no Evento TicketStateUpdate, pois é a partir de uma atualização do Estado do chamado que o monstro é criado.
## Provedor
![OTRS Provedor](/img/otrs-provider.png)
Conforme a imagem acima, a parte de Provedor do OTRS é composta de 2 sessões, Configurações e Operações. Como algumas opções da parte de Configurações dependem das Operações, vou explicar sua configuração inicialmente.

Para entrar na tela de Detalhes da Operação (imagem abaixo), ou se seleciona uma opção de 'Adicionar Operation' ou se clica em uma Operação presente na tabela. Conforme percebe-se na tela, o único campo obrigatório é o de Nome, mas é sempre bom informar uma descrição para o sentido dessa operação, pois é permitido ter várias operações iguais com nomes diferentes.
![OTRS Provedor - Configuração de Operação](/img/otrs-provider-operationdetail.png)

Na parte de Configurações, uma vez que tenha sido escolhida entre HTTP::REST ou HTTP::SOAP. No nosso caso, foi escolhido a opção de HTTP::REST pois o consumo pelo Redmine e outros sistemas fica mais simplificado. Para acessa a tela de Transporte (imagem abaixo), basta clicar em Configurar ao lado da opção do Transporte. De acordo com as operações informadas, apareceram "Mapeamento da rota para a operação 'xxx'" onde serão informados os PATH de acesso à cada função, e para cada mapeamento pode ser informado quais métodos são válidos para a chamada.
![OTRS Provedor - Configuração de Transporte](/img/otrs-provider-transport.png)

 Após informar o PATH de cada operação, para acessa-la basta usar a URL "http://[HOST]:[PORT]/otrs/nph-genericinterface.pl/Webservice/[NOME_WEBSERVICE]/[NOME_PATH]/[PARAMS]" onde:

 * HOST: nome do host de acesso ao OTRS
 * PORT: porta do host de acesso ao OTRS, caso seja 80 não é necessário informar
 * NOME_WEBSERVICE: nome do werbservice informado na criação do mesmo
 * NOME_PATH: nome do PATH dado no mapeamento para acessa a Operation desejada
 * [PARAMS]: sequência de parametros utilizados para uso do Webservice. No geral, são obrigatórios os parâmetros "UserLogin" ou "CustomerID" junto de "Password" ou o parâmetro "SessionID" que pode ser gerado com a Operação 'SessionCreate', que só exige os parâmetros "UserLogin" ou "CustomerID" junto de "Password". Dependendo da operação, existem outros parâmetros obrigatórios. Essa relação pode ser encontrada [na documentação de desenvolvedor do OTRS](https://otrs.github.io/doc/api/otrs/stable/Perl/index.html) pesquisando por 'Kernel::GenericInterface::Operation'

## Requisitante
![OTRS Requisitante](/img/otrs-requester.png)
Conforme a imagem acima, a parte de Requisitante do OTRS é composta de 2 sessões, Configurações e Invocadores. Como algumas opções da parte de Configurações dependem dos Invocadores, vou explicar sua configuração inicialmente. Adianto que nessa parte foi necessário fazer uma mudança no código, pois os Invocadores fornecidos pelo OTRS são extremamente genéricos e não funcionam, servem apenas para servir de exemplo para serem desenvolvidos. Em "Mudança de código" está explicado o que foi alterado e como habilitar o Invocador novo. No nosso caso, esse invocador se chama RedmineInvoker.

Para entrar na tela de Detalhes do Invocador (imagem abaixo), ou se seleciona uma opção de 'Adicionar Invoker' ou se clica em um Invocador presente na tabela (RedmineInvoker foi o escolhido). Conforme percebe-se na tela, o único campo obrigatório é o de Nome, mas é sempre bom informar uma descrição para o sentido desse invocador, pois é permitido ter vários invocadores iguais com nomes diferentes. O mais interessante nessa tela é a tabela de 'Disparadores de evento', onde é possível indicar um evento do OTRS a chamar o webservice remoto. No nosso caso, como é somente por atualização do chamado do OTRS, somente o TicketStateUpdate é necessário.
![OTRS Requisitante - Configuração de Invocador](/img/otrs-requester-invokerdetail.png)

Na parte de Configuração, conforme imagem abaixo, é necessário informar a URL do host do webservice, no nosso caso, o do acesso ao Redmine, e para cada invocador é necessário informar o PATH que será acessado no webservice remoto. Como a chamada do Redmine é feita através de JSON e queremos criar tarefas, basta colocar como /issues.json e indicar quais métodos HTTP são válidos para a chamada. Além disso, deve-se informar qual a autenticação, que no caso seria BasicAuth e informar um usuário e senha válidos no Redmine.
![OTRS Requisitante - Configuração de Transporte](/img/otrs-requester-transport.png)

## Campo Redmine
Uma vez configurado como o OTRS vai se comportar, seja como Provedor, seja como Requisitante, é necessário uma última alteração a ser feita que é um link direto entre o OTRS e o Redmine. Para isso, basta ir em Administração > Campos Dinâmicos. Na tela é possível criar um campo novo para "Chamado" ou para "Artigo", foi escolhida a opção de deixar em Chamado pois é mais visível ao agente de suporte. Ao clicar sobre o campo do Chamado, aparece uma lista de opções sobre o tipo do campo a ser criado, dentre eles estão "Checkbox", "Data", "Data/Hora", "Multisseleção", "Suspenso", "Texto" e "Área de texto", no nosso caso foi escolhido a opção de Texto.
Após a seleção, você será direcionado a tela de configuração do campo, onde tem 3 campos obrigatórios, Nome, Campo e Ordem do Campo mas um já vem preenchido (Ordem do Campo). "Nome" é a variável a ser criada, não pode conter nada além de  caracteres alfabéticos e numéricos. Já o "Campo" é o texto label que aparecerá no OTRS quando ele for solicitado, seja nas tabelas ou em modais do sistema. Além desses campos, um campo interessante é o 'Mostrar Link', que permite uma formatação do valor a ser informado no campo para o link colocado, essa formatação se dá da seguinte forma [% Data.XXX | uri %] onde Data.XXX é referente à todos os campos dinâmicos, no lugar do XXX deve colocar o "Nome" do campo. A imagem abaixo mostra como ficou a configuração do campo redmine.
![OTRS Campos Dinâmicos - Campo Redmine](/img/otrs-customfield-redmine.png)

Após a criação do campo, deve-se alterar as configrações do sistema para fazer aparecer o campo. Para tal, basta ir em Administração > Configuração do Sistema, pesquisar pelo grupo Ticket e editar somente aqueles que são necessários. No nosso caso, os necessários foram:

* Frontend::Agent::Ticket::ViewStatus, para mostrar na visão de estados o link do Redmine
* Frontend::Agent::Ticket::ViewLocked, para mostrar na visão de chamados bloqueados ao agente o link do Redmine
* Frontend::Agent::Ticket::ViewNote, para mostrar ao lançar uma nota o link do Redmine

A tela de ViewStatus e ViewLocked, a forma de incluir o campo é praticamente a mesma, ela segue o exemplo da tela abaixo, obrigatoriamente para campos dinâmicos deve-se colocar DynamicField_XXX, onde XXX é no Nome do campo. O valor na coluna pode variar entre 0 (Desabilitado, não aparece para ninguém), 1 (Disponível, o agente pode optar por mostra-lo ou não na tabela) e 2 (Habilitado, obrigatoriamente mostra na tabela).
![OTRS Campos Dinâmicos - ViewStatus](/img/otrs-customfield-viewstatus.png)

Na tela de ViewNote, basta procurar por DynamicField que aparecerá a tabela onde se informar o Nome do campo (sem a necessidade do DynamicField_) e o valor que ele vai receber que varia entre 0 (Desabilitado, não pode ser mexido por ninguém), 1 (Habilitado, o agente pode optar por preenche-lo ou não) e 2 (Habilitado e requerido, obrigatoriamente deve ser informado).
![OTRS Campos Dinâmicos - ViewNote](/img/otrs-customfield-viewnote.png)
## Mudança no código
Explicar sobre os arquivos RedmineInvoker.pm, REST.pm, Mapping.pm, Simple.pm

### RedmineInvoker.pm
Conforme citado anteriormente, o RedmineInvoker foi desenvolvido para ser a ponte entre o OTRS e o Redmine. O Invocador possue 3 subrotinas.
* new
* PrepareRequest
* HandleResponse

Na subrotina new, foi alterado somente para incluir a exitencia do TicketObject, que possue métodos relacionados ao Ticket em geral. Esses métodos encontram-se [nesse link.](https://otrs.github.io/doc/api/otrs/stable/Perl/Kernel/System/Ticket.pm.html)
```
sub new {
    my ( $Type, %Param ) = @_;
    # allocate new hash for object
    my $Self = {};
    ###############################  editado a partir daqui ###############################
    $Self->{TicketObject} = Kernel::System::Ticket->new( %Param );
    ###############################     editado até aqui    ###############################
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
```
Na subrotina PrepareRequest, foi alterado para consultar o Ticket atual, pois como o evento é após a edição, no hash $Param{Data} contem o estado anterior do Ticket em $Param{Data}->{OldTicketData}.
```
my %Ticket = $Self->{TicketObject}->TicketGet(TicketID => $Param{Data}->{TicketID},);
```
A partir disso, verifico se o StateID é o desejado e se ele mudou nessa atualização, para evitar que qualquer nota lançada ou mudança de proprietário tentasse criar uma tarefa no Redmine.
```
if ( %Ticket{StateID} == 11 && $Param{Data}->{OldTicketData}->{StateID} != %Ticket{StateID}) {
```
Como parte do processo, ao mudar o estado do OTRS para "Em Desenvolvimento", a nota que será enviada junto será carregada para justamente servir de fonte para a Tarefa a ser criada. Essa nota é salva em $Param{Data}->{UltimaNota}
```
# Pesquisando as Notas do Ticket
my @Article = $Self->{TicketObject}->ArticleGet(TicketID => $Param{Data}->{TicketID},
);
# Extraindo a Ultima nota e colocando-a no Param Data
my $last_one = pop @Article;
$Param{Data}->{UltimaNota} = $last_one;
```
No Redmine, cada Tarefa deve obrigatoriamente pertencer à um projeto. No nosso caso, o OTRS já estava configurado para que cada fila correspondesse à um modulo no sistema, para fazer essa correlação, foi incluso um array com os ID das Filas X ID dos Projetos. Futuramente isso pode ser melhorado.
```
# Montando array  que correlaciona QueueID com project_id
my %queueProject;
$queueProject{3} = 24; # Compras
$queueProject{4} = 25; # Estoque
$queueProject{8} = 26; # Faturamento
$queueProject{6} = 27; # Financeiro
$queueProject{9} = 17; # NFe
$queueProject{5} = 28; # Serviço
```
Com essas informações é possível montar um JSON que será enviado ao Redmine, guardado na variável $Param{Data}->{issue}.
```
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
```
No final o método se assemelhará a esse abaixo.
```
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
```
O método de HandleResponse não foi alterado.

### REST.pm
Dentre os métodos dessa classe, o único que foi mexido foi a subrotina RequesterPerformRequest, responsável por montar todo o processo do Perl para comunicação REST.
Como o Perl converte todo o hash ${Param} para JSON, foi necessário excluir os itens OldTicketData, TicketID e UltimaNota da seguinte forma.
```
# Excluindo coisas que não vao servir daqui pra frente!
delete $Param{Data}->{OldTicketData};
delete $Param{Data}->{TicketID};
delete $Param{Data}->{UltimaNota};
```
Após isso, internamente a subrotina verifica se os métodos PUT, POST e PATCH são chamados, caso sim então ele faz a codificação para JSON. Como já havia pré-montado o JSON no RedmineInvoker, foi necessário descodifica-lo para que essa parte o codifique novamente. Futuramente isso mode ser melhorado.
```
my $json = decode_json $Param{Data}->{issue};
$Param{Data} = $JSONObject->Encode(
    Data => $json,
);
```
E para finalizar, alterei a verificação da resposta, onde ele somente verificava se foi o HTTP code 200, mas como o de criação é 201, considerei-o também assim
```
if ( $ResponseCode ne '200' && $ResponseCode ne '201' ) {
    $ResponseError = $ErrorMessage . " Response code '$ResponseCode'.";
}
```
# Terceiro Passo: Configuração do Redmine
Infelizmente (ou não), o Redmine não possue um modo Requester como o OTRS, o que torna a configuração mais pelo lado do cógido do que pela interface do mesmo. Por interface, a única coisa a ser feita é a criação do campo OTRS.
## Campo OTRS
Para criar o campo de OTRS, deve-se ir na parte de Administração > Campos personalizados. Ao clicar no botão de novo campo, pede-se para qual objeto do Redmine esse campo será criado. No nosso caso, será criado para Tarefas. Após isso, seleciona-se o 'Tipo' do campo, no nosso caso foi Texto, informar 'Nome' do campo, e informa 'Valores do link para URL', que se for preenchido com "http://[HOST]:[PORT]/otrs/index.pl?Action=AgentTicketZoom;TicketNumber=%value%", ao clicar no campo com um valor válido uma nova janela é aberta carregando o chamado com o número informado no campo. Além desses campos, pode-se informar se ele vai ser pesquisável, se pertence a todos os projetos ou só a alguns, para quais tipos de tarefas e paéis ele irá aparecer.
![OTRS Campos Dinâmicos - Campo Redmine](/img/otrs-customfield-redmine.png)

## Mudança no código
Basicamente, o único arquivo do Redmine que foi mexido foi o "issues_controller.rb", nele estão contidos os métodos "create" e "update".
No método de create, apenas foi adicionado a verificação do valor do campo OTRS, caso ele exista com um valor, o webservice do OTRS é chamado. Isso permite que tanto quando o OTRS criar a tarefa, quanto se a tarefa for criada avulsa, o OTRS será atualizado para apontar a esta tarefa. Para o webservice de atualização, é necessário informar o TicketNumber ou TicketID e os parametros de autenticação, no body passar um JSON com "{"DynamicField":{"Name": "redmine", "Value":#{@issue.id}}}", a praticidade do código do Rails do redmine permite escrever expression-language na string e a mesma ser interpretada para carregar o valor, quaisquer informações a mais podem ser consultadas dessa forma.
```
def create
  call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
  @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
  if @issue.save
    call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
    ###############################  editado a partir daqui ###############################
    field = IssueCustomField.find_by_name('OTRS')
    if @issue.custom_value_for(field).value
      uri = URI.parse("http://localhost:81/otrs/nph-genericinterface.pl/Webservice/Teste/UpdateTicket?TicketNumber=#{@issue.custom_value_for(field)}&UserLogin=user@example.com&Password=yourpass")
      body = "{\"DynamicField\" : {\"Name\" : \"redmine\", \"Value\" : #{@issue.id}}}"
      headers = {'Content-Type' => 'application/json', 'Charset' => 'utf-8' }
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      headers.keys.each do |key|
        request[key] = headers[key]
      end
      request.body = body
      http.request(request)
    end
    ###############################     editado até aqui    ###############################
    respond_to do |format|
      format.html {
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
        if params[:continue]
          attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
          redirect_to new_project_issue_path(@issue.project, :issue => attrs)
        else
          redirect_to issue_path(@issue)
        end
      }
      format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
    end
    return
  else
    respond_to do |format|
      format.html { render :action => 'new' }
      format.api  { render_validation_errors(@issue) }
    end
  end
end
```
No método de update, também foi adicionado a verificação do valor do campo OTRS, caso ele exista com um valor, o webservice do OTRS é chamado, mas além disso verifica-se também se a situação da tarefa foi modificada também, em especial para a situação de vitória. Aproveito esse momento para além de alterar o Estado do OTRS, lançar uma nota informando que o desenvolvimento já concluiu a solicitação e que está sendo aguardado um novo deploy para teste.
```
def update
  return unless update_issue_from_params
  @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
  saved = false
  begin
    saved = save_issue_with_child_records
  rescue ActiveRecord::StaleObjectError
    @conflict = true
    if params[:last_journal_id]
      @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
      @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
    end
  end

  if saved
    render_attachment_warning_if_needed(@issue)
    flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?
    ###############################  editado a partir daqui ###############################
    # verificar se tem o campo OTRS informado e se a situação da issue é Vitória(id=5)
    field = IssueCustomField.find_by_name('OTRS')
    if @issue.custom_value_for(field).value && @issue.status_id == 5
      uri = URI.parse("http://localhost:81/otrs/nph-genericinterface.pl/Webservice/Teste/UpdateTicket?TicketNumber=#{@issue.custom_value_for(field)}&UserLogin=user@example.com&Password=yourpass")
      body = "{\"Ticket\" : {\"StateID\" : 10}, \"Article\" : {\"Subject\" : \"Retorno do Desenvolvimento\", \"Body\":\"#{@issue.current_journal.notes}\", \"ArticleType\":\"note-internal\", \"HistoryType\":\"AddNote\",\"Charset\": \"utf8\", \"MimeType\":\"application/json\"}}"
      headers = {'Content-Type' => 'application/json', 'Charset' => 'utf-8' }
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      headers.keys.each do |key|
        request[key] = headers[key]
      end
      request.body = body
      http.request(request)
    end
    ###############################     editado até aqui    ###############################
    respond_to do |format|
      format.html { redirect_back_or_default issue_path(@issue) }
      format.api  { render_api_ok }
    end
  else
    respond_to do |format|
      format.html { render :action => 'edit' }
      format.api  { render_validation_errors(@issue) }
    end
  end
end
```
Ambas as alterações enncontram-se na pasta Redmine desse repositório
