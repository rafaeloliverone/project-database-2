/*** 
GRUPO: Rafael Oliveira
       Lucas Sales
***/

/*** Criação da tabela Contas ***/
CREATE TABLE Contas
(
	numconta char(11)             NOT NULL,
	dig      char(1)              NOT NULL,
	nome     varchar(50)          NOT NULL,
	tipo     char(1)              NOT NULL
	CONSTRAINT DF_contas_tipo     DEFAULT 'A',
	ativa    char(1)              NOT NULL
	CONSTRAINT DF_contas_ativa    DEFAULT 'S',
	CONSTRAINT PK_contas          PRIMARY KEY (numconta),
	CONSTRAINT CK_contas_numconta CHECK (LENGTH(numconta)=11),
	CONSTRAINT CK_contas_dig      CHECK (dig SIMILAR TO '[0-9|&]'),
	CONSTRAINT CK_contas_tipo     CHECK (tipo SIMILAR TO '[A|S]'),
	CONSTRAINT CK_contas_ativa    CHECK (ativa SIMILAR TO '[S|N]')
);

/*** Criação da tabela Saldos ***/
CREATE TABLE Saldos
(
	numconta char(11)           NOT NULL,
	ano      int                NOT NULL,
	saldo    numeric(9,2)       NOT NULL
	CONSTRAINT DF_saldos_saldo  DEFAULT 0,
	CONSTRAINT FK_saldos_contas FOREIGN KEY (numconta) REFERENCES Contas,
	CONSTRAINT PK_saldos        PRIMARY KEY (ano, numconta)
);

/*** Criação da tabela DebCred ***/
CREATE TABLE DebCred
(
	numconta char(11)             NOT NULL,
	mesano   char(6)              NOT NULL,
	credito  numeric(11,2)        NOT NULL
	CONSTRAINT DF_debcred_credito DEFAULT 0,
	debito   numeric(11,2)        NOT NULL
	CONSTRAINT DF_debcred_debito  DEFAULT 0,
	CONSTRAINT FK_debcred_contas  FOREIGN KEY (numconta) REFERENCES Contas,
	CONSTRAINT PK_debcred         PRIMARY KEY (mesano, numconta)
);

/*** Criação da tabela MovDebCred ***/
CREATE TABLE MovDebCred
(
	numconta char(11)                NOT NULL,
	nsu      int                     GENERATED ALWAYS AS IDENTITY,
	dig      char(1)                 NOT NULL,
	data     date                    NOT NULL,
	debcred  char(1)                 NOT NULL,
	valor    numeric(11,2)           NOT NULL
	CONSTRAINT DF_movdebcred_valor   DEFAULT 0,
	CONSTRAINT PK_movdebcred         PRIMARY KEY (numconta, nsu),
	CONSTRAINT CK_movdebcred_debcred CHECK (debcred SIMILAR TO '[D|C]')
);



/*** TAREFAS ***/

/*** FUNCÃO PARA DESCOBRIR NÍVEL DA CONTA ***/
CREATE OR REPLACE FUNCTION nivelConta(conta char(11))
RETURNS INTEGER AS $$
DECLARE
	acc_lvl int := 6;
BEGIN
	IF substring(conta from 10 for 11) = '00' THEN
		acc_lvl := 5;
		IF substring(conta from 7 for 3) = '000' THEN
			acc_lvl := 4;
			IF substring(conta from 5 for 2) = '00' THEN
				acc_lvl := 3;
				IF substring(conta from 3 for 2) = '00' THEN
					acc_lvl := 2;
					IF substring(conta from 2 for 1) = '0' THEN
						acc_lvl := 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END IF;
	RETURN acc_lvl;
END; $$
LANGUAGE plpgsql;



/*** FUNCÃO PARA DESCOBRIR AS CONTAS SUPERIORES DE UMA DETERMINADA CONTA ***/
CREATE OR REPLACE FUNCTION contaSuperior(conta char(11))
RETURNS char(11)[] AS $$													
DECLARE
	nivel integer := (SELECT nivelConta(conta));
	contasSuperiores char(11)[];
	conta_1 char(11);
	conta_2 char(11);
	conta_3 char(11);
	conta_4 char(11);
	conta_5 char(11);												
BEGIN
	IF nivel = 6 THEN
		conta_1 := rpad(substring(conta from 1 for 1), 11, '0');
		conta_2 := rpad(substring(conta from 1 for 2), 11, '0');
		conta_3 := rpad(substring(conta from 1 for 4), 11, '0');
		conta_4 := rpad(substring(conta from 1 for 6), 11, '0');
		conta_5 := rpad(substring(conta from 1 for 9), 11, '0');
		contasSuperiores := array_append(contasSuperiores, conta_1);
		contasSuperiores := array_append(contasSuperiores, conta_2);
		contasSuperiores := array_append(contasSuperiores, conta_3);
		contasSuperiores := array_append(contasSuperiores, conta_4);
		contasSuperiores := array_append(contasSuperiores, conta_5);
	ELSIF nivel = 5 THEN
		conta_1 := rpad(substring(conta from 1 for 1), 11, '0');
		conta_2 := rpad(substring(conta from 1 for 2), 11, '0');
		conta_3 := rpad(substring(conta from 1 for 4), 11, '0');
		conta_4 := rpad(substring(conta from 1 for 6), 11, '0');
		contasSuperiores := array_append(contasSuperiores, conta_1);
		contasSuperiores := array_append(contasSuperiores, conta_2);
		contasSuperiores := array_append(contasSuperiores, conta_3);
		contasSuperiores := array_append(contasSuperiores, conta_4);
	ELSIF nivel = 4 THEN
		conta_1 := rpad(substring(conta from 1 for 1), 11, '0');
		conta_2 := rpad(substring(conta from 1 for 2), 11, '0');
		conta_3 := rpad(substring(conta from 1 for 4), 11, '0');
		contasSuperiores := array_append(contasSuperiores, conta_1);
		contasSuperiores := array_append(contasSuperiores, conta_2);
		contasSuperiores := array_append(contasSuperiores, conta_3);
	ELSIF nivel = 3 THEN
		conta_1 := rpad(substring(conta from 1 for 1), 11, '0');
		conta_2 := rpad(substring(conta from 1 for 2), 11, '0');
		contasSuperiores := array_append(contasSuperiores, conta_1);
		contasSuperiores := array_append(contasSuperiores, conta_2);
	ELSIF nivel = 2 THEN
		conta_1 := rpad(substring(conta from 1 for 1), 11, '0');
		contasSuperiores := array_append(contasSuperiores, conta_1);
	END IF;
	RETURN contasSuperiores;
END; $$
LANGUAGE plpgsql;						  


/*** TRIGGER ***/
/*** a) Criar um trigger na tabela conta que só permita adicionar uma nova conta 
se todas as suas contas superiores já estiverem na tabela. ***/
CREATE OR REPLACE FUNCTION checkConta()
RETURNS TRIGGER AS $$
DECLARE
	nivel integer := (SELECT nivelConta(NEW.numconta));
	contasSuperiores char(11)[] := (SELECT contaSuperior(NEW.numconta));									   
BEGIN
	IF (TG_OP='INSERT') THEN
		IF nivel = 6 THEN
			IF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[1]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																						 
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[2]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[3]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[4]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[5]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			END IF;
		ELSIF nivel = 5 THEN	
			IF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[1]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																						 
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[2]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[3]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[4]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			END IF;
		ELSIF nivel = 4 THEN	
			IF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[1]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																						 
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[2]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[3]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			END IF;
		ELSIF nivel = 3 THEN	
			IF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[1]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																						 
				USING HINT = 'Insira as contas superiores primeiro';
			ELSIF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[2]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																							
				USING HINT = 'Insira as contas superiores primeiro';
			END IF;
		ELSIF nivel = 2 THEN	
			IF NOT EXISTS (SELECT numconta FROM Contas WHERE numconta = contasSuperiores[1]) THEN
				RAISE EXCEPTION 'Conta não pode ser inserida'																						 
				USING HINT = 'Insira as contas superiores primeiro';
			END IF;																					  
		END IF;									   
	END IF;
	RETURN NEW;																			   
END; $$
LANGUAGE plpgsql;
																			   
CREATE TRIGGER tgcheckConta
BEFORE INSERT ON Contas
FOR EACH ROW
EXECUTE PROCEDURE checkConta();

																						 
/*** PROCEDURE ****/
																						 
/*** a) Implementar uma stored procedure que execute o processamento de atualização do movimento mensal 
das contas. A procedure deve receber como argumento o mês e ano para atualização. ***/																						 
CREATE OR REPLACE PROCEDURE insertDebCred(mes text, ano text)
AS $$
DECLARE
	cursorDebCred2 NO SCROLL CURSOR
	FOR SELECT * FROM sumarizadaMovDebCred(mes,ano);
	rec RECORD;
	contasSuperiores char(11)[];
	incremento text := 'a';
	nivel int;
BEGIN 
	OPEN cursorDebCred2;
		LOOP
			FETCH cursorDebCred2 INTO rec;
			EXIT WHEN NOT FOUND;
			
				-- NumConta já está na tabela Contas
				IF rec.NumConta IN (SELECT NumConta FROM Contas) THEN
					
					-- Se possuir registro na tabela DebCred
					IF rec.NumConta IN (SELECT NumConta FROM DebCred) THEN
						
						-- Se possuir registro na tabela DebCred com NumConta e mesano, fazer update
						IF rec.NumConta::text LIKE (SELECT NumConta FROM DebCred WHERE mesano = mes||ano and numconta = rec.NumConta)::text THEN 
							UPDATE public.debcred 
								SET numconta=rec.NumConta, mesano=rec.mesano, credito=rec.credito, debito=rec.debito
								WHERE numconta = rec.NumConta and mesano = rec.mesano;
							RAISE NOTICE '(%) já possui registro na tabela dessa conta com o mês, foi feito UPDATE', rec.NumConta;
							
							nivel := (select nivelConta(rec.NumConta));	
							contasSuperiores := (SELECT contaSuperior(rec.NumConta));
							
							FOR i IN 1..nivel-1 LOOP
							IF contasSuperiores[i] IN (SELECT NumConta FROM Contas) AND contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN
-- 								INSERT INTO public.debcred(numconta, mesano, credito, debito)
-- 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
								UPDATE public.debcred 
								SET numconta=contasSuperiores[i], mesano=rec.mesano, credito= rec.credito, debito= rec.debito
								WHERE numconta = contasSuperiores[i] and mesano = rec.mesano;
										raise notice '%','INSERINDO DIRETO NO LOOP';
							
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM Contas) THEN 
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');		

							ELSE 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');
									
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							END IF;
						END LOOP;
							
							
							
						-- Possui registro na DebCred, porém o mesano é diferente	
						ELSE 
							INSERT INTO public.debcred(numconta, mesano, credito, debito)
							VALUES (rec.NumConta, rec.mesano, rec.credito, rec.debito);
							raise notice '(%) inserindo na tabela debcred, o mês é diferente', rec.NumConta;
							
							nivel := (select nivelConta(rec.NumConta));	
							contasSuperiores := (SELECT contaSuperior(rec.NumConta));
							
							FOR i IN 1..nivel-1 LOOP
							IF contasSuperiores[i] IN (SELECT NumConta FROM Contas) AND contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN
-- 								INSERT INTO public.debcred(numconta, mesano, credito, debito)
-- 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
								UPDATE public.debcred 
								SET numconta=contasSuperiores[i], mesano=rec.mesano, credito= rec.credito, debito= rec.debito
								WHERE numconta = contasSuperiores[i] and mesano = rec.mesano;
										raise notice '%','INSERINDO DIRETO NO LOOP';
							
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM Contas) THEN 
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');		

							ELSE 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');
									
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							END IF;
						END LOOP;
							
						END IF;
						
					-- Se não possuir registro, só insere direto 	
					ELSE 
						INSERT INTO public.debcred(numconta, mesano, credito, debito)
						VALUES (rec.NumConta, rec.mesano, rec.credito, rec.debito);
						RAISE NOTICE '(%) é nova na tabela DebCred apenas insere', rec.NumConta;
						
						nivel := (select nivelConta(rec.NumConta));	
						contasSuperiores := (SELECT contaSuperior(rec.NumConta));
						
						FOR i IN 1..nivel-1 LOOP
							IF contasSuperiores[i] IN (SELECT NumConta FROM Contas) AND contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN
-- 								INSERT INTO public.debcred(numconta, mesano, credito, debito)
-- 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
								UPDATE public.debcred 
								SET numconta=contasSuperiores[i], mesano=rec.mesano, credito= rec.credito, debito= rec.debito
								WHERE numconta = contasSuperiores[i] and mesano = rec.mesano;
										raise notice '%','INSERINDO DIRETO NO LOOP';
							
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM Contas) THEN 
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
 										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							ELSIF contasSuperiores[i] IN (SELECT NumConta FROM DebCred) THEN 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');		

							ELSE 
								INSERT INTO public.contas(
									numconta, dig, nome, tipo, ativa)
									VALUES (contasSuperiores[i], gerarDigito(contasSuperiores[i]), incremento, 'S', 'S');
									
								INSERT INTO public.debcred(numconta, mesano, credito, debito)
										VALUES (contasSuperiores[i], rec.mesano, rec.credito, rec.debito);
										
							END IF;
						END LOOP;
							
					END IF;
	
					
				-- Se NumConta não possuir registro na tabela Contas	
				ELSE 
					RAISE NOTICE '(%) não cadastrada na tabela contas', rec.NumConta;
				END IF;
		END LOOP;
	CLOSE cursorDebCred2;
END;$$
LANGUAGE plpgsql;
																							  
																							  

/*** b) Implemente uma stored procedure que transporte o saldo final (dezembro/yyyy) de um ano 
que teve seu processamento encerrado para o ano posterior. O transporte de saldo deve ser feito 
para todas as contas do plano de contas  ***/
CREATE OR REPLACE PROCEDURE transpSaldoFinal(ano text)
LANGUAGE plpgsql
AS $$
DECLARE
	linha RECORD;
	saldo_final numeric(11, 2) := 0;
	total_credito numeric(11, 2) := 0;
	total_debito numeric(11, 2) := 0;
	mes text;
BEGIN
	IF EXISTS (SELECT mesano FROM debcred WHERE mesano = '12' || ano) THEN
		FOR linha IN SELECT numconta FROM contas WHERE tipo = 'A' LOOP
			FOR i IN 1..12 LOOP
				CASE i
					WHEN 1,2,3,4,5,6,7,8,9 THEN
						mes := '0' || CAST(i AS text);
					ELSE
						mes := CAST(i AS text);
				END CASE;
				IF EXISTS (SELECT credito FROM debcred WHERE numconta = linha.numconta AND mesano = mes || ano) THEN
					total_credito := total_credito + (SELECT credito FROM debcred WHERE numconta = linha.numconta AND mesano = mes || ano);
				END IF;
				IF EXISTS (SELECT debito FROM debcred WHERE numconta = linha.numconta AND mesano = mes || ano) THEN
					total_debito := total_debito + (SELECT debito FROM debcred WHERE numconta = linha.numconta AND mesano = mes || ano);
				END IF;
			END LOOP;
			saldo_final := total_credito - total_debito;
			INSERT INTO saldos (numconta, ano, saldo) VALUES (linha.numconta, CAST(ano AS int)+1, saldo_final);
			total_credito := 0;
			total_debito := 0;
		END LOOP;
	END IF;
END $$;
																							  
/*** c) Implementar uma stored procedure/stored function que realize a crítica do movimento de débito 
e crédito. A stored procedure deve sinalizar quando não houver inconsistência nos registros analisados.	***/																						  
CREATE TYPE c_mov AS (
	numconta char(11),
	dig char(1),
	erros text[]
)

CREATE OR REPLACE FUNCTION critica_mov(mes text, ano text)
	RETURNS SETOF c_mov
AS $$
DECLARE 
	linha record;
	erros text[];
BEGIN 
	FOR linha in SELECT Distinct NumConta, Dig FROM MovDebCred WHERE Data::text LIKE ano||'-'||mes||'%'
	LOOP
		IF linha.NumConta NOT IN (SELECT NumConta FROM Contas) THEN  
			erros := array_append(erros, 'Conta não cadastrada');
			IF (gerarDigito(linha.NumConta) <> linha.dig) THEN
				erros := array_append(erros, 'Dígito errado');
			END IF;
			RETURN NEXT (linha.NumConta, linha.dig, erros);
		ELSE
			IF (gerarDigito(linha.NumConta) <> linha.dig) THEN
				erros := array_append(erros, 'Dígito errado');
			END IF;
			IF ('S' LIKE (SELECT c.Tipo FROM Contas c WHERE c.NumConta = linha.NumConta)) THEN
				erros := array_append(erros, 'Conta sintética');
			END IF;
			RETURN NEXT (linha.NumConta, linha.Dig, erros);
		END IF;
		erros := '{}';
	END LOOP;
END; $$
LANGUAGE plpgsql;
						  
						  
/*** FUNCTION ***/
/*** a) Criar uma função que receba uma conta como argumento e retorne seu respectivo dígito ***/
CREATE OR REPLACE FUNCTION gerarDigito(conta char(11))
RETURNS char(1)
LANGUAGE plpgsql
AS $$
DECLARE
	digitofinal char(1);
	aux int;
	digito int := 0;												  
BEGIN
	FOR i IN 1..11 LOOP
		aux := cast(substring(conta from i for 1) AS int);
		CASE i
			WHEN 1 THEN
				aux := aux*2;
			WHEN 2 THEN
				aux := aux*7;
			WHEN 3 THEN
				aux := aux*6;
			WHEN 4 THEN
				aux := aux*5;
			WHEN 5 THEN
				aux := aux*4;
			WHEN 6 THEN
				aux := aux*3;
			WHEN 7 THEN
				aux := aux*2;
			WHEN 8 THEN
				aux := aux*7;
			WHEN 9 THEN
				aux := aux*6;
			WHEN 10 THEN
				aux := aux*5;
			WHEN 11 THEN
				aux := aux*4;											 
		END CASE;
		digito := digito + aux;											 										  
	END LOOP;
	digito := digito % 11;
	digito := 11 - digito;									 
	IF digito = 10 THEN
		digitofinal := '0';
	ELSIF digito = 11 THEN
		digitofinal := '&';
	ELSE
		digitofinal := cast(digito as char(1));				  
	END IF;											 											  											  
	RETURN digitofinal;											  
END $$;
										   
										   
/*** b) Criar uma função (que retorne uma tabela) que, para uma conta 
e um mês ano passado como argumento, retorne os valores (evoluídos) ***/
CREATE OR REPLACE FUNCTION valorEvoluido(conta char(11), data_mes text, data_ano text)
RETURNS TABLE (
	saldoanterior numeric (11, 2),
	totalcredito numeric (11, 2),
	totaldebito numeric (11, 2),
	saldoatual numeric (11, 2)
)AS $$
DECLARE
	saldo_ant numeric(11, 2) := 0;
	tot_credito numeric(11, 1) := 0;
	tot_debito numeric(11, 2) := 0;
	saldo_atu numeric(11, 2) := 0;
	mesaux text;
	credito numeric(11, 2) := 0;
	debito  numeric(11, 2) := 0;
BEGIN
	IF EXISTS (SELECT sal.saldo FROM saldos AS sal WHERE sal.ano = CAST(data_ano AS int) AND sal.numconta = conta) THEN
		saldo_ant := (SELECT saldo FROM saldos WHERE ano = CAST(ano AS int) AND numconta = conta);
	END IF;
	IF EXISTS (SELECT d.credito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = data_mes || data_ano) THEN
		tot_credito := (SELECT d.credito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = data_mes || data_ano);
	END IF;
	IF EXISTS (SELECT d.debito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = data_mes || data_ano) THEN
		tot_debito := (SELECT d.debito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = data_mes || data_ano);
	END IF;
	IF CAST(data_mes AS int) > 1 THEN
		FOR i IN 1..CAST(data_mes AS int)-1 LOOP
			CASE i
				WHEN 1,2,3,4,5,6,7,8,9 THEN
					mesaux := '0' || CAST(i AS text);
				ELSE
					mesaux := CAST(i AS text);
			END CASE;
			IF EXISTS (SELECT d.credito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = mesaux || data_ano) THEN
				credito := (SELECT d.credito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = mesaux || data_ano);
			END IF;
			IF EXISTS (SELECT d.debito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = mesaux || data_ano) THEN
				debito := (SELECT d.debito FROM debcred AS d WHERE d.numconta = conta AND d.mesano = mesaux || data_ano);
			END IF;
			saldo_ant := saldo_ant + credito - debito;
			credito := 0;
			debito := 0;
		END LOOP;
	END IF;
	saldo_atu := saldo_ant + tot_credito - tot_debito;
	saldoanterior := saldo_ant;
	totalcredito := tot_credito;
	totaldebito := tot_debito;
	saldoatual := saldo_atu;
	RETURN NEXT;
END; $$
LANGUAGE plpgsql;										   