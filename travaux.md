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
    Electricité --> IsolerMurs
IsolerMurs --> Electricité
    PlacerChauffeEau --> RerouterChauffGarage
    PlacerLaveuse --> RerouterChauffGarage
    Escalier --> PlacerLaveuse
    RerouterChauffGarage  --> BoucherFenetreGarage
    


```

PlacerDouche
    PercerEvacuationSecheuse
    PercerEvacuationSDB
