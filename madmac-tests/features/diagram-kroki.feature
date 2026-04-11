Feature: Kroki-diagrammit reading modessa
  Kayttajana haluan etta PlantUML, Graphviz, D2 ja muut diagrammikielet
  renderoidaan visuaalisesti reading modessa Kroki API:n kautta.

  Scenario: PlantUML-diagrammi renderoidaan SVG:ksi
    Given MadMac on auki reading modessa
    And tiedostossa on plantuml code block
    Then plantuml-lohkon tilalla nakyy SVG-kaavio

  Scenario: Graphviz dot -diagrammi renderoidaan
    Given tiedostossa on graphviz code block
    Then graphviz-lohkon tilalla nakyy SVG-kaavio

  Scenario: D2-diagrammi renderoidaan
    Given tiedostossa on d2 code block
    Then d2-lohkon tilalla nakyy SVG-kaavio

  Scenario: Tuntematon kieli naytetaan code blockina
    Given tiedostossa on code block kielella "foobar"
    Then code block naytetaan tavallisena koodina
    And Kroki-kutsua ei tehda

  Scenario: Kroki-virhe naytetaan gracefully
    Given tiedostossa on virheellinen plantuml-syntaksi
    Then alkuperainen code block sailyy nakyvissa
    And virheilmoitus ei kaada appia

  Scenario: Diagrammit skaalautuvat zoomilla
    Given tiedostossa on plantuml-diagrammi
    And zoom on 150%
    Then diagrammi skaalautuu 150%:iin

  Scenario: Offline-tilassa diagrammit nayttavat placeholderin
    Given MadMac ei saa yhteytta kroki.io:iin
    Then code block naytetaan sellaisenaan
    And nakyy ilmoitus "Diagram rendering requires internet connection"
