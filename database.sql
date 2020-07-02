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

/*** Criacao da tabela Saldos ***/
CREATE TABLE Saldos
(
	numconta char(11)           NOT NULL,
	ano      int                NOT NULL,
	saldo    numeric(9,2)       NOT NULL
	CONSTRAINT DF_saldos_saldo  DEFAULT 0,
	CONSTRAINT FK_saldos_contas FOREIGN KEY (numconta) REFERENCES Contas,
	CONSTRAINT PK_saldos        PRIMARY KEY (ano, numconta)
);

/*** Criacao da tabela DebCred ***/
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

/*** Cricao da tabela MovDebCred ***/
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