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
