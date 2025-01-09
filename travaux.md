```mermaid
graph TD
    RefairePlafond
    BoucherTrousBeton --> FinirSol
    FinirSol -- Hauteur Marche --> Escalier
    BoucherFenetreGarage --> IsolerMurs
    IsolerChFroide --> PlacerChauffeEau
    PlacerChauffeEau --> RefairePlomberie

    FinirSol --> MursInterieurs
    BoucherFenetreGarage -->MursInterieurs
    PlacerChauffeEau --> BoucherFenetreGarage
    PlacerLaveuse --> BoucherFenetreGarage
    RefairePlomberie --> PlacerLaveuse
    RefairePlafond --> Electricité

    RerouterChauffGarage  --> BoucherFenetreGarage
    PlacerDouche
    PercerEvacuationSecheuse
    PercerEvacuationSDB


```
