```mermaid
graph TD
    RefairePlafond
    BoucherTrousBeton --> FinirSol
    FinirSol -- Hauteur Marche --> Escalier
    BoucherFenetreGarage --> IsolerMurs
    IsolerChFroide[Isoler Chambre Froide ✓] --> PlacerChauffeEau
    PlacerChauffeEau[Placer Chaffe eau ✓] --> RefairePlomberie

    FinirSol --> MursInterieurs
    BoucherFenetreGarage -->MursInterieurs
    PlacerChauffeEau --> BoucherFenetreGarage
    PlacerLaveuse --> BoucherFenetreGarage
    RefairePlomberie[Refaire Plomberie ✓] --> PlacerLaveuse
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
