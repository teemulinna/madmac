Feature: Viewer zoom skaalaa kaiken yhdessa
  Kayttajana haluan etta zoom kasvattaa seka tekstia etta diagrammeja
  jotta voin lukea ja tarkastella visuaalista sisaltoa samalla zoom-tasolla.

  Scenario: Cmd+ skaalaa tekstin
    Given MadMac on auki markdown-tiedoston kanssa reading modessa
    When painan Cmd+
    Then reading-moden teksti kasvaa
    And ulkoasun proportiot sailyvat

  Scenario: Cmd+ skaalaa Mermaid-diagrammit
    Given MadMac on auki tiedoston jossa on mermaid-diagrammi
    When painan Cmd+
    Then teksti kasvaa
    And mermaid-diagrammi kasvaa samassa suhteessa

  Scenario: Cmd+ skaalaa KaTeX-matikkakaavat
    Given MadMac on auki tiedoston jossa on KaTeX inline ja display math
    When painan Cmd+
    Then matikkakaavat kasvavat samassa suhteessa kuin teksti

  Scenario: Cmd+0 palauttaa zoom-tason 100%:iin
    Given MadMac on zoomattu 200%:iin
    When painan Cmd+0
    Then teksti, diagrammit ja kaavat palautuvat alkuperaiseen kokoon

  Scenario: Zoom muistuu uudelleenkaynnistyksen yli
    Given MadMac:n zoom on 150%
    And MadMac suljetaan ja kaynnistetaan uudelleen
    Then zoom on edelleen 150%

  Scenario: Sidebar ei zoomaa
    Given MadMac on zoomattu 200%:iin
    Then sidebarin teksti pysyy normaalin kokoisena
    And vain editori-alueen sisalto on suurempi

  Scenario: Zoomin minimi ja maksimi
    Given MadMac on zoom-tasolla 100%
    When painan Cmd- toistuvasti
    Then zoom ei mene alle 50%
    When painan Cmd+ toistuvasti
    Then zoom ei kasva yli 300%
