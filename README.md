# A. Bevragingen

## A.1. Welke coureurs zijn in alle races van het seizoen 2024 gefinished?

### A.1.1. Primaire Uitwerking

#### A.1.1.1. Query

#### A.1.1.2. Resultaten

#### A.1.1.3. Toelichting

#### A.1.1.4. Query plan

#### A.1.1.5. Aanbevolen indexen

### A.1.2. Alternatieve Uitwerking

#### A.1.2.1. Query

#### A.1.2.2. Resultaten

#### A.1.2.3. Toelichting

#### A.1.2.4. Query plan

#### A.1.2.5. Aanbevolen indexen

## A.2. Van 2004 tot en met 2024: per race de snelste ronde met circuit, racedatum, coureur, rondenummer, rondetijd, positie, punten, totaal aantal rondes en resultstatus; gesorteerd op circuit en daarna op rondetijd.

### A.2.1. Primaire Uitwerking

#### A.2.1.1. Query

#### A.2.1.2. Resultaten

#### A.2.1.3. Toelichting

#### A.2.1.4. Query plan

#### A.2.1.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

### A.2.2. Alternatieve Uitwerking

#### A.2.2.1. Query

#### A.2.2.2. Resultaten

#### A.2.2.3. Toelichting

#### A.2.2.4. Query plan

#### A.2.2.5. Aanbevolen indexen

## A.3. Toon voor de seizoenen 2015 tot en met 2024 de winnaar van het seizoen. Geef het jaartal van het seizoen, de naam van de winnaar, het aantal races dat hij heeft gewonnen. Voeg ook het totaal aantal races toe, en voeg tot slot het volgende toe: vanaf welke race (datum, volgnummer in het seizoen + naam van de race) stond hij in de klassering op de eerste plaats en behield hij die eerste plek tot het einde toe.

### A.3.1. Primaire Uitwerking

#### A.3.1.1. Query

#### A.3.1.2. Resultaten

#### A.3.1.3. Toelichting

#### A.3.1.4. Query plan

#### A.3.1.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

### A.3.2. Alternatieve Uitwerking

#### A.3.2.1. Query

#### A.3.2.2. Resultaten

#### A.3.2.3. Toelichting

#### A.3.2.4. Query plan

#### A.3.2.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

## A.4. Welke coureurs hebben na deelname van een of meerdere seizoenen een periode niet deelgenomen en zijn in een later seizoen weer teruggekeerd in de Formule 1? Geef de naam van de coureur in alfabetische volgorde en daarnaast de periodes (in het format “1991–2006”, “2010–2012”) waarin ze deelgenomen hebben. Zet deze periodes op chronologische volgorde.

### A.4.1. Primaire Uitwerking

#### A.4.1.1. Query

*Opmerking: View gebruikt omdat in latere opdracht deze zelfde gegevens gebruikt moeten worden.*

#### A.4.1.2. Resultaten

#### A.4.1.3. Toelichting

Het uitwerken van dit vraagstuk was enorm complex, veel SQL databases hebben namelijk ingebouwde ondersteuning voor 
ranges, zoals postgres met intrange of tsrange; SQL Server heeft dit echter niet, hierdoor moest deze complete 
logica zelf geschreven worden.

Ik heb dit aangepakt door eerst een beeld te brengen welke jaren iedere driver meegedaan heeft aan races, hierna 
heb ik deze op volgorde gezet, waarbij ik door middel van de LAG() operatie met OVER() heb gekeken of de jaren die 
op volgorde staan, een opeenvolging van elkaar zijn. Indien deze niet matchen wordt er dan een nieuwe groep 
gestart (eigenlijk betekent dit: reeks opgebroken). Door middel van de SUM() operatie met OVER() heb ik daarna echte 
groepen gemaakt van jaren die bij elkaar horen; dit wordt dan in een volgende stap gebruikt om voor iedere groep de 
minimale en maximale jaartallen binnen te halen, waarbij ik ook een string-formatted variant opstel die of een range 
opstelt, of een enkel jaartal als een groep maar een jaar is.

Van deze hele operatie heb ik nader een view gemaakt (en het document ook hierop aangepast), omdat deze in veel 
hierna volgende vraagstukken gebruikt gaat worden. Hierdoor kan toekomstige code te overzien blijven.

Tot slot heb ik veel pogingen gewaagd om een alternatieve implementatie hiervoor te bedenken, dit is mij echter 
niet gelukt. En zoals de opdracht stelde ‘indien mogelijk’; daarom heb ik na veel werk, dus gekozen om deze niet 
voort te zetten. Ik kreeg geen goede uitwerking die anders werkte.

#### A.4.1.4. Query plan

#### A.4.1.5. Aanbevolen indexen

## A.5. Maak een overzicht van alle F1 coureurs die in hun volledige carrière 25 of meer wedstrijden hebben gewonnen. Toon per coureur zijn naam, in één veld een overzicht van de seizoenen waarin hij gereden heeft (ontbrekende jaren weglaten), het aantal races dat hij gestart is, het aantal races die hij gewonnen heeft en het percentage van het aantal races die hij gewonnen heeft ten opzichte van het aantal races dat hij gestart is. Een voorbeeld van hoe het er voor Michael Schumacher en Ayrton Senna uitziet, zie je hieronder.

### A.5.1. Primaire Uitwerking

#### A.5.1.1. Query

#### A.5.1.2. Resultaten

#### A.5.1.3. Toelichting

#### A.5.1.4. Query plan

#### A.5.1.5. Aanbevolen indexen

### A.5.2. Alternatieve Uitwerking

#### A.5.2.1. Query

#### A.5.2.2. Resultaten

#### A.5.2.3. Toelichting

#### A.5.2.4. Query plan

#### A.5.2.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

## A.6. Er zijn niet ieder jaar evenveel wedstrijden gereden. Daarom is het interessant om te zien welke coureur procentueel de meeste races per seizoen heeft gewonnen. Maak onderstaand overzicht

### A.6.1. Primaire Uitwerking

#### A.6.1.1. Query

#### A.6.1.2. Resultaten

#### A.6.1.3. Toelichting

De eerste oplossing voor het vraagstuk heb ik geimplementeerd door gebruik te maken van twee CTEs, een berekend het 
aantal wins per race, en de ander het totaal aantal races per bestuurder. Deze worden dan samengebracht waarbij het 
percentage berekend wordt. Tijdens het samenbrengen is er gekozen voor een left-join van de wins, omdat er niet 
altijd wins voor een jaar zullen zijn. Indien het een inner join zou zijn geweest, zouden enkel jaren met wins zichtbaar zijn.

#### A.6.1.4. Query plan

#### A.6.1.5. Aanbevolen indexen

### A.6.2. Alternatieve Uitwerking

#### A.6.2.1. Query

#### A.6.2.2. Resultaten

#### A.6.2.3. Toelichting

Voor de alternatieve implementatie heb ik de query korter proberen te maken. In deze nieuwe query wordt in een keer 
zowel het aantal wins, races en het percentage berekend. Dit is mogelijk door de IIF/NULLIF te gebruiken van SQL 
server, waarbij ik het tellen conditioneel maak (per groep), in plaats van filtering met een WHERE uit te voeren. 
Deze is daardoor veel korter, en heeft ook een simpeler queryplan.

#### A.6.2.4. Query plan

#### A.6.2.5. Aanbevolen indexen

## A.7. Maak de eindstand voor de coureurs van 2021 na. Zie onderstaand overzicht voor de juiste punten.

### A.7.1. Invoegen extra gegevens

#### A.7.1.1. Query

#### A.7.1.2. Toelichting

Om de gegevens in te laden heb ik deze handmatig moeten uitlezen van het CSV formaat. Helaas omdat ik Docker gebruik, 
was het eenvoudig inladen van CSV bestanden met de ingebouwde functies niet mogelijk; vandaar dat ik het zelf heb 
moeten doen. Het inladen van deze gegevens is gegaan in een tijdelijke tabel.

Deze tijdelijke tabel wordt stapgewijs overgezet naar de daadwerkelijke tables. Dit is in verschillende stappen gegaan, 
waarbij er in iedere stap op basis van de gegevens uit de tijdelijke tabel (en enige aannames) de nieuwe rijen aan 
worden gemaakt. Hierbij is er ook zo veel mogelijk gedaan om te checken dat er geen duplicate rijen worden toegevoegd 
(dit door middel van NOT EXISTS met een subquery).

### A.7.2. Primaire Uitwerking

#### A.7.2.1. Query

#### A.7.2.2. Resultaten

#### A.7.2.3. Toelichting

#### A.7.2.4. Query plan

#### A.7.2.5. Aanbevolen indexen

### A.7.3. Alternatieve Uitwerking

#### A.7.3.1. Query

#### A.7.3.2. Resultaten

#### A.7.3.3. Toelichting

#### A.7.3.4. Query plan

#### A.7.3.5. Aanbevolen indexen