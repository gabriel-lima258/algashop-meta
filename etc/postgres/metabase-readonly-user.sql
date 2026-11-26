-- Usuario que o Metabase usa para LER o reporting database (fonte "Algashop Insights").
-- Ferramenta de BI so consulta: ela nunca deveria conseguir alterar a copia do CDC.

create role metabase_reader login password 'metabase_reader';

-- Rede de seguranca: toda transacao deste usuario ja nasce somente leitura.
-- Mesmo que alguem conceda escrita por engano, o INSERT/UPDATE/DELETE e recusado.
alter role metabase_reader set default_transaction_read_only = on;
grant connect on database insights to metabase_reader;

\connect insights

grant usage on schema public to metabase_reader;

-- Na primeira subida as tabelas AINDA NAO EXISTEM (quem cria e o Flyway do insights),
-- entao este grant nao pega nada. Ele fica para quando o script rodar na mao.
grant select on all tables in schema public to metabase_reader;

-- Quem faz o trabalho de verdade: toda tabela criada DEPOIS ja nasce com SELECT
-- para o leitor. Atencao: vale so para tabelas criadas pelo papel que rodou este
-- comando (postgres). Se outro usuario criar tabela, o grant nao chega nela.
alter default privileges in schema public grant select on tables to metabase_reader;
