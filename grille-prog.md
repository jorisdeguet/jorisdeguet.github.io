```mermaid

---
title: Profil programmation
---
flowchart LR
    1N6("1N6")
    2N6("2N6")
    3N5("3N5 <ul><li>Kotlin</li><li>Utilisation composants</li> </ul")
    4N6("4N6")
    5N6("5N6")
    2W5("2W5")
    3W6("2W5")
    2W5("2W5")
    2W5("2W5")
    
        1N6 --> 2N6
 
    subgraph LR "Mobile"
      
      3N5 --> 4N6
      4N6 --> 5N6
    end
    2N6 --> Mobile
subgraph LR "Web"
  2W5 --> 3W6
  3W6 --> 4W6
  4W6 --> 5W5
end
    1N6 --> Web
```
