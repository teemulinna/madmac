Feature: Workspace-asettelu sidebarilla
  Kayttajana haluan sidebarin editorin viereen
  jotta voin navigoida tiedostojen valilla.

  Scenario: Ikkuna sisaltaa split viewin
    Given macmd on auki tiedoston kanssa
    Then ikkunassa on sidebar vasemmalla ja editori oikealla
    And editori nayttaa tiedoston sisallon

  Scenario: Sidebar togglettuu Cmd+B:lla
    Given macmd on auki tiedoston kanssa
    When painan Cmd+B
    Then sidebar piiloutuu
    When painan Cmd+B uudelleen
    Then sidebar palaa nakyviin

  Scenario: Sidebarilla on minimi- ja maksimiveleys
    Given sidebar on nakyvissa
    When raahaan sidebarin jakajaa
    Then sidebar ei pienene alle 180px
    And sidebar ei kasva yli 400px

  Scenario: Editori tayttaa jaljelle jaavan tilan
    Given macmd on auki tiedoston kanssa
    And sidebar on 220px levea
    Then editori tayttaa lopun ikkunan leveydesta
    And WKWebViewin sisalto mukautuu kaytettavissa olevaan leveyteen

  Scenario: Kaikki olemassa olevat ominaisuudet toimivat split viewissa
    Given macmd on auki split view -tilassa
    Then teema vaihtuu (View > Theme > Light/Dark/Sunburn)
    And zoom toimii (Cmd+/Cmd-/Cmd+0)
    And Cmd+C kopioi markdownia leikepoydale
    And Cmd+E togglettaa edit moden
    And Cmd+S tallentaa tiedoston
    And Settings (Cmd+,) avautuu ja asetukset paivittyvat editoriin
